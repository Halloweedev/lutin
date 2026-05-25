import XCTest
import LutinCore
import LutinRegistry
import TestSupport
@testable import LutinDocument

final class RegistryStoreBuildOutcomeTests: XCTestCase {
    func testRecordsOutcomeForExistingEntry() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        try registry.upsert(RegistryEntry(
            name: "Acorn", configPath: "/tmp/acorn/lutin.yml", appPath: "",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(), lastOpenedDate: Date()))

        let store = RegistryStore(registry: registry)
        try store.reload()
        try store.recordBuildOutcome(name: "Acorn", outcome: .succeeded)

        let entry = try registry.find(name: "Acorn")
        XCTAssertEqual(entry?.lastBuildOutcome, .succeeded)
    }

    func testNoopsForUnknownName() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        let store = RegistryStore(registry: registry)
        try store.reload()

        // Must not throw: a failed welcome-page update must not fail a successful build.
        XCTAssertNoThrow(try store.recordBuildOutcome(name: "Ghost", outcome: .failed))
    }

    func testLeavesOtherEntriesUntouched() throws {
        let dir = try Fixtures.makeTempDirectory()
        let registry = Registry(storeURL: dir.appendingPathComponent("projects.json"))
        try registry.upsert(RegistryEntry(
            name: "Acorn", configPath: "/tmp/acorn/lutin.yml", appPath: "",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(), lastOpenedDate: Date()))
        try registry.upsert(RegistryEntry(
            name: "Bloom", configPath: "/tmp/bloom/lutin.yml", appPath: "",
            lastDetectedVersion: nil, lastReleaseStatus: nil,
            createdDate: Date(), lastOpenedDate: Date()))

        let store = RegistryStore(registry: registry)
        try store.reload()
        try store.recordBuildOutcome(name: "Acorn", outcome: .failed)

        XCTAssertEqual(try registry.find(name: "Acorn")?.lastBuildOutcome, .failed)
        XCTAssertNil(try registry.find(name: "Bloom")?.lastBuildOutcome)
    }
}
