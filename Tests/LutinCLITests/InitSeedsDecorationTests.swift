import XCTest
import TestSupport
import LutinCore
import LutinConfig
import LutinRegistry
@testable import LutinCLI

final class InitSeedsDecorationTests: XCTestCase {
    func testInitSeedsItemsButNoDefaultArrow() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let registry = Registry(storeURL: dir.appendingPathComponent("registry.json"))

        _ = try CommandLogic.initProject(directory: dir, appPath: nil,
                                         template: "blueprint", registry: registry,
                                         dryRun: false)

        let config = try LutinConfig.load(from: dir.appendingPathComponent("lutin.yml"))
        let items = config.items ?? []
        XCTAssertTrue(items.contains { $0.type == "app" })
        XCTAssertTrue(items.contains { $0.type == "applications" })
        // Arrows are now opt-in via drag-to-connect on the canvas; the
        // init template seeds two items only.
        XCTAssertNil(config.decorations,
                     "lutin init should not seed a default arrow")
    }

    func testInitConfigPassesValidation() throws {
        let dir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let registry = Registry(storeURL: dir.appendingPathComponent("registry.json"))
        _ = try CommandLogic.initProject(directory: dir, appPath: nil,
                                         template: "blueprint", registry: registry,
                                         dryRun: false)
        let config = try LutinConfig.load(from: dir.appendingPathComponent("lutin.yml"))
        XCTAssertTrue(ConfigValidator.validate(config).isEmpty)
    }
}
