import XCTest
import TestSupport
@testable import LutinConfig

final class ConfigValidatorTests: XCTestCase {
    private func baseConfig() throws -> LutinConfig {
        try LutinConfig.load(from: Fixtures.barryConfig)
    }

    func testValidConfigHasNoErrors() throws {
        let issues = ConfigValidator.validate(try baseConfig())
        XCTAssertFalse(issues.contains { $0.severity == .error })
    }

    func testEmptyNameIsError() throws {
        var config = try baseConfig()
        config.project.name = ""
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.severity == .error && $0.path == "project.name" })
    }

    func testDuplicateItemIdsAreError() throws {
        var config = try baseConfig()
        config.items = [
            .init(type: "app", id: "dup", x: 0, y: 0, label: nil),
            .init(type: "applications", id: "dup", x: 1, y: 1, label: nil),
        ]
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.severity == .error && $0.path == "items[].id" })
    }

    /// Drawn arrows were removed — `type: arrow` is no longer valid and
    /// surfaces an unknown-type error.
    func testArrowTypeIsRejected() throws {
        var config = try baseConfig()
        config.decorations = [.init(type: "arrow")]
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains {
            $0.severity == .error && $0.path == "decorations[0].type"
        })
    }
}
