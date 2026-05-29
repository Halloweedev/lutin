import XCTest
@testable import LutinDocument
import LutinConfig

final class ImageDecorationIntentTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("imgdec-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testAddImageDecorationAppends() throws {
        let doc = try makeDoc()
        try doc.apply(.addImageDecoration(path: "./logo.png", x: 20, y: 30, width: 100, height: nil))
        XCTAssertEqual(doc.config.decorations?.count, 1)
        let d = doc.config.decorations?.first
        XCTAssertEqual(d?.type, "image")
        XCTAssertEqual(d?.path, "./logo.png")
        XCTAssertEqual(d?.x, 20)
        XCTAssertEqual(d?.y, 30)
        XCTAssertEqual(d?.width, 100)
    }

    func testMoveImageDecorationUpdatesGeometry() throws {
        let doc = try makeDoc()
        try doc.apply(.addImageDecoration(path: "./logo.png", x: 20, y: 30, width: 100, height: nil))
        try doc.apply(.moveImageDecoration(index: 0, x: 50, y: 60, width: 120, height: 80))
        let d = doc.config.decorations?.first
        XCTAssertEqual(d?.x, 50)
        XCTAssertEqual(d?.y, 60)
        XCTAssertEqual(d?.width, 120)
        XCTAssertEqual(d?.height, 80)
    }

    // A move that passes height: nil must leave an existing explicit height
    // untouched (so a reposition that omits height never wipes a stretch).
    func testMoveImageDecorationNilHeightPreservesExisting() throws {
        let doc = try makeDoc()
        try doc.apply(.addImageDecoration(path: "./logo.png", x: 0, y: 0, width: 100, height: 40))
        try doc.apply(.moveImageDecoration(index: 0, x: 10, y: 20, width: 100, height: nil))
        let d = doc.config.decorations?.first
        XCTAssertEqual(d?.x, 10)
        XCTAssertEqual(d?.y, 20)
        XCTAssertEqual(d?.height, 40, "nil height must not clear the existing stretch")
    }

    func testDeleteImageDecorationRemoves() throws {
        let doc = try makeDoc()
        try doc.apply(.addImageDecoration(path: "./a.png", x: 0, y: 0, width: 10, height: nil))
        try doc.apply(.addImageDecoration(path: "./b.png", x: 0, y: 0, width: 10, height: nil))
        try doc.apply(.deleteImageDecoration(index: 0))
        XCTAssertEqual(doc.config.decorations?.count, 1)
        XCTAssertEqual(doc.config.decorations?.first?.path, "./b.png")
    }
}
