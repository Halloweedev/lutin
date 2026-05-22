import XCTest
@testable import LutinDocument
import LutinConfig

final class ReorderAndSwapIntentTests: XCTestCase {
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
        decorations:
        - {type: arrow, from: a, to: b}
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
        try doc.apply(.addImageDecoration(path: "./x.png", x: 0, y: 0, width: 10))
        try doc.apply(.addImageDecoration(path: "./y.png", x: 0, y: 0, width: 10))
        // decorations are now: [arrow a->b, image x, image y]
        try doc.apply(.reorderImageDecoration(fromIndex: 2, toIndex: 1))
        // expected: [arrow a->b, image y, image x]
        XCTAssertEqual(doc.config.decorations?[1].path, "./y.png")
        XCTAssertEqual(doc.config.decorations?[2].path, "./x.png")
    }

    func testSwapArrow() throws {
        let doc = try makeDoc()
        try doc.apply(.swapArrow(from: "a", to: "b"))
        let arrow = doc.config.decorations?.first(where: { $0.type == "arrow" })
        XCTAssertEqual(arrow?.from, "b")
        XCTAssertEqual(arrow?.to, "a")
    }
}
