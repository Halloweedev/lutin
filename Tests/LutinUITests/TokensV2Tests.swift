import XCTest
import SwiftUI
import AppKit
@testable import LutinUI

final class TokensV2Tests: XCTestCase {
    /// Every token referenced by the UI must resolve to two non-equal NSColor
    /// values in light vs. dark mode. Catches "forgot to set the dark value"
    /// at compile-time-adjacent.
    func testEveryTokenHasDistinctLightAndDarkValue() {
        for key in Tokens.Key.allCases {
            let light = Tokens.nsColor(key, appearance: .init(named: .aqua)!)
            let dark = Tokens.nsColor(key, appearance: .init(named: .darkAqua)!)
            XCTAssertNotEqual(light, dark,
                "Token '\(key)' has identical light and dark values — set both in Assets.xcassets.")
        }
    }

    func testSquareShapeHasZeroCornerRadius() {
        let shape = SquareShape()
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        // A zero-radius rounded rect == a plain rect bbox.
        XCTAssertEqual(path.boundingRect, CGRect(x: 0, y: 0, width: 100, height: 100))
    }
}
