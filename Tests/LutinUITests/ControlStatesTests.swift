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

    // Hover/press values bumped 2026-05-24 alongside the pure-white chrome
    // pass — 4% on white was too quiet to read as a state change. The
    // hover/press constants are the source of truth; these tests pin the
    // math through them so a future re-tune doesn't silently regress the
    // resolution function.
    func testHoverDarkens() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: true, isPressed: false, isFocused: false)
        let expected = 1.0 - ControlInteractionState.hoverDarken
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, CGFloat(expected), accuracy: 0.001)
    }

    func testPressDarkens() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: false, isPressed: true, isFocused: false)
        let expected = 1.0 - ControlInteractionState.pressDarken
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, CGFloat(expected), accuracy: 0.001)
    }

    func testFocusMatchesHover() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: true)
        let expected = 1.0 - ControlInteractionState.hoverDarken
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, CGFloat(expected), accuracy: 0.001)
    }

    func testPressBeatsHoverAndFocus() {
        let base = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let state = ControlInteractionState.State(isHovered: true, isPressed: true, isFocused: true)
        let expected = 1.0 - ControlInteractionState.pressDarken
        XCTAssertEqual(state.resolvedFill(base: base).redComponent, CGFloat(expected), accuracy: 0.001)
    }

    func testHoverIsNoticeablyGreyer() {
        // The user asked for clearly-greyer hovers (2026-05-24). Pin a floor
        // so a future tune cannot drop back into "is anything happening?"
        // territory — anything below 6% on white is imperceptible without
        // a side-by-side comparison.
        XCTAssertGreaterThanOrEqual(ControlInteractionState.hoverDarken, 0.06)
        XCTAssertGreaterThan(ControlInteractionState.pressDarken, ControlInteractionState.hoverDarken)
    }

    func testIsInteractingFlag() {
        XCTAssertFalse(ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: true, isPressed: false, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: false, isPressed: true, isFocused: false).isInteracting)
        XCTAssertTrue(ControlInteractionState.State(isHovered: false, isPressed: false, isFocused: true).isInteracting)
    }
}
