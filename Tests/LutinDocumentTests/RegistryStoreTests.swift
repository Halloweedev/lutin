import XCTest
import LutinCore
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
}
