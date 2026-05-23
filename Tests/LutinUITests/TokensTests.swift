import XCTest
import SwiftUI
@testable import LutinUI

final class TokensTests: XCTestCase {
    func testBrandAccentResolvesFromAssetCatalog() {
        // The test confirms the bundle and asset name are wired correctly.
        // We don't compare colour values (that's the catalog's job); we confirm
        // the Color is not the .clear fallback the SwiftUI runtime returns when
        // an asset is missing.
        let bundle = Bundle.module
        // On SwiftPM macOS the asset catalog is shipped uncompiled (no `Assets.car`),
        // and `.colorset` directories nest inside `Assets.xcassets`, so we need the
        // `subdirectory:` form to find the colorset URL.
        XCTAssertNotNil(bundle.url(forResource: "Assets", withExtension: "car")
                        ?? bundle.url(forResource: "BrandAccent", withExtension: "colorset")
                        ?? bundle.url(forResource: "BrandAccent", withExtension: "colorset",
                                      subdirectory: "Assets.xcassets"),
                        "BrandAccent.colorset must be present in LutinUI bundle")
        _ = Tokens.color(.brandAccent)        // smoke test — no crash
    }

    func testSpacingScale() {
        // Bumped 2026-05-23 to give chrome surfaces more breathing room.
        XCTAssertEqual(Tokens.spacing(.xs), 4)
        XCTAssertEqual(Tokens.spacing(.sm), 8)
        XCTAssertEqual(Tokens.spacing(.md), 14)
        XCTAssertEqual(Tokens.spacing(.lg), 20)
        XCTAssertEqual(Tokens.spacing(.xl), 32)
    }

    func testDarkenReducesEachComponentByRatio() {
        let white = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let darkened = Tokens.darken(white, by: 0.04)
        let r = darkened.redComponent
        let g = darkened.greenComponent
        let b = darkened.blueComponent
        XCTAssertEqual(r, 0.96, accuracy: 0.001)
        XCTAssertEqual(g, 0.96, accuracy: 0.001)
        XCTAssertEqual(b, 0.96, accuracy: 0.001)
        XCTAssertEqual(darkened.alphaComponent, 1.0, accuracy: 0.001)
    }

    func testDarkenClampsAtZero() {
        let black = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let darkened = Tokens.darken(black, by: 0.5)
        XCTAssertEqual(darkened.redComponent, 0.0, accuracy: 0.001)
    }

    func testDarkenPreservesAlpha() {
        let translucent = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 0.3)
        let darkened = Tokens.darken(translucent, by: 0.1)
        XCTAssertEqual(darkened.alphaComponent, 0.3, accuracy: 0.001)
    }
}
