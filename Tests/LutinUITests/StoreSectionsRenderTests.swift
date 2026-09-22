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

    // MARK: - Pending changes + Apply (§7.6–7.7)

    private static let reviewFixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()                       // Tests/LutinUITests
        .deletingLastPathComponent()                       // Tests
        .appendingPathComponent("LutinStoreConnectTests/Fixtures")

    private func reviewPlan() throws -> ASCReviewPlan {
        try ASCReviewPlan.decode(
            Data(contentsOf: Self.reviewFixtures.appendingPathComponent("plan.json")),
            path: "plan.json")
    }

    private func reviewStatus() throws -> ASCReviewStatus {
        try ASCReviewStatus.decode(
            Data(contentsOf: Self.reviewFixtures.appendingPathComponent("review-status.json")),
            path: "review-status.json")
    }

    private func reviewApproval() throws -> ASCReviewApproval {
        try ASCReviewApproval.decode(
            Data(contentsOf: Self.reviewFixtures.appendingPathComponent("approved.json")),
            path: "approved.json")
    }

    private func reviewStatus(_ json: String) throws -> ASCReviewStatus {
        try JSONDecoder().decode(ASCReviewStatus.self, from: Data(json.utf8))
    }

    private func reviewSection(_ state: StoreSectionState<StoreReviewModel>,
                               hasPlan: Bool = true,
                               isConfirmingApply: Bool = false,
                               applyResult: String? = nil,
                               applyFailure: StoreFailure? = nil) -> some View {
        TabBody {
            StoreReviewSection(
                state: state, hasPlan: hasPlan,
                reviewerNote: .constant("Checked the French subtitle."),
                isConfirmingApply: isConfirmingApply, isBusy: false,
                applyResult: applyResult, applyFailure: applyFailure,
                actions: StoreReviewSection.Actions(
                    plan: {}, approveKey: { _ in }, approveScope: { _ in },
                    approveAll: {}, beginApply: {}, cancelApply: {}, confirmApply: {}))
        }
    }

    /// 4 changes (2 app-info, 2 version), 1 approved: the section must paint
    /// every field/from/to/reason, the per-change controls, and the pill.
    func testPendingChangesPaintsEveryChangeWithItsApprovalState() throws {
        let model = StoreReviewModel.make(plan: try reviewPlan(), status: try reviewStatus(),
                                          approval: try reviewApproval())
        let rep = snapshot(reviewSection(.loaded(model)), name: "review")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "the section must paint the changes, not a flat rectangle")
    }

    /// A stale approval reads as a warning, not a hard error, and Apply stays
    /// disabled.
    func testAStaleApprovalPaintsAWarning() throws {
        let stale = try reviewStatus(#"{"planHash":"new","approvalPlanHash":"old","approvalMatchesPlan":false,"ready":false,"totalCount":4,"approvedCount":0,"pendingCount":4,"approvedKeys":[],"pendingKeys":[]}"#)
        let model = StoreReviewModel.make(plan: try reviewPlan(), status: stale)
        let rep = snapshot(reviewSection(.loaded(model)), name: "review-stale")
        XCTAssertGreaterThan(distinctColors(rep).count, 4)
    }

    /// asc says every change is approved: the Apply section shows the approval
    /// summary and an enabled primary button.
    func testAReadyPlanShowsTheApplySummary() throws {
        let ready = try reviewStatus(#"{"planHash":"9f2c","approvalPlanHash":"9f2c","approvalMatchesPlan":true,"ready":true,"totalCount":4,"approvedCount":4,"pendingCount":0,"approvedKeys":["app-info:en-US:name","app-info:fr-FR:subtitle","version:1.2.3:en-US:description","version:1.2.3:fr-FR:whatsNew"],"pendingKeys":[]}"#)
        let approval = try JSONDecoder().decode(
            ASCReviewApproval.self,
            from: Data(#"{"schemaVersion":1,"approvedAt":"2026-09-21T10:40:00Z","planHash":"9f2c","mode":"all","note":"Ship it.","approvedKeys":[]}"#.utf8))
        let model = StoreReviewModel.make(plan: try reviewPlan(), status: ready,
                                          approval: approval)
        XCTAssertTrue(model.isReady)
        let rep = snapshot(reviewSection(.loaded(model)), name: "review-ready")
        XCTAssertGreaterThan(distinctColors(rep).count, 4)
    }

    /// The confirm gate: the destructive line and the two choices must be
    /// unmistakable.
    func testTheConfirmGateIsUnambiguous() throws {
        let ready = try reviewStatus(#"{"planHash":"9f2c","approvalPlanHash":"9f2c","approvalMatchesPlan":true,"ready":true,"totalCount":4,"approvedCount":4,"pendingCount":0}"#)
        let model = StoreReviewModel.make(plan: try reviewPlan(), status: ready,
                                          approval: try reviewApproval())
        let rep = snapshot(reviewSection(.loaded(model), isConfirmingApply: true),
                           name: "review-confirm")
        XCTAssertGreaterThan(distinctColors(rep).count, 4)
    }

    func testAnEmptyPlanPaintsItsExplanation() throws {
        let empty = try JSONDecoder().decode(
            ASCReviewPlan.self,
            from: Data(#"{"schemaVersion":1,"planHash":"h","plan":{"adds":[],"updates":[],"deletes":[]}}"#.utf8))
        let status = try reviewStatus(#"{"planHash":"h","approvalMatchesPlan":false,"ready":true,"totalCount":0,"approvedCount":0,"pendingCount":0}"#)
        let model = StoreReviewModel.make(plan: empty, status: status)
        let rep = snapshot(reviewSection(.loaded(model)), name: "review-empty")
        XCTAssertGreaterThan(distinctColors(rep).count, 4,
                             "an empty plan must explain itself, never paint nothing")
    }

    /// No plan artifact at all: the empty state that invites `Run plan`.
    func testNoPlanPaintsTheEmptyState() {
        let rep = snapshot(reviewSection(.loaded(.empty), hasPlan: false),
                           name: "review-noplan")
        XCTAssertGreaterThan(distinctColors(rep).count, 4)
    }

    func testAFailedReviewPaintsTheSharedExplanation() {
        let failure = StoreFailure(code: "store_plan_failed",
                                   message: "No review artifact in .asc/metadata/review. Run plan first.")
        let rep = snapshot(reviewSection(.failed(failure)), name: "review-failed")
        XCTAssertGreaterThan(distinctColors(rep).count, 4)
    }
}
