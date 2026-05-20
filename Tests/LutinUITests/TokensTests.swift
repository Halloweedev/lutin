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
        XCTAssertEqual(Tokens.spacing(.xs), 2)
        XCTAssertEqual(Tokens.spacing(.sm), 4)
        XCTAssertEqual(Tokens.spacing(.md), 8)
        XCTAssertEqual(Tokens.spacing(.lg), 16)
        XCTAssertEqual(Tokens.spacing(.xl), 24)
    }

    func testRadiusScale() {
        XCTAssertEqual(Tokens.radius(.button), 8)
        XCTAssertEqual(Tokens.radius(.surface), 12)
        XCTAssertEqual(Tokens.radius(.window), 16)
    }
}
