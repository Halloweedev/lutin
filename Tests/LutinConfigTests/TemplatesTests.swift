import XCTest
import TestSupport
import LutinCore
@testable import LutinConfig

final class TemplatesTests: XCTestCase {
    func testKnownTemplateLookup() throws {
        let minimal = try Templates.named("minimal")
        XCTAssertEqual(minimal.window.width, 600)
        XCTAssertEqual(minimal.background.type, "solid")
        XCTAssertEqual(minimal.background.colorA, "#FFFFFF")
    }

    func testUnknownTemplateThrows() {
        XCTAssertThrowsError(try Templates.named("does-not-exist")) { error in
            XCTAssertEqual((error as? LutinError)?.code, "unknown_template")
        }
    }

    func testApplyDefaultsFillsMissingSections() throws {
        var config = try LutinConfig.load(from: Fixtures.barryConfig)
        XCTAssertNil(config.window)
        config = try Templates.applyDefaults(to: config)
        XCTAssertEqual(config.window?.width, 600)            // from minimal (default)
        XCTAssertEqual(config.background?.colorA, "#FFFFFF") // from minimal
        XCTAssertEqual(config.background?.type, "solid")     // from minimal
    }

    func testExplicitValuesWinOverTemplate() throws {
        var config = try LutinConfig.load(from: Fixtures.barryConfig)
        config.window = LutinConfig.WindowInfo(width: 900, height: nil, iconSize: nil,
                                               textSize: nil, showToolbar: nil, showSidebar: nil)
        config = try Templates.applyDefaults(to: config)
        XCTAssertEqual(config.window?.width, 900)            // explicit kept
        XCTAssertEqual(config.window?.height, 400)           // filled from minimal
    }

    func testLegacyTemplateNameFallsBackToDefault() throws {
        // A config with the removed "blueprint" template name should still
        // load successfully — applyDefaults falls back to defaultTemplateName.
        var config = try LutinConfig.load(from: Fixtures.barryConfig)
        config.background = LutinConfig.BackgroundInfo(
            type: "solid", template: "blueprint", path: nil, scale: nil,
            colorA: nil, colorB: nil, grid: nil, noise: nil, cornerRadius: nil)
        // Must not throw, and must fill window from minimal.
        XCTAssertNoThrow(config = try Templates.applyDefaults(to: config))
        XCTAssertEqual(config.window?.width, 600)  // minimal's width
    }
}
