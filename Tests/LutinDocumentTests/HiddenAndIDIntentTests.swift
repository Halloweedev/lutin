import XCTest
@testable import LutinDocument
import LutinConfig
import LutinCore

final class HiddenAndIDIntentTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("hidden-\(UUID().uuidString).yml")
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

    func testSetItemHiddenTogglesField() throws {
        let doc = try makeDoc()
        try doc.apply(.setItemHidden(id: "a", hidden: true))
        XCTAssertEqual(doc.config.items?.first(where: { $0.id == "a" })?.hidden, true)
        try doc.apply(.setItemHidden(id: "a", hidden: false))
        XCTAssertEqual(doc.config.items?.first(where: { $0.id == "a" })?.hidden, false)
    }

    func testSetImageHiddenTogglesField() throws {
        let doc = try makeDoc()
        try doc.apply(.setImageHidden(index: 0, hidden: true))
        XCTAssertEqual(doc.config.decorations?[0].hidden, true)
    }

    func testSetItemIDRenames() throws {
        let doc = try makeDoc()
        try doc.apply(.setItemID(old: "a", new: "lutin"))
        XCTAssertEqual(doc.config.items?.first?.id, "lutin")
    }

    func testSetItemIDCollisionRejected() throws {
        let doc = try makeDoc()
        XCTAssertThrowsError(try doc.apply(.setItemID(old: "a", new: "b"))) { err in
            XCTAssertEqual((err as? LutinError)?.code, "editor_id_collision")
        }
    }

    func testSetItemIDEmptyRejected() throws {
        let doc = try makeDoc()
        XCTAssertThrowsError(try doc.apply(.setItemID(old: "a", new: "  "))) { err in
            XCTAssertEqual((err as? LutinError)?.code, "editor_invalid_id")
        }
    }
}
