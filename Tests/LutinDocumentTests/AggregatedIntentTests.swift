import XCTest
@testable import LutinDocument
import LutinConfig

final class AggregatedIntentTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agg-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        window: {width: 680, height: 420, iconSize: 96}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testSetWindowPartialPatch() throws {
        let doc = try makeDoc()
        try doc.apply(.setWindow(width: 800, height: nil, iconSize: nil,
                                 textSize: nil, showToolbar: nil, showSidebar: nil))
        XCTAssertEqual(doc.config.window?.width, 800)
        XCTAssertEqual(doc.config.window?.height, 420, "unspecified field unchanged")
        XCTAssertEqual(doc.config.window?.iconSize, 96)
    }

    func testSetProjectMetadata() throws {
        let doc = try makeDoc()
        try doc.apply(.setProjectMetadata(name: "NewName", bundleId: "com.new.id"))
        XCTAssertEqual(doc.config.project.name, "NewName")
        XCTAssertEqual(doc.config.project.bundleId, "com.new.id")
    }

    func testSetAppPath() throws {
        let doc = try makeDoc()
        try doc.apply(.setApp(path: "./new.app"))
        XCTAssertEqual(doc.config.app.path, "./new.app")
    }

    func testSetOutputAllThree() throws {
        let doc = try makeDoc()
        try doc.apply(.setOutput(directory: "rel", dmgName: "n.dmg", volumeName: "V"))
        XCTAssertEqual(doc.config.output.directory, "rel")
        XCTAssertEqual(doc.config.output.dmgName, "n.dmg")
        XCTAssertEqual(doc.config.output.volumeName, "V")
    }
}
