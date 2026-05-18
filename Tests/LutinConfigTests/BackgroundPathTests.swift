import XCTest
import TestSupport
@testable import LutinConfig

final class BackgroundPathTests: XCTestCase {
    func testDecodesBackgroundPath() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("lutin.yml")
        let yaml = """
        project:
          name: Barry
          bundleId: com.anotheragence.barry
        app:
          path: ./Barry.app
        output:
          directory: ./release
          dmgName: Barry-${version}.dmg
          volumeName: Barry
        background:
          type: image
          path: ./art/bg.png
        """
        try yaml.write(to: url, atomically: true, encoding: .utf8)
        let config = try LutinConfig.load(from: url)
        XCTAssertEqual(config.background?.type, "image")
        XCTAssertEqual(config.background?.path, "./art/bg.png")
    }

    func testBackgroundPathDefaultsToNilWhenAbsent() throws {
        let config = try LutinConfig.load(from: Fixtures.barryConfig)
        XCTAssertNil(config.background?.path)
    }
}
