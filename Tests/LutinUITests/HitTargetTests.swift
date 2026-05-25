import XCTest
import SwiftUI
import AppKit
@testable import LutinUI

/// Verifies the accessibility-pass hit-target policy:
/// every chrome control gets at least `Tokens.Size.controlHeight` of
/// clickable height, and the `.lutinHitTarget()` modifier is applied
/// consistently on the three primitives.
@MainActor
final class HitTargetTests: XCTestCase {

    func testControlHeightTokenIsTwentyEight() {
        XCTAssertEqual(Tokens.Size.controlHeight, 28,
                       "Minimum chrome hit-target height is fixed at 28pt — see View+LutinHitTarget.swift")
    }

    func testLutinToggleGrowsToControlHeight() {
        // The toggle's visible chrome (14pt checkbox + 13pt label) is
        // well under 28pt on its own. Wrapping in lutinHitTarget() must
        // grow the hosting view's intrinsic height to controlHeight.
        let binding = Binding(get: { false }, set: { _ in })
        let view = LutinToggle("Show toolbar", isOn: binding)
        let host = NSHostingView(rootView: view)
        let fit = host.fittingSize
        XCTAssertGreaterThanOrEqual(fit.height, Tokens.Size.controlHeight,
                                    "LutinToggle hit target collapsed below 28pt — lutinHitTarget() regressed")
    }

    func testLutinButtonTitleMeetsControlHeight() {
        let view = LutinButton("Cancel") { }
        let host = NSHostingView(rootView: view)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, Tokens.Size.controlHeight,
                                    "LutinButton title-init hit target collapsed below 28pt")
    }

    func testLutinIconButtonMeetsControlHeight() {
        let view = LutinIconButton(systemName: "plus", accessibilityLabel: "Add") { }
        let host = NSHostingView(rootView: view)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, Tokens.Size.controlHeight,
                                    "LutinIconButton hit target collapsed below 28pt")
    }
}
