import XCTest
@testable import LutinDocument
import LutinConfig

final class DeleteSelectionIntentTests: XCTestCase {
    /// Loader drops `type: arrow` (drawn arrows removed). After load,
    /// `decorations` contains only the image at index 0.
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("delsel-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 1, y: 1}
        - {type: applications, id: b, x: 2, y: 2}
        decorations:
        - {type: image, path: ./i.png, x: 5, y: 5, width: 10}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testDeleteMultipleKindsInOneStep() throws {
        let doc = try makeDoc()
        try doc.apply(.deleteSelection(targets: [
            .item(id: "a"),
            .imageDecoration(index: 0),
        ]))
        XCTAssertEqual(doc.config.items?.count, 1)
        XCTAssertEqual(doc.config.items?.first?.id, "b")
        XCTAssertEqual(doc.config.decorations?.count, 0)
    }

    func testDeleteIsOneUndoStep() throws {
        let doc = try makeDoc()
        try doc.apply(.deleteSelection(targets: [.item(id: "a"), .item(id: "b")]))
        doc.undo()
        XCTAssertEqual(doc.config.items?.count, 2)
    }

    /// Image decorations no longer participate in a cascade; deleting an
    /// item leaves any decorations untouched (they're positioned in
    /// absolute coords).
    func testDeleteItemLeavesDecorationsAlone() throws {
        let doc = try makeDoc()
        try doc.apply(.deleteSelection(targets: [.item(id: "a")]))
        XCTAssertEqual(doc.config.decorations?.count, 1,
                       "image decorations survive item deletion")
    }
}
