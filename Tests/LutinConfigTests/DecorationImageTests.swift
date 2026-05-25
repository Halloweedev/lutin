import XCTest
import TestSupport
@testable import LutinConfig

final class DecorationImageTests: XCTestCase {
    private func baseConfig(decorations: [LutinConfig.Decoration]) -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.x.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry.dmg", volumeName: "Barry"),
            window: nil, background: nil,
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220, label: nil)],
            decorations: decorations,
            signing: nil, notarization: nil, sparkle: nil)
    }

    func testValidImageDecorationHasNoIssues() {
        let config = baseConfig(decorations: [
            .init(type: "image", path: "assets/arrow.png", x: 300, y: 220, width: 120)])
        XCTAssertTrue(ConfigValidator.validate(config).isEmpty)
    }

    /// Drawn arrows were removed — `type: arrow` is rejected as unknown.
    func testArrowTypeIsAnError() {
        let config = baseConfig(decorations: [.init(type: "arrow")])
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].type" })
    }

    func testImageMissingPathAndPositionIsAnError() {
        let config = baseConfig(decorations: [.init(type: "image")])
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].path" })
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].x" })
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].y" })
    }

    func testUnknownDecorationTypeIsAnError() {
        let config = baseConfig(decorations: [.init(type: "sparkles")])
        XCTAssertTrue(ConfigValidator.validate(config)
            .contains { $0.path == "decorations[0].type" })
    }

    func testImageDecorationDecodesFromYAML() throws {
        let yaml = """
        project: { name: Barry, bundleId: com.x.barry }
        app: { path: ./Barry.app }
        output: { directory: ./release, dmgName: Barry.dmg, volumeName: Barry }
        decorations:
          - type: image
            path: assets/arrow.png
            x: 300
            y: 220
            width: 120
        """
        let config = try YAMLDecoderConfig.decode(yaml)
        XCTAssertEqual(config.decorations?.first?.type, "image")
        XCTAssertEqual(config.decorations?.first?.path, "assets/arrow.png")
        XCTAssertEqual(config.decorations?.first?.x, 300)
        XCTAssertEqual(config.decorations?.first?.y, 220)
        XCTAssertEqual(config.decorations?.first?.width, 120)
    }
}

/// Small helper so the test does not depend on Yams import details.
enum YAMLDecoderConfig {
    static func decode(_ yaml: String) throws -> LutinConfig {
        let dir = try Fixtures.makeTempDirectory()
        let tmp = dir.appendingPathComponent("lutin.yml")
        try yaml.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinConfig.load(from: tmp)
    }
}
