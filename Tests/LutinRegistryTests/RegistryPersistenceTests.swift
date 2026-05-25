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

    func testDecodesLegacyEntryWithoutBuildOutcomeField() throws {
        let dir = try Fixtures.makeTempDirectory()
        let storeURL = dir.appendingPathComponent("projects.json")

        // Hand-written legacy JSON (no `lastBuildOutcome` key) must still decode.
        let legacy = """
        {
          "schemaVersion": 1,
          "projects": [
            {
              "name": "Legacy",
              "configPath": "/tmp/legacy/lutin.yml",
              "appPath": "/tmp/legacy/app.app",
              "lastDetectedVersion": null,
              "lastReleaseStatus": null,
              "createdDate": "2022-03-07T20:26:40Z",
              "lastOpenedDate": "2022-03-07T20:26:40Z"
            }
          ]
        }
        """
        try legacy.write(to: storeURL, atomically: true, encoding: .utf8)

        let registry = Registry(storeURL: storeURL)
        let entries = try registry.allEntries()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "Legacy")
        XCTAssertNil(entries[0].lastBuildOutcome)
    }

    func testRoundTripsBuildOutcomeWhenSet() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        var entry = RegistryEntry(
            name: "Acorn", configPath: "/tmp/acorn/lutin.yml", appPath: "/tmp/acorn/app.app",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(timeIntervalSince1970: 700_000_000),
            lastOpenedDate: Date(timeIntervalSince1970: 700_000_000))
        entry.lastBuildOutcome = .succeeded
        try registry.upsert(entry)

        let reloaded = try registry.find(name: "Acorn")
        XCTAssertEqual(reloaded?.lastBuildOutcome, .succeeded)
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
