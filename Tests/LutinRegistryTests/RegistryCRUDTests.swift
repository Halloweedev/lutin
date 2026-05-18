import XCTest
import LutinCore
import TestSupport
@testable import LutinRegistry

final class RegistryCRUDTests: XCTestCase {
    private func entry(_ name: String, configPath: String) -> RegistryEntry {
        RegistryEntry(name: name, configPath: configPath, appPath: configPath + "/app",
                      lastDetectedVersion: nil, lastReleaseStatus: nil,
                      createdDate: Date(), lastOpenedDate: Date())
    }

    func testFindByName() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        try registry.upsert(entry("Barry", configPath: "/tmp/a"))
        XCTAssertEqual(try registry.find(name: "Barry")?.name, "Barry")
        XCTAssertNil(try registry.find(name: "Ghost"))
    }

    func testRemoveUnknownNameThrows() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        XCTAssertThrowsError(try registry.remove(name: "Ghost")) { error in
            XCTAssertEqual((error as? LutinError)?.code, "project_not_in_registry")
        }
    }

    func testListReportsOkAndMissingStatus() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        // An entry whose config file actually exists.
        let realConfig = Fixtures.barryConfig.path
        try registry.upsert(entry("Real", configPath: realConfig))
        try registry.upsert(entry("Gone", configPath: "/tmp/definitely/missing/lutin.yml"))

        let statuses = try registry.list()
        let byName = Dictionary(uniqueKeysWithValues: statuses.map { ($0.entry.name, $0.status) })
        XCTAssertEqual(byName["Real"], .ok)
        XCTAssertEqual(byName["Gone"], .missing)
    }
}
