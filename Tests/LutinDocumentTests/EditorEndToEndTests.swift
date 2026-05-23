import XCTest
@testable import LutinDocument
@testable import LutinConfig

/// End-to-end coverage of the editor's intent surface: bootstrap a project,
/// run every intent the GUI can issue, save, reload, confirm every field
/// survives. If a tab's binding posts an intent the document can't honor,
/// this catches it.
final class EditorEndToEndTests: XCTestCase {
    private func bootstrap() throws -> (URL, LutinProjectDocument) {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        let configURL = try ProjectBootstrap.create(
            inputs: .init(projectName: "E2E",
                          bundleId: "com.example.e2e",
                          appPath: "/Applications/Calculator.app",
                          windowWidth: 800, windowHeight: 500),
            homeDirectory: home)
        let doc = try LutinProjectDocument(configURL: configURL)
        return (configURL, doc)
    }

    // MARK: - All intents the four tabs + canvas issue

    func testEveryIntentRoundTrips() throws {
        let (configURL, doc) = try bootstrap()

        // ── Window tab ───────────────────────────────────────────────
        try doc.apply(.setWindow(width: 720, height: nil, iconSize: nil,
                                 textSize: nil, showToolbar: nil, showSidebar: nil))
        try doc.apply(.setWindow(width: nil, height: 460, iconSize: nil,
                                 textSize: nil, showToolbar: nil, showSidebar: nil))
        try doc.apply(.setWindow(width: nil, height: nil, iconSize: 128,
                                 textSize: 14, showToolbar: true, showSidebar: true))

        // ── Project tab ──────────────────────────────────────────────
        try doc.apply(.setProjectMetadata(name: "E2E v2", bundleId: "com.example.e2e.v2"))
        try doc.apply(.setApp(path: "/Applications/Notes.app"))
        try doc.apply(.setOutput(directory: "./out", dmgName: "e2e-${version}.dmg",
                                 volumeName: "E2E"))

        // ── Release tab ──────────────────────────────────────────────
        var signing = LutinConfig.SigningInfo(enabled: true,
                                              identity: "Developer ID Application: Acme",
                                              hardenedRuntime: true,
                                              entitlements: "./entitlements.plist",
                                              signDmg: true)
        try doc.apply(.setSigning(signing))
        try doc.apply(.setNotarization(LutinConfig.NotarizationInfo(
            enabled: true, profile: "ci-notary", staple: true)))
        try doc.apply(.setSparkle(LutinConfig.SparkleInfo(
            enabled: true,
            appcastPath: "./appcast.xml",
            releaseNotesDirectory: "./release-notes",
            downloadBaseURL: "https://example.com/releases")))

        // ── Design tab: items ────────────────────────────────────────
        try doc.apply(.moveItem(id: "app", x: 250, y: 250))
        try doc.apply(.renameItemLabel(id: "app", label: "E2E App"))
        try doc.apply(.setItemHidden(id: "applications", hidden: true))
        try doc.apply(.setItemID(old: "applications", new: "apps"))
        // The arrow that referenced "applications" should now point at "apps".
        let arrow = doc.config.decorations?.first(where: { $0.type == "arrow" })
        XCTAssertEqual(arrow?.to, "apps", "setItemID must cascade into arrows")

        // ── Design tab: arrows ───────────────────────────────────────
        try doc.apply(.renameArrowLabel(from: "app", to: "apps", label: "Drag here"))
        try doc.apply(.setArrowHidden(from: "app", to: "apps", hidden: false))
        try doc.apply(.swapArrow(from: "app", to: "apps"))
        XCTAssertEqual(doc.config.decorations?.first?.from, "apps",
                       "swapArrow must reverse endpoints")
        try doc.apply(.swapArrow(from: "apps", to: "app"))   // undo

        // ── Design tab: image decorations ────────────────────────────
        try doc.apply(.addImageDecoration(path: "./logo.png", x: 100, y: 100, width: 80))
        try doc.apply(.addImageDecoration(path: "./badge.png", x: 200, y: 100, width: 80))
        try doc.apply(.moveImageDecoration(index: 1, x: 220, y: 120, width: 100))
        try doc.apply(.setImageHidden(index: 1, hidden: true))
        try doc.apply(.reorderImageDecoration(fromIndex: 1, toIndex: 2))

        // ── Canvas multi-element moves ───────────────────────────────
        try doc.apply(.moveMany(deltas: [
            .init(target: .item(id: "app"), dx: 5, dy: -5),
            .init(target: .imageDecoration(index: 1), dx: 10, dy: 10),
        ]))

        // ── Background editor: variant switching ─────────────────────
        for variantType in ["template", "solid", "gradient", "image"] {
            var bg = doc.config.background ?? LutinConfig.BackgroundInfo(
                type: variantType, template: nil, path: nil, scale: 2,
                colorA: nil, colorB: nil, grid: nil, noise: nil,
                cornerRadius: nil, angle: nil)
            bg.type = variantType
            try doc.apply(.setBackground(bg))
            XCTAssertEqual(doc.config.background?.type, variantType)
        }

        // ── Save + reload identity ───────────────────────────────────
        try doc.save()
        let reloaded = try LutinProjectDocument(configURL: configURL)
        XCTAssertEqual(reloaded.config.project.name, "E2E v2")
        XCTAssertEqual(reloaded.config.project.bundleId, "com.example.e2e.v2")
        XCTAssertEqual(reloaded.config.app.path, "/Applications/Notes.app")
        XCTAssertEqual(reloaded.config.output.directory, "./out")
        XCTAssertEqual(reloaded.config.window?.width, 720)
        XCTAssertEqual(reloaded.config.window?.height, 460)
        XCTAssertEqual(reloaded.config.window?.iconSize, 128)
        XCTAssertEqual(reloaded.config.window?.textSize, 14)
        XCTAssertEqual(reloaded.config.window?.showToolbar, true)
        XCTAssertEqual(reloaded.config.window?.showSidebar, true)
        XCTAssertEqual(reloaded.config.signing?.identity,
                       "Developer ID Application: Acme")
        XCTAssertEqual(reloaded.config.notarization?.profile, "ci-notary")
        XCTAssertEqual(reloaded.config.sparkle?.downloadBaseURL,
                       "https://example.com/releases")
        XCTAssertEqual(reloaded.config.items?.first?.label, "E2E App")
        XCTAssertEqual(reloaded.config.items?.first(where: { $0.id == "apps" })?.hidden, true)
        let reloadedArrow = reloaded.config.decorations?.first(where: { $0.type == "arrow" })
        XCTAssertEqual(reloadedArrow?.label, "Drag here")
    }

