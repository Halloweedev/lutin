import XCTest
import LutinCore
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

    func testValidArrowDecorationHasNoIssues() {
        let config = baseConfig(decorations: [
            .init(type: "arrow", from: "app", to: "applications", label: "Drag to install")])
        XCTAssertTrue(ConfigValidator.validate(config).isEmpty)
    }

    func testValidImageDecorationHasNoIssues() {
        let config = baseConfig(decorations: [
            .init(type: "image", path: "assets/arrow.png", x: 300, y: 220, width: 120)])
        XCTAssertTrue(ConfigValidator.validate(config).isEmpty)
    }

    func testArrowMissingEndpointsIsAnError() {
        let config = baseConfig(decorations: [.init(type: "arrow")])
        let issues = ConfigValidator.validate(config)
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].from" })
        XCTAssertTrue(issues.contains { $0.path == "decorations[0].to" })
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
    }
}

/// Small helper so the test does not depend on Yams import details.
enum YAMLDecoderConfig {
    static func decode(_ yaml: String) throws -> LutinConfig {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-deco-\(UUID().uuidString).yml")
        try yaml.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try LutinConfig.load(from: tmp)
    }
}
