import XCTest
@testable import LutinDocument
import LutinConfig

final class StructReplaceIntentTests: XCTestCase {
    private func makeDoc() throws -> LutinProjectDocument {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("repl-\(UUID().uuidString).yml")
        try """
        project: {name: T, bundleId: c.t}
        app: {path: ./x.app}
        output: {directory: out, dmgName: t.dmg, volumeName: T}
        """.write(to: tmp, atomically: true, encoding: .utf8)
        return try LutinProjectDocument(configURL: tmp)
    }

    func testSetBackgroundReplaces() throws {
        let doc = try makeDoc()
        var bg = LutinConfig.BackgroundInfo(
            type: "gradient", template: nil, path: nil, scale: nil,
            colorA: "#fff", colorB: "#000", grid: nil, noise: nil, cornerRadius: nil, angle: 90)
        bg.colorA = "#fff"
        bg.colorB = "#000"
        bg.angle = 90
        try doc.apply(.setBackground(bg))
        XCTAssertEqual(doc.config.background?.type, "gradient")
        XCTAssertEqual(doc.config.background?.angle, 90)
    }

    func testSetSigningReplaces() throws {
        let doc = try makeDoc()
        var s = LutinConfig.SigningInfo(
            enabled: true, identity: nil, hardenedRuntime: nil, entitlements: nil, signDmg: nil)
        s.identity = "Developer ID Application: X"
        try doc.apply(.setSigning(s))
        XCTAssertEqual(doc.config.signing?.enabled, true)
        XCTAssertEqual(doc.config.signing?.identity, "Developer ID Application: X")
    }

    func testSetNotarizationReplaces() throws {
        let doc = try makeDoc()
        var n = LutinConfig.NotarizationInfo(enabled: true, profile: nil, staple: nil)
        n.profile = "ci-notary"
        try doc.apply(.setNotarization(n))
        XCTAssertEqual(doc.config.notarization?.profile, "ci-notary")
    }

    func testSetSparkleReplaces() throws {
        let doc = try makeDoc()
        var sp = LutinConfig.SparkleInfo(
            enabled: true, appcastPath: nil, releaseNotesDirectory: nil, downloadBaseURL: nil)
        sp.appcastPath = "./appcast.xml"
        try doc.apply(.setSparkle(sp))
        XCTAssertEqual(doc.config.sparkle?.appcastPath, "./appcast.xml")
    }
}
