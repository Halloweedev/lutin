import XCTest
import LutinConfig
@testable import LutinUI

final class SchemaCoverageTests: XCTestCase {
    func testEverySchemaFieldIsCovered() {
        // Build a config with every optional populated so Mirror can walk
        // each field's actual type (rather than skipping nil).
        var cfg = LutinConfig.empty(name: "X", bundleId: "c.x",
                                    appPath: "./x.app",
                                    outputDir: "o", dmgName: "x.dmg", volumeName: "X")
        cfg.window = LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                                            textSize: 12, showToolbar: true, showSidebar: false)
        cfg.background = LutinConfig.BackgroundInfo(type: "solid", template: "legacy",
                                                    path: "./bg.png", scale: 2,
                                                    colorA: "#fff", colorB: "#000",
                                                    grid: true, noise: 0.1,
                                                    cornerRadius: 4, angle: 0)
        cfg.items = [LutinConfig.Item(type: "app", id: "a", x: 0, y: 0, label: "L", hidden: false)]
        var deco = LutinConfig.Decoration(type: "arrow")
        deco.from = "a"; deco.to = "b"; deco.label = "L"
        deco.path = "./i.png"; deco.x = 0; deco.y = 0; deco.width = 10
        deco.hidden = false
        cfg.decorations = [deco]
        cfg.signing = LutinConfig.SigningInfo(enabled: false, identity: "i",
                                              hardenedRuntime: true,
                                              entitlements: "e.plist",
                                              signDmg: true)
        cfg.notarization = LutinConfig.NotarizationInfo(enabled: false, profile: "p", staple: true)
        cfg.sparkle = LutinConfig.SparkleInfo(enabled: false, appcastPath: "./a.xml",
                                              releaseNotesDirectory: "./rn",
                                              downloadBaseURL: "https://x")

        let schemaFields = SchemaCoverage.fieldsFromConfig(cfg)
        let missing = schemaFields.subtracting(SchemaCoverage.coveredFields)
        XCTAssertTrue(missing.isEmpty,
            "These LutinConfig fields are not in SchemaCoverage.coveredFields: \(missing.sorted()). Wire the field into the editor or add an explicit entry.")
    }
}
