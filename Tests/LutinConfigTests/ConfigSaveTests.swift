import XCTest
import TestSupport
@testable import LutinConfig

final class ConfigSaveTests: XCTestCase {
    private func sampleConfig() -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry-${version}.dmg", volumeName: "Barry"),
            window: nil, background: LutinConfig.BackgroundInfo(
                type: nil, template: "blueprint", path: nil, scale: nil, colorA: nil,
                colorB: nil, grid: nil, noise: nil, cornerRadius: nil),
            items: nil, decorations: nil, signing: nil, notarization: nil, sparkle: nil
        )
    }

    func testSaveWritesHeaderAndRoundTrips() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("lutin.yml")
        try sampleConfig().save(to: url)

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("# lutin.yml"))

        let reloaded = try LutinConfig.load(from: url)
        XCTAssertEqual(reloaded.project.name, "Barry")
        XCTAssertEqual(reloaded.output.dmgName, "Barry-${version}.dmg")
        XCTAssertEqual(reloaded.background?.template, "blueprint")
    }
}
