import XCTest
import TestSupport
import LutinCore
import LutinConfig
import LutinRegistry
@testable import LutinCLI

final class InitSeedsDecorationTests: XCTestCase {
    func testInitSeedsItemsAndADefaultArrow() throws {
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
        let decorations = config.decorations ?? []
        XCTAssertEqual(decorations.count, 1)
        XCTAssertEqual(decorations.first?.type, "arrow")
        XCTAssertEqual(decorations.first?.from, "app")
        XCTAssertEqual(decorations.first?.to, "applications")
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
