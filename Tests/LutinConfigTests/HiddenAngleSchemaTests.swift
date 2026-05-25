import XCTest
import Yams
@testable import LutinConfig

final class HiddenAngleSchemaTests: XCTestCase {
    func testItemHiddenRoundTrips() throws {
        let yaml = """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 1, y: 2, hidden: true}
        """
        let cfg = try YAMLDecoder().decode(LutinConfig.self, from: yaml.data(using: .utf8)!)
        XCTAssertEqual(cfg.items?.first?.hidden, true)
    }

    func testDecorationHiddenRoundTrips() throws {
        let yaml = """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        decorations:
        - {type: image, path: ./a.png, x: 0, y: 0, width: 10, hidden: true}
        """
        let cfg = try YAMLDecoder().decode(LutinConfig.self, from: yaml.data(using: .utf8)!)
        XCTAssertEqual(cfg.decorations?.first?.hidden, true)
    }

    func testBackgroundAngleRoundTrips() throws {
        let yaml = """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        background: {type: gradient, colorA: "#fff", colorB: "#000", angle: 45}
        """
        let cfg = try YAMLDecoder().decode(LutinConfig.self, from: yaml.data(using: .utf8)!)
        XCTAssertEqual(cfg.background?.angle, 45)
    }

    func testHiddenNilEmitsNoKey() throws {
        var item = LutinConfig.Item(type: "app", id: "a", x: 1, y: 2, label: nil)
        item.hidden = nil
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(item)
        XCTAssertFalse(encoded.contains("hidden"))
    }

    func testHiddenFalseEmitsNoKey() throws {
        var item = LutinConfig.Item(type: "app", id: "a", x: 1, y: 2, label: nil)
        item.hidden = false
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(item)
        XCTAssertFalse(encoded.contains("hidden"))
    }

    func testHiddenTrueEmitsKey() throws {
        var item = LutinConfig.Item(type: "app", id: "a", x: 1, y: 2, label: nil)
        item.hidden = true
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(item)
        XCTAssertTrue(encoded.contains("hidden: true"))
    }

    func testBackgroundAngleNilEmitsNoKey() throws {
        var bg = LutinConfig.BackgroundInfo(type: "gradient", template: nil, path: nil, scale: nil,
                                            colorA: "#fff", colorB: "#000", grid: nil, noise: nil,
                                            cornerRadius: nil, angle: nil)
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(bg)
        XCTAssertFalse(encoded.contains("angle"))
    }

    func testBackgroundAngleNonNilEmitsKey() throws {
        var bg = LutinConfig.BackgroundInfo(type: "gradient", template: nil, path: nil, scale: nil,
                                            colorA: "#fff", colorB: "#000", grid: nil, noise: nil,
                                            cornerRadius: nil, angle: 45)
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(bg)
        XCTAssertTrue(encoded.contains("angle: 45"))
    }

    func testDecorationHiddenFalseEmitsNoKey() throws {
        var deco = LutinConfig.Decoration(type: "image",
                                          path: "./a.png", x: 0, y: 0, width: 10)
        deco.hidden = false
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(deco)
        XCTAssertFalse(encoded.contains("hidden"),
                       "hidden=false should not emit a key (got: \(encoded))")
    }

    func testDecorationHiddenTrueEmitsKey() throws {
        var deco = LutinConfig.Decoration(type: "image",
                                          path: "./a.png", x: 0, y: 0, width: 10)
        deco.hidden = true
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let encoded = try encoder.encode(deco)
        XCTAssertTrue(encoded.contains("hidden: true"),
                      "hidden=true must emit the key (got: \(encoded))")
    }

    func testBackgroundInfoFullyPopulatedRoundTrips() throws {
        let bg = LutinConfig.BackgroundInfo(type: "gradient", template: "legacy", path: "./bg.png",
                                            scale: 2, colorA: "#ff0000", colorB: "#00ff00",
                                            grid: true, noise: 0.25, cornerRadius: 12, angle: 90)

        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let yaml = try encoder.encode(bg)

        let decoded = try YAMLDecoder().decode(LutinConfig.BackgroundInfo.self, from: yaml)
        XCTAssertEqual(decoded.type, "gradient")
        XCTAssertEqual(decoded.template, "legacy")
        XCTAssertEqual(decoded.path, "./bg.png")
        XCTAssertEqual(decoded.scale, 2)
        XCTAssertEqual(decoded.colorA, "#ff0000")
        XCTAssertEqual(decoded.colorB, "#00ff00")
        XCTAssertEqual(decoded.grid, true)
        XCTAssertEqual(decoded.noise, 0.25)
        XCTAssertEqual(decoded.cornerRadius, 12)
        XCTAssertEqual(decoded.angle, 90)
    }
}
