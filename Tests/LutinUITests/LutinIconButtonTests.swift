import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinIconButtonTests: XCTestCase {

    func testBareAtRestNoContainerFill() {
        let view = LutinIconButton(systemName: "plus", accessibilityLabel: "Add", action: {})
        XCTAssertNil(view.restFillKey)
    }

    func testInteractionFillIsControlHoverFill() {
        let view = LutinIconButton(systemName: "plus", accessibilityLabel: "Add", action: {})
        XCTAssertEqual(view.interactionFillKey, .controlHoverFill)
    }

    func testActionFires() {
        var fired = false
        let view = LutinIconButton(systemName: "plus", accessibilityLabel: "Add", action: { fired = true })
        view.invokeForTest()
        XCTAssertTrue(fired)
    }

    func testAccessibilityLabelPreserved() {
        let view = LutinIconButton(systemName: "play.fill", accessibilityLabel: "Build", action: {})
        XCTAssertEqual(view.accessibilityLabel, "Build")
    }
}
