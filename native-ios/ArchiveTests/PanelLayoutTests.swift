import SwiftUI
import UIKit
import XCTest
@testable import Archive

final class PanelLayoutTests: XCTestCase {
    @MainActor
    func testButtonPanelKeepsMultipleChildrenInOneVerticalSurface() {
        let controller = UIHostingController(rootView:
            Button {} label: {
                ArchivePanel(tint: ArchiveTheme.sleep) {
                    Color.clear.frame(height: 20)
                    Color.clear.frame(height: 20)
                }
            }.buttonStyle(.plain)
        )
        let size = controller.sizeThatFits(in: CGSize(width: 320, height: 1000))
        XCTAssertEqual(size.width, 320, accuracy: 1)
        XCTAssertGreaterThan(size.height, 80, "Content must remain vertically grouped even inside a button label")
        XCTAssertLessThan(size.height, 160, "A compact panel must not consume the screen height")
    }
}
