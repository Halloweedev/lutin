import XCTest
@testable import LutinIntentBridge
@testable import LutinDocument
import LutinConfig

final class IntentBridgeRoundTripTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 10, y: 10}
        - {type: applications, id: b, x: 100, y: 100}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testMoveManyEnvelope() throws {
        let json = """
        [
          {"kind": "moveMany", "deltas": [
            {"kind": "item", "id": "a", "dx": 5, "dy": -3}
          ]}
        ]
        """.data(using: .utf8)!
        let doc = try makeDoc()
        try IntentBridge.applySequence(jsonData: json, to: doc)
        XCTAssertEqual(doc.config.items?[0].x, 15)
        XCTAssertEqual(doc.config.items?[0].y, 7)
    }

    func testSetWindowEnvelope() throws {
        let json = """
        [{"kind": "setWindow", "width": 800, "iconSize": 128}]
        """.data(using: .utf8)!
        let doc = try makeDoc()
        try IntentBridge.applySequence(jsonData: json, to: doc)
        XCTAssertEqual(doc.config.window?.width, 800)
        XCTAssertEqual(doc.config.window?.iconSize, 128)
    }

    func testSetItemHiddenEnvelope() throws {
        let json = """
        [{"kind": "setItemHidden", "id": "a", "hidden": true}]
        """.data(using: .utf8)!
        let doc = try makeDoc()
        try IntentBridge.applySequence(jsonData: json, to: doc)
        XCTAssertEqual(doc.config.items?.first(where: { $0.id == "a" })?.hidden, true)
    }

    func testUnknownKindThrows() throws {
        let json = """
        [{"kind": "nope"}]
        """.data(using: .utf8)!
        let doc = try makeDoc()
        XCTAssertThrowsError(try IntentBridge.applySequence(jsonData: json, to: doc))
    }
}
