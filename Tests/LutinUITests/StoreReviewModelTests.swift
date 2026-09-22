import XCTest
import LutinStoreConnect
@testable import LutinUI

/// §7.6's Pending changes, as data. Every approval fact is asserted from asc's
/// own payloads — the model never decides what is approved (§4.5).
final class StoreReviewModelTests: XCTestCase {

    // MARK: - Fixtures

    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()          // Tests/LutinUITests
        .deletingLastPathComponent()          // Tests
        .appendingPathComponent("LutinStoreConnectTests/Fixtures")

    private func plan() throws -> ASCReviewPlan {
        try ASCReviewPlan.decode(
            Data(contentsOf: Self.fixtures.appendingPathComponent("plan.json")),
            path: "plan.json")
    }

    private func status() throws -> ASCReviewStatus {
        try ASCReviewStatus.decode(
            Data(contentsOf: Self.fixtures.appendingPathComponent("review-status.json")),
            path: "review-status.json")
    }

    private func approval() throws -> ASCReviewApproval {
        try ASCReviewApproval.decode(
            Data(contentsOf: Self.fixtures.appendingPathComponent("approved.json")),
            path: "approved.json")
    }

    private func status(_ json: String) throws -> ASCReviewStatus {
        try JSONDecoder().decode(ASCReviewStatus.self, from: Data(json.utf8))
    }

    private func plan(_ json: String) throws -> ASCReviewPlan {
        try JSONDecoder().decode(ASCReviewPlan.self, from: Data(json.utf8))
    }

    // MARK: - Grouping

    func testChangesGroupByScopeAndCarryFieldFromToAndReason() throws {
        let model = StoreReviewModel.make(plan: try plan(), status: nil)

        XCTAssertEqual(model.groups.map(\.id), ["app-info", "version"])
        XCTAssertEqual(model.groups.map(\.title), ["App info", "Version"])
        XCTAssertFalse(model.isEmpty)

        let appInfo = model.groups[0]
        XCTAssertEqual(appInfo.changes.count, 2)
        let add = try XCTUnwrap(appInfo.changes.first)
        XCTAssertEqual(add.id, "app-info:en-US:name")
        XCTAssertEqual(add.field, "name")
        XCTAssertEqual(add.locale, "en-US")
        XCTAssertEqual(add.kind, .add)
        XCTAssertEqual(add.title, "name · en-US")
        XCTAssertEqual(add.transition, "→ Sayrise", "an add has no local side")
        XCTAssertEqual(add.reason, "field exists locally but not remotely")
        XCTAssertNil(add.from)
        XCTAssertEqual(add.to, "Sayrise")

        let version = model.groups[1]
        XCTAssertEqual(version.changes.map(\.kind), [.update, .delete])
        let update = version.changes[0]
        XCTAssertEqual(update.transition, "Old description. → New description.")
        XCTAssertEqual(update.reason, "field value differs")
        let delete = version.changes[1]
        XCTAssertEqual(delete.transition, "Ancienne note. →", "a delete has no local side")
        XCTAssertEqual(delete.reason, "localization missing locally")
    }

    // MARK: - Approval state comes from asc

    func testApprovedKeysFromAscsStatusMarkTheMatchingChangesOnly() throws {
        let model = StoreReviewModel.make(plan: try plan(), status: try status())

        let approved = model.groups.flatMap(\.changes).filter(\.isApproved)
        XCTAssertEqual(approved.map(\.id), ["app-info:en-US:name"],
                       "only the key in asc's approvedKeys is approved")
        XCTAssertEqual(model.groups[0].approvedCount, 1)
        XCTAssertEqual(model.groups[0].pendingCount, 1)
        XCTAssertFalse(model.isReady)
    }

    func testTheApprovalRecordSuppliesTheModeAndNote() throws {
        let model = StoreReviewModel.make(plan: try plan(), status: try status(),
                                          approval: try approval())
        XCTAssertEqual(model.approval?.mode, "key")
        XCTAssertEqual(model.approval?.note, "Checked the French subtitle against the app.")
        XCTAssertEqual(model.approval?.approvedAt, "2026-09-21T10:40:00Z")
    }

    func testAStaleApprovalIsReportedAndApplyIsNotReady() throws {
        let stale = try status(#"{"planHash":"new","approvalPlanHash":"old","approvalMatchesPlan":false,"ready":false,"totalCount":4,"approvedCount":0,"pendingCount":4,"approvedKeys":[],"pendingKeys":[]}"#)
        let model = StoreReviewModel.make(plan: try plan(), status: stale)

        XCTAssertTrue(model.isStale, "an approval against an older plan is stale")
        XCTAssertFalse(model.isReady)
    }

    // MARK: - Empty and unavailable

    func testAnEmptyPlanIsReadyWithNothingToApplyNotAnError() throws {
        let empty = try plan(#"{"schemaVersion":1,"planHash":"h","plan":{"adds":[],"updates":[],"deletes":[]}}"#)
        let status = try status(#"{"planHash":"h","approvalMatchesPlan":false,"ready":true,"totalCount":0,"approvedCount":0,"pendingCount":0}"#)
        let model = StoreReviewModel.make(plan: empty, status: status)

        XCTAssertTrue(model.isEmpty, "a plan with no changes is empty, not an error")
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertTrue(model.isReady, "asc says there is nothing to apply")
        XCTAssertEqual(model.totalCount, 0)
    }

    /// asc's numbers are asc's, not a recount of the plan: a status that
    /// disagrees with the arrays must still be rendered as asc reported it.
    func testPendingCountsComeFromAscsStatusNotFromLutinsOwnSetMath() throws {
        let status = try status(#"{"planHash":"p","approvalMatchesPlan":true,"ready":false,"totalCount":3,"approvedCount":1,"pendingCount":2,"approvedKeys":["app-info:en-US:name"],"pendingKeys":["app-info:fr-FR:subtitle","version:1.2.3:en-US:description"]}"#)
        let model = StoreReviewModel.make(plan: try plan(), status: status)

        XCTAssertEqual(model.totalCount, 3, "asc's total, not the plan's 4")
        XCTAssertEqual(model.approvedCount, 1)
        XCTAssertEqual(model.pendingCount, 2)
        XCTAssertEqual(model.groups.flatMap(\.changes).count, 4,
                       "the rows are the plan's, the counts are asc's")
    }

    func testWhenAscsStatusIsUnavailableApplyIsNotReadyAndTheModelSaysSo() throws {
        let model = StoreReviewModel.make(plan: try plan(), status: nil)

        XCTAssertFalse(model.hasStatus)
        XCTAssertFalse(model.isReady, "Lutin never guesses an approval")
        XCTAssertNil(model.approval)
    }

    func testTheEmptyModelIsTheNoPlanState() {
        XCTAssertFalse(StoreReviewModel.empty.hasStatus)
        XCTAssertFalse(StoreReviewModel.empty.isReady)
        XCTAssertTrue(StoreReviewModel.empty.isEmpty)
        XCTAssertTrue(StoreReviewModel.empty.groups.isEmpty)
    }
}
