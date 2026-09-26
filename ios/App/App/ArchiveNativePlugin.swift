import Capacitor
import HealthKit
import SwiftUI
import UIKit

@objc(ArchiveNativePlugin)
public final class ArchiveNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ArchiveNativePlugin"
    public let jsName = "ArchiveNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getCapabilities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentHealthAccessPrimer", returnType: CAPPluginReturnPromise)
    ]

    private let healthStore = HKHealthStore()

    @objc public func getCapabilities(_ call: CAPPluginCall) {
        call.resolve([
            "platform": "ios",
            "swiftUI": true,
            "healthKitAvailable": HKHealthStore.isHealthDataAvailable(),
            "healthImportReady": false,
            "authorizationMode": "readOnly"
        ])
    }

    @objc public func presentHealthAccessPrimer(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                call.reject("Archive's native bridge is unavailable.")
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                call.resolve(["status": "unavailable", "platform": "ios"])
                return
            }
            guard let presenter = self.bridge?.viewController else {
                call.reject("Archive could not present the HealthKit access sheet.")
                return
            }

            let view = ArchiveHealthAccessView(
                requestAuthorization: { completion in
                    self.requestReadAuthorization(completion: completion)
                },
                finish: { status in
                    call.resolve(["status": status, "platform": "ios"])
                }
            )
            let controller = UIHostingController(rootView: view)
            controller.modalPresentationStyle = .pageSheet
            controller.isModalInPresentation = true
            if #available(iOS 15.0, *) {
                controller.sheetPresentationController?.detents = [.medium(), .large()]
                controller.sheetPresentationController?.prefersGrabberVisible = true
            }
            presenter.present(controller, animated: true)
        }
    }

    private func requestReadAuthorization(completion: @escaping (Bool, String?) -> Void) {
        let readTypes = healthReadTypes()
        guard !readTypes.isEmpty else {
            completion(false, "Archive could not prepare its HealthKit data types.")
            return
        }

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            DispatchQueue.main.async {
                if let error {
                    completion(false, error.localizedDescription)
                    return
                }
                completion(success, success ? nil : "iOS did not complete the HealthKit access review.")
            }
        }
    }

    private func healthReadTypes() -> Set<HKObjectType> {
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .heartRate,
            .heartRateVariabilitySDNN,
            .flightsClimbed
        ]
        var types = Set<HKObjectType>()
        for identifier in quantityIdentifiers {
            if let quantityType = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(quantityType)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }
}

private struct ArchiveHealthAccessView: View {
    private enum AccessState: Equatable {
        case introduction
        case requesting
        case complete
        case failed(String)
    }

    @Environment(\.presentationMode) private var presentationMode
    @State private var accessState: AccessState = .introduction

    let requestAuthorization: (@escaping (Bool, String?) -> Void) -> Void
    let finish: (String) -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brandMark
                    introduction
                    dataSummary
                    if case let .failed(message) = accessState {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    actions
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
    }

    private var brandMark: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 62, height: 62)
                .shadow(color: Color.black.opacity(0.07), radius: 18, y: 8)
            Text("A")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(Color.primary)
        }
        .accessibilityHidden(true)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(accessState == .complete ? "Access review complete" : "Connect Apple Health")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text(accessState == .complete
                 ? "Your choices remain private and can be changed at any time in Apple Health."
                 : "Archive can use the health records already collected by your iPhone and watch. You choose every category, and Archive only requests read access.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataSummary: some View {
        VStack(spacing: 0) {
            healthRow("Sleep & recovery", color: Color(red: 0.79, green: 0.63, blue: 0.86))
            Divider().padding(.leading, 42)
            healthRow("Movement & workouts", color: Color(red: 0.67, green: 0.86, blue: 0.67))
            Divider().padding(.leading, 42)
            healthRow("Heart & energy", color: Color(red: 1.0, green: 0.77, blue: 0.83))
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 0.75)
        )
    }

    private func healthRow(_ title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 13, height: 13)
            Text(title).font(.body.weight(.medium))
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                HStack(spacing: 9) {
                    if accessState == .requesting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(primaryLabel).font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(ArchiveHealthPrimaryButtonStyle())
            .disabled(accessState == .requesting)

            if accessState != .complete {
                Button("Not now") {
                    finish("cancelled")
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.body.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 46)
            }
        }
    }

    private var primaryLabel: String {
        switch accessState {
        case .introduction, .failed:
            return "Review health access"
        case .requesting:
            return "Opening Apple Health..."
        case .complete:
            return "Done"
        }
    }

    private func primaryAction() {
        if accessState == .complete {
            finish("reviewed")
            presentationMode.wrappedValue.dismiss()
            return
        }
        accessState = .requesting
        requestAuthorization { success, message in
            withAnimation(.easeOut(duration: 0.22)) {
                accessState = success ? .complete : .failed(message ?? "Health access could not be reviewed.")
            }
        }
    }
}

private struct ArchiveHealthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.33, green: 0.29, blue: 0.42), Color(red: 0.16, green: 0.17, blue: 0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
