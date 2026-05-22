import XCTest
@testable import LutinDocument
import LutinConfig
import LutinCore

final class MoveManyIntentTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("movemany-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 10, y: 10}
        - {type: applications, id: b, x: 100, y: 100}
        decorations:
        - {type: image, path: ./bg.png, x: 50, y: 50, width: 40}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testMoveManyAppliesAllDeltas() throws {
        let doc = try makeDoc()
        try doc.apply(.moveMany(deltas: [
            .init(target: .item(id: "a"), dx: 5, dy: -3),
            .init(target: .item(id: "b"), dx: -10, dy: 20),
            .init(target: .imageDecoration(index: 0), dx: 1, dy: 1),
        ]))
        XCTAssertEqual(doc.config.items?[0].x, 15)
        XCTAssertEqual(doc.config.items?[0].y, 7)
        XCTAssertEqual(doc.config.items?[1].x, 90)
        XCTAssertEqual(doc.config.items?[1].y, 120)
        XCTAssertEqual(doc.config.decorations?[0].x, 51)
        XCTAssertEqual(doc.config.decorations?[0].y, 51)
    }

    func testMoveManyIsOneUndoStep() throws {
        let doc = try makeDoc()
        try doc.apply(.moveMany(deltas: [
            .init(target: .item(id: "a"), dx: 5, dy: 0),
            .init(target: .item(id: "b"), dx: 5, dy: 0),
        ]))
        doc.undo()
        XCTAssertEqual(doc.config.items?[0].x, 10, "first item restored")
        XCTAssertEqual(doc.config.items?[1].x, 100, "second item restored in same undo")
    }

    func testMoveManyEmptyDeltasIsNoOp() throws {
        let doc = try makeDoc()
        let before = doc.config
        try doc.apply(.moveMany(deltas: []))
        XCTAssertEqual(doc.config.items?[0].x, before.items?[0].x)
        XCTAssertFalse(doc.isDirty, "empty moveMany should not dirty the document")
    }

    func testMoveManyUnknownIdThrows() throws {
        let doc = try makeDoc()
        XCTAssertThrowsError(try doc.apply(.moveMany(deltas: [
            .init(target: .item(id: "nonexistent"), dx: 1, dy: 1)
        ]))) { error in
            guard let lutinError = error as? LutinError else { return XCTFail("wrong error type") }
            XCTAssertEqual(lutinError.code, "editor_item_not_found")
        }
    }
}
