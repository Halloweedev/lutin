import XCTest
@testable import LutinDocument
import LutinConfig

final class SetArrowHiddenIntentTests: XCTestCase {
    func testTogglesHidden() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("arrhid-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        items:
        - {type: app, id: a, x: 0, y: 0}
        - {type: applications, id: b, x: 0, y: 0}
        decorations:
        - {type: arrow, from: a, to: b}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        let doc = try LutinProjectDocument(configURL: tmp)
        try doc.apply(.setArrowHidden(from: "a", to: "b", hidden: true))
        let arrow = doc.config.decorations?.first
        XCTAssertEqual(arrow?.hidden, true)
    }
}
