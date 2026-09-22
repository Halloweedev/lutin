import AppKit
import SwiftUI
import XCTest
import LutinCore
import LutinStoreConnect
import LutinStoreMetadata
@testable import LutinUI

/// §8's rule for this surface: a render test per Store-surface change, and
/// then actually look at the PNG. `LUTIN_PREVIEW_DUMP=1` writes them to /tmp.
@MainActor
final class StoreSectionsRenderTests: XCTestCase {

    /// The column's real width, from the audit (the panel is ~430 pt).
    static let panelWidth: CGFloat = 430

    private func snapshot<V: View>(_ view: V, height: CGFloat = 720,
                                   name: String) -> NSBitmapImageRep {
        snapshotPNG(view, size: CGSize(width: Self.panelWidth, height: height),
                    dumpName: "lutin-store-\(name)")
    }

    private func distinctColors(_ rep: NSBitmapImageRep) -> Set<UInt32> {
        sampledColors(rep)
    }

    private func report(_ issues: [StoreMetadataIssue], offline: Bool = false,
                        fileCount: Int = 4) -> StoreLogic.StoreValidateReport {
        StoreLogic.StoreValidateReport(
            fileCount: fileCount, issues: issues, offline: offline,
            errorCount: issues.filter(\.isError).count,
            warningCount: issues.filter { !$0.isError }.count,
            valid: !issues.contains(where: \.isError))
    }

    private func section(_ state: StoreSectionState<StoreValidationModel>) -> some View {
        TabBody {
            StoreValidationSection(state: state, onRecheck: {})
        }
    }

    private func appSection(_ state: StoreSectionState<StoreAppModel>) -> some View {
        TabBody {
            StoreAppSection(state: state)
        }
    }

    private func versionsSection(_ state: StoreSectionState<StoreVersionsModel>) -> some View {
        TabBody {
            StoreVersionsSection(state: state)
        }
    }

    /// An error and a warning, in two scopes and two locales: the section must
    /// paint both, plus the two scope headers and the status line.
    func testLoadedValidationWithAnErrorAndAWarningPaints() {
        let model = StoreValidationModel.make(report: report([
            StoreMetadataIssue(scope: "app-info", locale: "en-US", field: "name",
                               severity: "error",
                               message: "name is 41 characters; the limit is 30",
                               length: 41, limit: 30),
            StoreMetadataIssue(scope: "version", locale: "fr-FR", field: "description",
                               severity: "warning",
                               message: "description is shorter than the 10 characters "
                                      + "App Store Connect recommends"),
        ]))
        let rep = snapshot(section(.loaded(model)), name: "validation")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the section must paint findings, not a flat rectangle")
    }

    /// asc absent: the offline subset is the degraded explanation (§7), and it
    /// must paint rather than leave the section empty.
    func testOfflineCleanValidationPaintsTheDegradedExplanation() {
        let model = StoreValidationModel.make(report: report([], offline: true))
        let rep = snapshot(section(.loaded(model)), name: "validation-offline")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the offline subset must paint its explanation")
    }

    /// A validation failure the engine could not turn into findings still
    /// degrades to an explanation with the shared fix, never an empty state.
    func testFailedValidationPaintsTheExplanation() {
        let failure = StoreFailure(code: "store_asc_failed",
                                   message: "asc exited 2: json: unknown field \"bogusField\"")
        let rep = snapshot(section(.failed(failure)), name: "validation-failed")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "a failed section must still paint an explanation")
    }

    // MARK: - App (§7.2)

    func testTheResolvedAppPaints() {
        let model = StoreAppModel.make(
            app: ASCApp(id: "1234567890", name: "MyApp", bundleID: "com.example.myapp",
                        sku: "MYAPP", primaryLocale: "en-US"),
            appID: "1234567890", bundleID: "com.example.myapp", platform: "MAC_OS")
        let rep = snapshot(appSection(.loaded(model)), name: "app")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the App section must paint its rows and its footer note")
    }

    /// §4.2's failure mode: a mismatched bundleID is an error, never a calm row
    /// of data. It must read as blocked, with the fix.
    func testTheBundledMismatchReadsAsBlockedWithItsFix() {
        let failure = mismatchFailure
        XCTAssertNotNil(failure.fix)
        let rep = snapshot(appSection(.failed(failure)), name: "app-mismatch")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the mismatch must paint the blocked row and the fix")
    }

    /// The invariant behind the duplicate-fix finding: a failure's fix hint is
    /// drawn in exactly one place — `StoreSectionFailure`. A section body that
    /// mentions `failure.fix` re-introduces the duplicate, and this scan fails
    /// when that comes back; the value-level assertion it replaces could not.
    func testOnlyTheSharedFailureViewDrawsAFixHint() throws {
        let storeDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // Tests/LutinUITests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("Sources/LutinUI/Store")
        let files = try FileManager.default.contentsOfDirectory(at: storeDir,
                                                               includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "the scan must find the Store sources")
        for file in files where file.lastPathComponent != "StoreSectionState.swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(source.contains("failure.fix"),
                           "\(file.lastPathComponent) draws a failure's fix itself — use StoreSectionFailure")
        }
    }

    private var mismatchFailure: StoreFailure {
        StoreFailure(LutinError(
            code: "store_bundle_id_mismatch",
            message: "store.bundleID is com.other.app, but the resolved app "
                   + "1234567890 is com.example.myapp.",
            details: ["expected": "com.other.app"]))
    }

    // MARK: - Versions (§7.3)

    func testTheVersionsListPaintsNewestFirstWithItsPill() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()                       // Tests/LutinUITests
            .deletingLastPathComponent()                       // Tests
            .appendingPathComponent("LutinStoreConnectTests/Fixtures/versions-list.json")
        let data = try Data(contentsOf: fixture)
        let model = StoreVersionsModel.make(
            versions: try ASCAppStoreVersion.decodeList(data), platform: "MAC_OS")
        XCTAssertEqual(model.versions.first?.versionString, "2.0")
        let rep = snapshot(versionsSection(.loaded(model)), name: "versions")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the Versions section must paint the rows and the count pill")
    }

    func testAnEmptyVersionsListPaintsItsExplanation() {
        let model = StoreVersionsModel.make(versions: [], platform: "MAC_OS")
        let rep = snapshot(versionsSection(.loaded(model)), name: "versions-empty")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "an empty list must explain itself, never paint nothing")
    }
}
