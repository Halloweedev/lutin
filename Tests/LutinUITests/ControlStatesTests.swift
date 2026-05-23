import XCTest
import SwiftUI
import AppKit
@testable import LutinUI

final class ControlStatesTests: XCTestCase {
    func testRestStateReturnsBaseFill() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: false)
        let resolved = state.resolvedFill(base: base)
        XCTAssertEqual(resolved.redComponent, 1.0, accuracy: 0.001)
    }

    func testHoverDarkensByFourPercent() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: true, isPressed: false, isFocused: false)
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, 0.96, accuracy: 0.001)
    }

    func testPressDarkensByEightPercent() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: false, isPressed: true, isFocused: false)
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, 0.92, accuracy: 0.001)
    }

    func testFocusMatchesHover() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: true)
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, 0.96, accuracy: 0.001)
    }

    func testPressBeatsHoverAndFocus() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: true, isPressed: true, isFocused: true)
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, 0.92, accuracy: 0.001)
    }

    func testIsInteractingFlag() {
        XCTAssertFalse(ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: true, isPressed: false, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: false, isPressed: true, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: true).isInteracting)
    }
}
