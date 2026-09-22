import XCTest
import LutinCore
@testable import LutinStoreConnect

/// The review artifacts are asc's, decoded verbatim (§4.5). These tests pin
/// the contract from asc 5.3.0's `internal/cli/metadata/review.go` — the key
/// formats, the reason strings, and the pinned `schemaVersion`.
final class ReviewArtifactDecodingTests: XCTestCase {

    // MARK: - plan.json

    func testPlanDecodesTheThreeArraysAndEveryChange() throws {
        let plan = try ASCReviewPlan.decode(try Fixtures.data("plan.json"),
                                            path: "/tmp/lutin-review/plan.json")
        XCTAssertEqual(plan.schemaVersion, 1)
        XCTAssertEqual(plan.planHash,
                       "9f2c1b0e5d4a3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f1e0d9c8b")
        XCTAssertEqual(plan.generatedAt, "2026-09-21T10:36:24Z")
        XCTAssertEqual(plan.plan.adds.count, 2)
        XCTAssertEqual(plan.plan.updates.count, 1)
        XCTAssertEqual(plan.plan.deletes.count, 1)
        XCTAssertEqual(plan.changes.count, 4, "adds, then updates, then deletes")
        // `appId` / `versionId` are asc's keys; the model renames them.
        XCTAssertEqual(plan.plan.appID, "1234567890")
        XCTAssertEqual(plan.plan.versionID, "version-1")
        XCTAssertEqual(plan.plan.version, "1.2.3")
    }

    func testPlanKeysAndReasonsMatchAscsFormats() throws {
        let plan = try ASCReviewPlan.decode(try Fixtures.data("plan.json"),
                                            path: "/tmp/lutin-review/plan.json")
        // app-info keys are scope:locale:field …
        let add = plan.plan.adds[0]
        XCTAssertEqual(add.key, "app-info:en-US:name")
        XCTAssertEqual(add.scope, "app-info")
        XCTAssertEqual(add.locale, "en-US")
        XCTAssertNil(add.version, "app-info items carry no version")
        XCTAssertEqual(add.field, "name")
        XCTAssertEqual(add.reason, "field exists locally but not remotely")
        XCTAssertNil(add.from)
        XCTAssertEqual(add.to, "Sayrise")
        // … version keys are scope:version:locale:field.
        let update = plan.plan.updates[0]
        XCTAssertEqual(update.key, "version:1.2.3:en-US:description")
        XCTAssertEqual(update.scope, "version")
        XCTAssertEqual(update.version, "1.2.3")
        XCTAssertEqual(update.reason, "field value differs")
        XCTAssertEqual(update.from, "Old description.")
        XCTAssertEqual(update.to, "New description.")
        let delete = plan.plan.deletes[0]
        XCTAssertEqual(delete.key, "version:1.2.3:fr-FR:whatsNew")
        XCTAssertEqual(delete.reason, "localization missing locally")
        XCTAssertEqual(delete.from, "Ancienne note.")
        XCTAssertNil(delete.to, "a delete has nothing on the local side")
    }

    func testAPlanWithAnUnsupportedSchemaVersionIsASchemaError() throws {
        let json = #"{"schemaVersion":2,"planHash":"h","plan":{"adds":[],"updates":[],"deletes":[]}}"#
        XCTAssertThrowsError(
            try ASCReviewPlan.decode(Data(json.utf8), path: "/tmp/plan.json")
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["path"], "/tmp/plan.json")
        }
    }

    func testAPlanWithAnUnknownTopLevelKeyStillDecodes() throws {
        // asc may add fields; schemaVersion is the pinned contract, not the key
        // set.
        let json = #"{"schemaVersion":1,"planHash":"h","futureField":{"a":1},"plan":{"adds":[],"updates":[],"deletes":[]}}"#
        let plan = try ASCReviewPlan.decode(Data(json.utf8), path: "/tmp/plan.json")
        XCTAssertEqual(plan.planHash, "h")
        XCTAssertTrue(plan.changes.isEmpty)
    }

    func testAMalformedPlanNamesTheFile() throws {
        XCTAssertThrowsError(
            try ASCReviewPlan.decode(Data("not json".utf8), path: "/tmp/broken/plan.json")
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["path"], "/tmp/broken/plan.json")
        }
    }

    // MARK: - approved.json

    func testApprovalDecodesModeNoteAndKeys() throws {
        let approval = try ASCReviewApproval.decode(try Fixtures.data("approved.json"),
                                                    path: "/tmp/lutin-review/approved.json")
        XCTAssertEqual(approval.schemaVersion, 1)
        XCTAssertEqual(approval.mode, "key")
        XCTAssertEqual(approval.note, "Checked the French subtitle against the app.")
        XCTAssertEqual(approval.approvedAt, "2026-09-21T10:40:00Z")
        XCTAssertEqual(approval.approvedKeys, ["app-info:en-US:name"])
    }

    func testAnApprovalWithAnUnsupportedSchemaVersionIsASchemaError() throws {
        let json = #"{"schemaVersion":2,"planHash":"h","mode":"all","approvedKeys":[]}"#
        XCTAssertThrowsError(
            try ASCReviewApproval.decode(Data(json.utf8), path: "/tmp/approved.json")
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["path"], "/tmp/approved.json")
        }
    }

    // MARK: - asc metadata status --output json

    func testStatusDecodesReadyCountsAndMatchingPlan() throws {
        let status = try ASCReviewStatus.decode(try Fixtures.data("review-status.json"),
                                                path: "/tmp/lutin-review")
        XCTAssertEqual(status.planHash,
                       "9f2c1b0e5d4a3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f1e0d9c8b")
        XCTAssertEqual(status.approvalPlanHash, status.planHash)
        XCTAssertTrue(status.approvalMatchesPlan)
        XCTAssertFalse(status.ready, "3 of 4 changes are still pending")
        XCTAssertEqual(status.totalCount, 4)
        XCTAssertEqual(status.approvedCount, 1)
        XCTAssertEqual(status.pendingCount, 3)
        XCTAssertEqual(status.approvedKeys, ["app-info:en-US:name"])
        XCTAssertFalse(status.isStale)
    }

    func testStatusWithoutAnApprovalDecodesTheOptionalKeys() throws {
        // asc omits approvalPlanHash/approvedKeys/pendingKeys when nothing has
        // been approved; the decoder must not require them.
        let json = #"{"reviewDir":"r","planPath":"p","approvalPath":"a","planHash":"h","approvalMatchesPlan":false,"ready":false,"totalCount":2,"approvedCount":0,"pendingCount":2}"#
        let status = try ASCReviewStatus.decode(Data(json.utf8), path: "r")
        XCTAssertNil(status.approvalPlanHash)
        XCTAssertEqual(status.approvedKeys, [])
        XCTAssertEqual(status.pendingKeys, [])
        XCTAssertFalse(status.isStale, "no approval is not a stale approval")
    }

    /// An approval made against a different plan: the UI says so and keeps
    /// Apply disabled.
    func testAnApprovalAgainstADifferentPlanIsStale() throws {
        let json = #"{"planHash":"new","approvalPlanHash":"old","approvalMatchesPlan":false,"ready":false,"totalCount":1,"approvedCount":0,"pendingCount":1}"#
        let status = try ASCReviewStatus.decode(Data(json.utf8), path: "r")
        XCTAssertTrue(status.isStale)
    }

    func testAMalformedStatusNamesTheReviewDir() throws {
        XCTAssertThrowsError(
            try ASCReviewStatus.decode(Data("not json".utf8), path: "/tmp/broken")
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["path"], "/tmp/broken")
        }
    }
}
