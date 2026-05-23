import XCTest
import TestSupport
import LutinCore
@testable import LutinConfig

final class ConfigLoadTests: XCTestCase {
    func testLoadsBarryFixture() throws {
        let config = try LutinConfig.load(from: Fixtures.barryConfig)
        XCTAssertEqual(config.project.name, "Barry")
        XCTAssertEqual(config.project.bundleId, "com.anotheragence.barry")
        XCTAssertEqual(config.app.path, "./Barry.app")
        XCTAssertEqual(config.output.dmgName, "Barry-${version}.dmg")
        XCTAssertNil(config.background?.template)    // fixture now uses explicit solid, no template name
        XCTAssertNil(config.window)              // not present in fixture
    }

    func testMissingFileThrowsConfigNotFound() {
        let missing = Fixtures.barryProject.appendingPathComponent("nope.yml")
        XCTAssertThrowsError(try LutinConfig.load(from: missing)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "config_not_found")
        }
    }

    func testMalformedYamlThrowsInvalidConfig() throws {
        let dir = try Fixtures.makeTempDirectory()
        let badURL = dir.appendingPathComponent("lutin.yml")
        try "project: [unbalanced".write(to: badURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try LutinConfig.load(from: badURL)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "invalid_config")
        }
    }
}
