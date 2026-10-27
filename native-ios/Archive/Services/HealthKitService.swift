import ArchiveCore
import Foundation
import HealthKit

/// Read-only, one-shot HealthKit transport. The caller owns the two permitted
/// triggers (cold launch and completed refresh) and atomically persists the
/// returned records, explicit deletions and anchors. This service owns no store
/// of its own and never interprets an empty response as a read-authorization grant.
actor HealthKitService {
    nonisolated static var available: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    enum ServiceError: LocalizedError {
        case unavailable
        case busy
        case invalidAnchor(String)
        case invalidResponse(String)
        case invalidSample(String)
        case stalledAnchor(String)
        case limitExceeded
        case queryTimedOut

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "HealthKit is unavailable on this device."
            case .busy:
                return "A HealthKit operation is already in progress."
            case .invalidAnchor(let type):
                return "The saved HealthKit cursor or date boundary is invalid for \(type). No changes were applied."
            case .invalidResponse(let type):
                return "HealthKit returned an incomplete response for \(type). No changes were applied."
            case .invalidSample(let type):
                return "HealthKit returned an unsupported or invalid sample for \(type). No changes were applied."
            case .stalledAnchor(let type):
                return "HealthKit did not advance its cursor for \(type). No changes were applied."
            case .limitExceeded:
                return "This HealthKit read exceeded its safe import limit. No changes were applied."
            case .queryTimedOut:
                return "HealthKit did not finish in time. No changes were applied."
            }
        }
    }

    private enum Limits {
        static let pageSize = 500
        static let pagesPerType = 128
        static let objectsPerRead = 25_000 // Includes explicit deletions.
        static let bytesPerRecord = 64 * 1_024
        static let bytesPerPayload = 16 * 1_024 * 1_024
        static let bytesPerAnchor = 64 * 1_024
        static let secondsPerQuery: TimeInterval = 15
        static let secondsPerRead: TimeInterval = 90
        static let initialLookback: TimeInterval = 30 * 24 * 60 * 60
    }

    private struct QuantityDescriptor {
        let metric: String
        let unit: HKUnit
        let unitName: String
        let measurement: String?
    }

    private struct ReadType {
        let sampleType: HKSampleType
        let layer: String
        let quantity: QuantityDescriptor?
    }

    private struct ReadBudget {
        private var objects = 0
        private var bytes = 0

        mutating func include(_ value: JSONValue, encoder: JSONEncoder) throws {
            let size = try encoder.encode(value).count
            guard size <= Limits.bytesPerRecord,
                  objects < Limits.objectsPerRead,
                  bytes + size + 1 <= Limits.bytesPerPayload else {
                throw ServiceError.limitExceeded
            }
            objects += 1
            bytes += size + 1
        }
    }

    private let healthStore = HKHealthStore()
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private var dayFormatters: [String: DateFormatter] = [:]
    // Actors are reentrant across awaits. Reject an overlapping call rather than
    // allow two reads to race the same caller-supplied durable anchors.
    private var operationInProgress = false

    /// Presents read-only authorization. Completing this method proves only that
    /// the access review completed, not that any particular read type was granted.
    /// There is deliberately no data query or automatic read after this action.
    func requestAccess() async throws {
        guard Self.available else { throw ServiceError.unavailable }
        guard !operationInProgress else { throw ServiceError.busy }
        operationInProgress = true
        defer { operationInProgress = false }
        try Task.checkCancellation()

        let types = Set<HKObjectType>(readTypes().map { $0.sampleType as HKObjectType })
        try await healthStore.requestAuthorization(toShare: [], read: types)
        try Task.checkCancellation()
    }

    /// Drains each anchored type to an empty page. An explicit authorization-denied
    /// query error skips only that type, retaining its original cursor and rows.
    /// Any other failure discards the entire transaction. Empty layers are not
    /// deletion instructions; only deletedIDs are.
    func read(anchors: [String: String]) async throws -> HealthKitBatch {
        guard Self.available else { throw ServiceError.unavailable }
        guard !operationInProgress else { throw ServiceError.busy }
        operationInProgress = true
        defer { operationInProgress = false }
        try Task.checkCancellation()

        let startedAt = Date()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(Limits.secondsPerRead))
        let fallbackTimeZone = TimeZone.current
        let encoder = JSONEncoder()
        var budget = ReadBudget()
        var records: [String: [JSONValue]] = [:]
        var deletedIDs: [String: [String]] = [:]
        var nextAnchors = anchors

        for descriptor in readTypes() {
            let key = descriptor.sampleType.identifier
            let boundaryKey = key + ".startDate"
            let savedToken = anchors[key]
            let savedBoundary = anchors[boundaryKey]
            // A cursor must never be reused with a new/rolling predicate.
            guard savedToken == nil || savedBoundary != nil else {
                throw ServiceError.invalidAnchor(key)
            }

            let boundary: Date
            let boundaryString: String
            if let savedBoundary {
                guard let parsed = timestampFormatter.date(from: savedBoundary),
                      parsed.timeIntervalSinceReferenceDate.isFinite,
                      parsed <= startedAt else {
                    throw ServiceError.invalidAnchor(key)
                }
                boundary = parsed
                boundaryString = savedBoundary
            } else {
                // Round-trip the initial boundary through its persisted string so
                // even sub-millisecond Date precision cannot change the predicate.
                boundaryString = timestampFormatter.string(
                    from: startedAt.addingTimeInterval(-Limits.initialLookback)
                )
                guard let parsed = timestampFormatter.date(from: boundaryString) else {
                    throw ServiceError.invalidAnchor(key)
                }
                boundary = parsed
            }

            var anchor = try savedToken.map { try decodeAnchor($0, type: key) }
            var token = savedToken
            // No moving end date: changing the predicate while reusing an anchor
            // can permanently miss changes. Include overlapping sleep intervals.
            let predicate = HKQuery.predicateForSamples(
                withStart: boundary, end: nil, options: []
            )
            if records[descriptor.layer] == nil { records[descriptor.layer] = [] }
            if deletedIDs[descriptor.layer] == nil { deletedIDs[descriptor.layer] = [] }
            var completed = false
            var authorizationDenied = false
            var typeRecords: [JSONValue] = []
            var typeDeletedIDs: [String] = []
            var typeBudget = budget

            for _ in 0..<Limits.pagesPerType {
                try Task.checkCancellation()
                let remaining = clock.now.duration(to: deadline)
                guard remaining > .zero else { throw ServiceError.queryTimedOut }
                let components = remaining.components
                let remainingSeconds = Double(components.seconds)
                    + Double(components.attoseconds) / 1_000_000_000_000_000_000
                let page: QueryPage
                do {
                    page = try await queryPage(
                        type: descriptor.sampleType,
                        predicate: predicate,
                        anchor: anchor,
                        timeout: min(Limits.secondsPerQuery, remainingSeconds)
                    )
                } catch {
                    try Task.checkCancellation()
                    let healthError = error as NSError
                    if healthError.domain == HKErrorDomain,
                       healthError.code == HKError.Code.errorAuthorizationDenied.rawValue {
                        // This is an actual error, NOT a permission inference from
                        // empty results. Discard every staged page for this type,
                        // including deletions and its candidate cursor/boundary.
                        authorizationDenied = true
                        break
                    }
                    throw error
                }
                try Task.checkCancellation()

                // Some SDK/provider versions limit samples and deleted objects
                // separately. An EMPTY page, not count < pageSize, proves drain.
                let empty = page.samples.isEmpty && page.deleted.isEmpty
                let newToken = try encodeAnchor(page.anchor, type: key)
                guard empty || newToken != token else {
                    throw ServiceError.stalledAnchor(key)
                }

                for sample in page.samples {
                    let value = try record(
                        sample, descriptor: descriptor, fallbackTimeZone: fallbackTimeZone
                    )
                    try typeBudget.include(value, encoder: encoder)
                    typeRecords.append(value)
                }
                for deleted in page.deleted {
                    let id = deleted.uuid.uuidString
                    try typeBudget.include(.string(id), encoder: encoder)
                    // Quantity deletions intentionally share quantitySamples:
                    // HKDeletedObject has no metric; core must inspect the old row.
                    typeDeletedIDs.append(id)
                }

                anchor = page.anchor
                token = newToken
                if empty {
                    completed = true
                    break
                }
            }

            if authorizationDenied { continue }
            guard completed, let token else { throw ServiceError.limitExceeded }
            budget = typeBudget
            records[descriptor.layer, default: []].append(contentsOf: typeRecords)
            deletedIDs[descriptor.layer, default: []].append(contentsOf: typeDeletedIDs)
            nextAnchors[key] = token
            nextAnchors[boundaryKey] = boundaryString
        }

        try Task.checkCancellation()
        guard clock.now < deadline else { throw ServiceError.queryTimedOut }
        let syncedAt = Date()
        // Include dictionary/array overhead and anchor strings in the final cap,
        // not just the per-record budget used while building the batch.
        let envelope = JSONValue.object([
            "records": .object(records.mapValues { .array($0) }),
            "deletedIDs": .object(deletedIDs.mapValues { .array($0.map { .string($0) }) }),
            "anchors": .object(nextAnchors.mapValues { .string($0) }),
            "syncedAt": .string(timestampFormatter.string(from: syncedAt))
        ])
        guard try encoder.encode(envelope).count <= Limits.bytesPerPayload else {
            throw ServiceError.limitExceeded
        }
        try Task.checkCancellation()
        guard clock.now < deadline else { throw ServiceError.queryTimedOut }
        return HealthKitBatch(
            records: records, deletedIDs: deletedIDs, anchors: nextAnchors, syncedAt: syncedAt
        )
    }

    private func readTypes() -> [ReadType] {
        [
            quantity(.stepCount, metric: "steps", unit: .count(), unitName: "count"),
            quantity(.distanceWalkingRunning, metric: "distance", unit: .meter(), unitName: "m"),
            quantity(.activeEnergyBurned, metric: "activeCalories", unit: .kilocalorie(), unitName: "kcal"),
            quantity(.basalEnergyBurned, metric: "basalCalories", unit: .kilocalorie(), unitName: "kcal"),
            quantity(.flightsClimbed, metric: "floors", unit: .count(), unitName: "count"),
            ReadType(sampleType: HKCategoryType(.sleepAnalysis), layer: "sleepSessions", quantity: nil),
            quantity(
                .heartRate, metric: "heartRate", unit: .count().unitDivided(by: .minute()),
                unitName: "bpm", layer: "heartRate"
            ),
            quantity(
                .heartRateVariabilitySDNN, metric: "heartRateVariability",
                unit: .secondUnit(with: .milli), unitName: "ms",
                layer: "heartRateVariability", measurement: "SDNN"
            ),
            ReadType(sampleType: HKObjectType.workoutType(), layer: "workouts", quantity: nil)
        ]
    }

    private func quantity(
        _ identifier: HKQuantityTypeIdentifier, metric: String, unit: HKUnit,
        unitName: String, layer: String = "quantitySamples", measurement: String? = nil
    ) -> ReadType {
        ReadType(
            sampleType: HKQuantityType(identifier), layer: layer,
            quantity: QuantityDescriptor(
                metric: metric, unit: unit, unitName: unitName, measurement: measurement
            )
        )
    }

    private func decodeAnchor(_ token: String, type: String) throws -> HKQueryAnchor {
        guard token.utf8.count <= ((Limits.bytesPerAnchor + 2) / 3) * 4,
              let data = Data(base64Encoded: token), !data.isEmpty,
              data.count <= Limits.bytesPerAnchor else {
            throw ServiceError.invalidAnchor(type)
        }
        do {
            guard let anchor = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: HKQueryAnchor.self, from: data
            ) else { throw ServiceError.invalidAnchor(type) }
            return anchor
        } catch {
            throw ServiceError.invalidAnchor(type)
        }
    }

    private func encodeAnchor(_ anchor: HKQueryAnchor, type: String) throws -> String {
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: anchor, requiringSecureCoding: true
        )
        guard data.count <= Limits.bytesPerAnchor else { throw ServiceError.invalidAnchor(type) }
        return data.base64EncodedString()
    }

    private func record(
        _ sample: HKSample, descriptor: ReadType, fallbackTimeZone: TimeZone
    ) throws -> JSONValue {
        let type = descriptor.sampleType.identifier
        guard sample.sampleType.identifier == type,
              sample.startDate.timeIntervalSinceReferenceDate.isFinite,
              sample.endDate.timeIntervalSinceReferenceDate.isFinite,
              sample.endDate >= sample.startDate else {
            throw ServiceError.invalidSample(type)
        }
        let metadata = sample.metadata ?? [:]
        let recordedZone = (metadata[HKMetadataKeyTimeZone] as? String).flatMap {
            TimeZone(identifier: $0)
        }
        let timeZone = recordedZone ?? fallbackTimeZone
        let revision = sample.sourceRevision
        let os = revision.operatingSystemVersion
        let startedAt = timestampFormatter.string(from: sample.startDate)
        let endedAt = timestampFormatter.string(from: sample.endDate)
        var fields: [String: JSONValue] = [
            "id": .string(sample.uuid.uuidString),
            "provider": .string("healthKit"),
            "source": .string(revision.source.name),
            "sourceId": .string(revision.source.bundleIdentifier),
            "healthKitType": .string(type),
            "startedAt": .string(startedAt),
            "endedAt": .string(endedAt),
            "startDate": .string(startedAt),
            "endDate": .string(endedAt),
            // Raw local start date only. Core owns sleep previous-wake-day rules.
            "date": .string(dayString(sample.startDate, timeZone: timeZone)),
            "timezone": .string(timeZone.identifier),
            "timeZone": .string(timeZone.identifier),
            "timeZoneSource": .string(recordedZone == nil ? "deviceFallback" : "sampleMetadata"),
            "sourceName": .string(revision.source.name),
            "sourceBundleId": .string(revision.source.bundleIdentifier),
            "sourceRevision": .object([
                "name": .string(revision.source.name),
                "bundleIdentifier": .string(revision.source.bundleIdentifier),
                "version": jsonString(revision.version),
                "productType": jsonString(revision.productType),
                "operatingSystemVersion": .object([
                    "major": .number(Double(os.majorVersion)),
                    "minor": .number(Double(os.minorVersion)),
                    "patch": .number(Double(os.patchVersion))
                ])
            ]),
            "device": deviceRecord(sample.device),
            "metadata": .object(try identityMetadata(metadata, type: type))
        ]

        if let quantity = descriptor.quantity {
            guard let value = sample as? HKQuantitySample else {
                throw ServiceError.invalidSample(type)
            }
            fields["metric"] = .string(quantity.metric)
            fields["value"] = try jsonNumber(value.quantity.doubleValue(for: quantity.unit), type: type)
            fields["unit"] = .string(quantity.unitName)
            if let measurement = quantity.measurement {
                fields["measurement"] = .string(measurement)
            }
        } else if descriptor.layer == "sleepSessions", let sleep = sample as? HKCategorySample {
            let stage: String
            let isAsleep: Bool
            switch sleep.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                stage = "inBed"; isAsleep = false
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stage = "awake"; isAsleep = false
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                stage = "asleepUnspecified"; isAsleep = true
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stage = "asleepCore"; isAsleep = true
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stage = "asleepDeep"; isAsleep = true
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stage = "asleepREM"; isAsleep = true
            default:
                stage = "unknown"; isAsleep = false
            }
            fields["sleepStage"] = .string(stage)
            fields["stage"] = .number(Double(sleep.value))
            fields["sleepStageValue"] = .number(Double(sleep.value))
            fields["isAsleep"] = .bool(isAsleep)
            // This is the RAW interval, not a claim of asleep duration.
            fields["durationSeconds"] = try jsonNumber(
                sleep.endDate.timeIntervalSince(sleep.startDate), type: type
            )
        } else if descriptor.layer == "workouts", let workout = sample as? HKWorkout {
            fields["activityType"] = .number(Double(workout.workoutActivityType.rawValue))
            fields["durationSeconds"] = try jsonNumber(workout.duration, type: type)
            // Keep HealthKit's supplied totals, including legacy workouts. The
            // total* accessors are deprecated on newer SDKs but remain available
            // on iOS 17; they do not perform another query or fabricate metrics.
            fields["distanceMeters"] = try jsonNumber(
                workout.totalDistance?.doubleValue(for: .meter()), type: type
            )
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity() ?? workout.totalEnergyBurned
            fields["activeCalories"] = try jsonNumber(
                energy?.doubleValue(for: .kilocalorie()), type: type
            )
        } else {
            throw ServiceError.invalidSample(type)
        }
        return .object(fields)
    }

    private func identityMetadata(_ metadata: [String: Any], type: String) throws -> [String: JSONValue] {
        // Deliberately allowlist identity/provenance, not arbitrary private or
        // potentially huge third-party metadata. No credentials or logs involved.
        var result: [String: JSONValue] = [:]
        for key in [HKMetadataKeySyncIdentifier, HKMetadataKeyExternalUUID, HKMetadataKeyTimeZone] {
            if let value = metadata[key] as? String { result[key] = .string(value) }
        }
        if let value = metadata[HKMetadataKeySyncVersion] as? NSNumber {
            result[HKMetadataKeySyncVersion] = try jsonNumber(value.doubleValue, type: type)
        }
        if let value = metadata[HKMetadataKeyWasUserEntered] as? Bool {
            result[HKMetadataKeyWasUserEntered] = .bool(value)
        }
        return result
    }

    private func deviceRecord(_ device: HKDevice?) -> JSONValue {
        guard let device else { return .null }
        return .object([
            "name": jsonString(device.name),
            "manufacturer": jsonString(device.manufacturer),
            "model": jsonString(device.model),
            "hardwareVersion": jsonString(device.hardwareVersion),
            "firmwareVersion": jsonString(device.firmwareVersion),
            "softwareVersion": jsonString(device.softwareVersion),
            "localIdentifier": jsonString(device.localIdentifier),
            "udiDeviceIdentifier": jsonString(device.udiDeviceIdentifier)
        ])
    }

    private func jsonString(_ value: String?) -> JSONValue {
        value.map { .string($0) } ?? .null
    }

    private func jsonNumber(_ value: Double?, type: String) throws -> JSONValue {
        guard let value else { return .null }
        guard value.isFinite, value >= 0 else { throw ServiceError.invalidSample(type) }
        return .number(value)
    }

    private func dayString(_ date: Date, timeZone: TimeZone) -> String {
        if let formatter = dayFormatters[timeZone.identifier] {
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        if dayFormatters.count >= 64 { dayFormatters.removeAll() }
        dayFormatters[timeZone.identifier] = formatter
        return formatter.string(from: date)
    }

    private func queryPage(
        type: HKSampleType, predicate: NSPredicate, anchor: HKQueryAnchor?, timeout: TimeInterval
    ) async throws -> QueryPage {
        let operation = QueryOperation(store: healthStore)
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                operation.start(
                    type: type, predicate: predicate, anchor: anchor,
                    timeout: timeout, continuation: continuation
                )
            }
        }, onCancel: {
            operation.cancel()
        })
    }

    // HealthKit samples/anchors are immutable here. Transfer their references out
    // of the arbitrary callback queue; only this actor converts them to JSON.
    private struct QueryPage: @unchecked Sendable {
        let samples: [HKSample]
        let deleted: [HKDeletedObject]
        let anchor: HKQueryAnchor
    }

    /// Small callback bridge, not an actor: cancellation and HealthKit callbacks
    /// can race on arbitrary threads. All mutable state is protected by lock.
    /// Only finish() resumes a registered continuation, exactly once. The query
    /// is stopped on success, error, timeout and cancellation; no update handler
    /// or observer is installed. A timer only bounds this explicit query.
    private final class QueryOperation: @unchecked Sendable {
        private let store: HKHealthStore
        private let lock = NSLock()
        private var finished = false
        private var query: HKAnchoredObjectQuery?
        private var continuation: CheckedContinuation<QueryPage, Error>?
        private var timeoutWork: DispatchWorkItem?

        init(store: HKHealthStore) {
            self.store = store
        }

        func start(
            type: HKSampleType, predicate: NSPredicate, anchor: HKQueryAnchor?,
            timeout: TimeInterval, continuation: CheckedContinuation<QueryPage, Error>
        ) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            let query = HKAnchoredObjectQuery(
                type: type, predicate: predicate, anchor: anchor, limit: Limits.pageSize
            ) { [self] _, samples, deleted, newAnchor, error in
                if let error {
                    finish(.failure(error))
                } else if let samples, let deleted, let newAnchor {
                    finish(.success(QueryPage(samples: samples, deleted: deleted, anchor: newAnchor)))
                } else {
                    finish(.failure(ServiceError.invalidResponse(type.identifier)))
                }
            }
            self.query = query
            let timer = DispatchWorkItem { [weak self] in
                self?.finish(.failure(ServiceError.queryTimedOut))
            }
            timeoutWork = timer
            // execute() registers asynchronous work. Serialize registration with
            // cancellation, so stop() cannot run before execute() and leave a
            // subsequently registered query orphaned.
            store.execute(query)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timer)
            lock.unlock()
        }

        func cancel() {
            finish(.failure(CancellationError()))
        }

        private func finish(_ result: Result<QueryPage, Error>) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            finished = true
            let continuation = self.continuation
            let query = self.query
            let timer = timeoutWork
            self.continuation = nil
            self.query = nil
            timeoutWork = nil
            lock.unlock()

            timer?.cancel()
            if let query { store.stop(query) }
            continuation?.resume(with: result)
        }
    }
}
