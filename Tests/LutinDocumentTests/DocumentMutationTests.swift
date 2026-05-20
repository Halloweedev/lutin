import XCTest
import LutinCore
import LutinConfig
import TestSupport
@testable import LutinDocument

final class DocumentMutationTests: XCTestCase {
    /// Barry's fixture has no items; seed one labelled "app" so movement
    /// intents have something to address. Each test gets its own temp copy.
    private func tempCopyOfBarry() throws -> URL {
        let dir = try Fixtures.makeTempDirectory()
        let src = Fixtures.barryConfig
        let dst = dir.appendingPathComponent("lutin.yml")
        try FileManager.default.copyItem(at: src, to: dst)
        var config = try LutinConfig.load(from: dst)
        config.items = [LutinConfig.Item(type: "app", id: "app", x: 100, y: 100, label: nil)]
        try config.save(to: dst)
        return dst
    }

    func testMoveItemSetsDirty() throws {
        let url = try tempCopyOfBarry()
        let doc = try LutinProjectDocument(configURL: url)
        XCTAssertFalse(doc.isDirty)
        try doc.apply(.moveItem(id: "app", x: 200, y: 240))
        XCTAssertTrue(doc.isDirty)
        XCTAssertEqual(doc.config.items?.first(where: { $0.id == "app" })?.x, 200)
    }

    func testSaveWritesAtomicallyAndClearsDirty() throws {
        let url = try tempCopyOfBarry()
        let doc = try LutinProjectDocument(configURL: url)
        try doc.apply(.moveItem(id: "app", x: 240, y: 200))
        try doc.save()
        XCTAssertFalse(doc.isDirty)

        let reloaded = try LutinProjectDocument(configURL: url)
        XCTAssertEqual(reloaded.config.items?.first(where: { $0.id == "app" })?.x, 240)
    }

    func testUndoRevertsMove() throws {
        let url = try tempCopyOfBarry()
        let doc = try LutinProjectDocument(configURL: url)
        let originalX = doc.config.items?.first(where: { $0.id == "app" })?.x ?? 0
        try doc.apply(.moveItem(id: "app", x: 999, y: 999))
        doc.undo()
        XCTAssertEqual(doc.config.items?.first(where: { $0.id == "app" })?.x, originalX)
    }
}
