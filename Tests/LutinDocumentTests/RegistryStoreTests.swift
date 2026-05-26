import XCTest
import LutinCore
import LutinConfig
import LutinRegistry
import TestSupport
@testable import LutinDocument

final class RegistryStoreTests: XCTestCase {
    func testLoadsEntriesFromUnderlyingRegistry() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("projects.json")
        let registry = Registry(storeURL: url)
        try registry.upsert(RegistryEntry(
            name: "Barry", configPath: "/tmp/Barry/lutin.yml", appPath: "/tmp/Barry/Barry.app",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(timeIntervalSince1970: 0),
            lastOpenedDate: Date(timeIntervalSince1970: 0)))

        let store = RegistryStore(registry: registry)
        try store.reload()
        XCTAssertEqual(store.entries.map(\.entry.name), ["Barry"])
    }

    func testRemoveDeletesFromUnderlyingRegistry() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("projects.json")
        let registry = Registry(storeURL: url)
        try registry.upsert(RegistryEntry(
            name: "Acme", configPath: "/tmp/Acme/lutin.yml", appPath: "/tmp/Acme/Acme.app",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(), lastOpenedDate: Date()))

        let store = RegistryStore(registry: registry)
        try store.reload()
        try store.remove(name: "Acme")
        XCTAssertEqual(store.entries.count, 0)
        XCTAssertEqual(try registry.allEntries().count, 0)
    }

    func testAddUsesConfigProjectNameAndResolvedAppPath() throws {
        let dir = try Fixtures.makeTempDirectory()
        let projectDir = dir.appendingPathComponent("FolderName", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        let config = LutinConfig(
            project: .init(name: "Config Name", bundleId: "com.example.config"),
            app: .init(path: "./Apps/Config.app"),
            output: .init(directory: "./release", dmgName: "Config.dmg", volumeName: "Config"),
            window: nil, background: nil, items: nil, decorations: nil,
            signing: nil, notarization: nil, sparkle: nil)
        try config.save(to: configURL)

        let store = RegistryStore(registry: registry)
        try store.add(configURL: configURL)

        let entry = try XCTUnwrap(registry.find(name: "Config Name"))
        XCTAssertEqual(entry.configPath, configURL.path)
        XCTAssertEqual(entry.appPath, projectDir.appendingPathComponent("Apps/Config.app").path)
        XCTAssertNil(try registry.find(name: "FolderName"))
    }
}
