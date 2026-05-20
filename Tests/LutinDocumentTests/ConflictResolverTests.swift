import XCTest
import LutinCore
import LutinConfig
import TestSupport
@testable import LutinDocument

final class ConflictResolverTests: XCTestCase {
    private func setupDirtyDocWithExternalEdit() throws -> (LutinProjectDocument, String) {
        let dir = try Fixtures.makeTempDirectory()
        let src = Fixtures.barryConfig
        let url = dir.appendingPathComponent("lutin.yml")
        try FileManager.default.copyItem(at: src, to: url)
        // Barry has no items by default — seed one so .moveItem has something to address.
        var seeded = try LutinConfig.load(from: url)
        seeded.items = [LutinConfig.Item(type: "app", id: "app", x: 100, y: 100, label: nil)]
        try seeded.save(to: url)

        let doc = try LutinProjectDocument(configURL: url)
        try doc.apply(.moveItem(id: "app", x: 333, y: 333))
        XCTAssertTrue(doc.isDirty)
        let onDisk = "project:\n  name: Mutated\n  bundleId: com.example.barry\napp:\n  path: ./Barry.app\noutput:\n  directory: ./release\n  dmgName: Barry.dmg\n  volumeName: Barry\n"
        try onDisk.write(to: url, atomically: true, encoding: .utf8)
        return (doc, onDisk)
    }

    func testKeepMineLeavesInMemoryUntouched() throws {
        let (doc, _) = try setupDirtyDocWithExternalEdit()
        let resolver = ConflictResolver(document: doc)
        try resolver.keepMine()
        XCTAssertEqual(doc.config.items?.first { $0.id == "app" }?.x, 333)
        XCTAssertTrue(doc.isDirty)  // still need to save to persist
    }

    func testTakeDiskOverwritesInMemory() throws {
        let (doc, _) = try setupDirtyDocWithExternalEdit()
        let resolver = ConflictResolver(document: doc)
        try resolver.takeDisk()
        XCTAssertEqual(doc.config.project.name, "Mutated")
        XCTAssertFalse(doc.isDirty)
    }

    func testDiffNonEmptyForConflict() throws {
        let (doc, _) = try setupDirtyDocWithExternalEdit()
        let resolver = ConflictResolver(document: doc)
        let diff = try resolver.computeDiff()
        XCTAssertFalse(diff.hunks.isEmpty)
    }
}
