import XCTest
import LutinCore
import TestSupport
@testable import LutinRegistry

final class RegistryPersistenceTests: XCTestCase {
    func testEmptyRegistryWhenFileMissing() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        XCTAssertEqual(try registry.allEntries().count, 0)
    }

    func testWritesAndReloadsEntries() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("projects.json")
        let registry = Registry(storeURL: url)
        try registry.upsert(RegistryEntry(
            name: "Barry", configPath: "/tmp/Barry/lutin.yml", appPath: "/tmp/Barry/Barry.app",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(timeIntervalSince1970: 0), lastOpenedDate: Date(timeIntervalSince1970: 0)))

        let reloaded = Registry(storeURL: url)
        XCTAssertEqual(try reloaded.allEntries().map(\.name), ["Barry"])
    }

    func testCorruptFileThrowsRegistryCorrupt() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("projects.json")
        try "{not json".write(to: url, atomically: true, encoding: .utf8)
        let registry = Registry(storeURL: url)
        XCTAssertThrowsError(try registry.allEntries()) { error in
            XCTAssertEqual((error as? LutinError)?.code, "registry_corrupt")
        }
    }
}
