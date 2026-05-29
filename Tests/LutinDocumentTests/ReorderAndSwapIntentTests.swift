import XCTest
@testable import LutinDocument
import LutinConfig

final class ReorderAndSwapIntentTests: XCTestCase {
    /// Loader silently drops `type: arrow` (drawn arrows removed). The
    /// fixture below tests reorder behavior independent of that.
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("reorder-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 1, y: 1}
        - {type: applications, id: b, x: 2, y: 2}
        - {type: app, id: c, x: 3, y: 3}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testReorderItem() throws {
        let doc = try makeDoc()
        try doc.apply(.reorderItem(id: "a", toIndex: 2))
        XCTAssertEqual(doc.config.items?.map(\.id), ["b", "c", "a"])
    }

    func testReorderImageDecoration() throws {
        let doc = try makeDoc()
        try doc.apply(.addImageDecoration(path: "./x.png", x: 0, y: 0, width: 10, height: nil))
        try doc.apply(.addImageDecoration(path: "./y.png", x: 0, y: 0, width: 10, height: nil))
        try doc.apply(.reorderImageDecoration(fromIndex: 1, toIndex: 0))
        XCTAssertEqual(doc.config.decorations?[0].path, "./y.png")
        XCTAssertEqual(doc.config.decorations?[1].path, "./x.png")
    }
}