    // MARK: - Undo discipline: a complex sequence rolls back cleanly

    func testUndoRollsBackEveryIntent() throws {
        let (_, doc) = try bootstrap()
        let snapshot = doc.config

        let sequence: [DocumentIntent] = [
            .moveItem(id: "app", x: 100, y: 100),
            .renameItemLabel(id: "app", label: "Renamed"),
            .setItemHidden(id: "app", hidden: true),
            .addImageDecoration(path: "./x.png", x: 0, y: 0, width: 50),
            .setWindow(width: 1000, height: nil, iconSize: nil,
                       textSize: nil, showToolbar: nil, showSidebar: nil),
            .setProjectMetadata(name: "Other", bundleId: "com.other"),
        ]
        for intent in sequence {
            try doc.apply(intent)
        }
        XCTAssertNotEqual(doc.config.project.name, snapshot.project.name)

        // Undo each step in reverse — six undos returns to baseline.
        for _ in sequence { doc.undo() }
        XCTAssertEqual(doc.config.project.name, snapshot.project.name)
        XCTAssertEqual(doc.config.project.bundleId, snapshot.project.bundleId)
        XCTAssertEqual(doc.config.window?.width, snapshot.window?.width)
        XCTAssertEqual(doc.config.items?.first?.label, snapshot.items?.first?.label)
        XCTAssertEqual(doc.config.items?.first?.hidden, snapshot.items?.first?.hidden)
        XCTAssertEqual(doc.config.decorations?.count, snapshot.decorations?.count)
    }

    // MARK: - Delete cascade keeps the document consistent

    func testDeleteSelectionCascadesArrows() throws {
        let (_, doc) = try bootstrap()
        XCTAssertEqual(doc.config.items?.count, 2)
        XCTAssertEqual(doc.config.decorations?.count, 1) // the seeded arrow

        // Deleting "app" should remove the arrow that referenced it.
        try doc.apply(.deleteSelection(targets: [.item(id: "app")]))
        XCTAssertEqual(doc.config.items?.count, 1)
        XCTAssertEqual(doc.config.decorations?.filter { $0.type == "arrow" }.count, 0,
                       "arrow with deleted endpoint must cascade out")
    }
}
