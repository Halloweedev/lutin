import XCTest
import TestSupport
import LutinRegistry
import LutinCore
@testable import LutinCLI

final class RegistryCommandsTests: XCTestCase {
    func testInitCreatesConfigAndRegisters() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        // Copy the Barry fixture app into the project dir so init can read its Info.plist.
        let appURL = projectDir.appendingPathComponent("Barry.app")
        try FileManager.default.copyItem(at: Fixtures.barryApp, to: appURL)
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))

        let result = try CommandLogic.initProject(
            directory: projectDir, appPath: appURL.path,
            template: "blueprint", registry: registry, dryRun: false)

        XCTAssertEqual(result.projectName, "Barry")
        XCTAssertEqual(result.bundleId, "com.anotheragence.barry")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("lutin.yml").path))
        XCTAssertEqual(try registry.find(name: "Barry")?.name, "Barry")
    }

    func testInitDryRunWritesNothing() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        let appURL = projectDir.appendingPathComponent("Barry.app")
        try FileManager.default.copyItem(at: Fixtures.barryApp, to: appURL)
        let registry = Registry(storeURL: projectDir.appendingPathComponent("projects.json"))

        _ = try CommandLogic.initProject(
            directory: projectDir, appPath: appURL.path,
            template: "blueprint", registry: registry, dryRun: true)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("lutin.yml").path))
        XCTAssertNil(try registry.find(name: "Barry"))
    }

    func testAddDuplicateNameThrows() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        _ = try CommandLogic.addProject(configPath: Fixtures.barryConfig.path,
                                        overrideName: nil, registry: registry)
        XCTAssertThrowsError(try CommandLogic.addProject(
            configPath: Fixtures.barryConfig.path, overrideName: nil, registry: registry)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "duplicate_project")
        }
    }

    func testRemoveDeletesEntry() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        _ = try CommandLogic.addProject(configPath: Fixtures.barryConfig.path,
                                        overrideName: nil, registry: registry)
        try CommandLogic.removeProject(name: "Barry", registry: registry)
        XCTAssertNil(try registry.find(name: "Barry"))
    }
}
