import XCTest
import TestSupport
import LutinCore
@testable import LutinConfig

final class TemplatesTests: XCTestCase {
    func testKnownTemplateLookup() throws {
        let blueprint = try Templates.named("blueprint")
        XCTAssertEqual(blueprint.window.width, 680)
        XCTAssertEqual(blueprint.background.template, "blueprint")
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
        XCTAssertEqual(config.window?.width, 680)            // from blueprint
        XCTAssertEqual(config.background?.colorA, "#EEF4FF") // from blueprint
        XCTAssertEqual(config.background?.template, "blueprint")
    }

    func testExplicitValuesWinOverTemplate() throws {
        var config = try LutinConfig.load(from: Fixtures.barryConfig)
        config.window = LutinConfig.WindowInfo(width: 900, height: nil, iconSize: nil,
                                               textSize: nil, showToolbar: nil, showSidebar: nil)
        config = try Templates.applyDefaults(to: config)
        XCTAssertEqual(config.window?.width, 900)            // explicit kept
        XCTAssertEqual(config.window?.height, 420)           // filled from blueprint
    }
}
