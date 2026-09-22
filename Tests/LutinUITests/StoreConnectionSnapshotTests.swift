import XCTest
import LutinCore
@testable import LutinStoreConnect
@testable import LutinUI

/// Spec 1a §7: the Connection section must state *which* of the five failure
/// modes applies, each with its fix — and must never let a connectivity blip
/// read as an auth problem. All of that is derived here, without running asc.
final class StoreConnectionSnapshotTests: XCTestCase {

    private func status(authenticated: Bool = true,
                        hasWebSession: Bool = true,
                        appID: String? = "1234567890",
                        fileCount: Int = 4) -> StoreLogic.StoreStatusPayload {
        StoreLogic.StoreStatusPayload(
            ascVersion: "5.3.0 (commit: unknown, date: unknown)",
            authenticated: authenticated,
            hasWebSession: hasWebSession,
            appID: appID,
            fileCount: fileCount,
            storageBackend: "System Keychain",
            credential: "Sayrise",
            environmentCredentials: false,
            capabilitiesByStatus: ["cli-supported": 16, "web-session": 28])
    }

    private func failure(_ code: String,
                         details: [String: String]? = nil) -> LutinError {
        LutinError(code: code, message: "asc said no (\(code)).", details: details)
    }

    // MARK: - The healthy state

    func testReadyStatesItsFacts() {
        let snapshot = StoreConnectionSnapshot.make(status: status(), error: nil, isOnline: true)
        XCTAssertEqual(snapshot.state, .ready)
        XCTAssertTrue(snapshot.isReady)
        XCTAssertNil(snapshot.fix, "a working connection needs no fix")

        let rows = Dictionary(uniqueKeysWithValues: snapshot.rows.map { ($0.label, $0.value) })
        XCTAssertEqual(rows["asc"], "5.3.0 (commit: unknown, date: unknown)")
        XCTAssertEqual(rows["Credential"], "Sayrise")
        XCTAssertEqual(rows["Storage"], "System Keychain")
        XCTAssertEqual(rows["Environment credentials"], "not set")
        XCTAssertEqual(rows["App"], "1234567890")
        XCTAssertEqual(rows["Metadata files"], "4")
        XCTAssertEqual(rows["Capabilities"], "16 cli-supported · 28 web-session")
    }

    func testCredentialRowsFlagTheTwoIndependentCredentialFacts() {
        let snapshot = StoreConnectionSnapshot.make(status: status(), error: nil, isOnline: true)
        XCTAssertEqual(snapshot.rows.first { $0.label == "Credential" }?.isHealthy, true)
        XCTAssertEqual(snapshot.rows.first { $0.label == "Web session" }?.isHealthy, true)

        let weak = StoreConnectionSnapshot.make(
            status: status(authenticated: false, hasWebSession: false), error: nil, isOnline: true)
        XCTAssertEqual(weak.rows.first { $0.label == "Credential" }?.isHealthy, false)
        XCTAssertEqual(weak.rows.first { $0.label == "Web session" }?.isHealthy, false)
    }

    // MARK: - Status-driven states

    func testAnUnauthenticatedAscIsItsOwnModeWithAFix() {
        let snapshot = StoreConnectionSnapshot.make(
            status: status(authenticated: false), error: nil, isOnline: true)
        XCTAssertEqual(snapshot.state, .unauthenticated)
        XCTAssertNotNil(snapshot.fix)
    }

    /// A missing web session does not block validation or the preview — it is a
    /// distinct, non-blocking mode, not a dead end.
    func testAMissingWebSessionIsDistinctFromBeingUnauthenticated() {
        let snapshot = StoreConnectionSnapshot.make(
            status: status(hasWebSession: false), error: nil, isOnline: true)
        XCTAssertEqual(snapshot.state, .noWebSession)
        XCTAssertNotEqual(snapshot.state, .unauthenticated)
        XCTAssertTrue(snapshot.fix?.lowercased().contains("web auth") == true)
    }

    // MARK: - Error-driven states

    func testMissingAscIsItsOwnModeWithItsInstallFix() {
        let snapshot = StoreConnectionSnapshot.make(
            status: nil, error: failure("store_asc_missing"), isOnline: true)
        XCTAssertEqual(snapshot.state, .ascMissing)
        XCTAssertTrue(snapshot.fix?.lowercased().contains("brew install asc") == true)
    }

    func testTooOldAscCarriesTheVersionItFound() {
        let snapshot = StoreConnectionSnapshot.make(
            status: nil,
            error: failure("store_asc_too_old", details: ["found": "2.0.0"]),
            isOnline: true)
        XCTAssertEqual(snapshot.state, .ascTooOld(found: "2.0.0"))
        XCTAssertNotNil(snapshot.fix)
    }

    func testAnUnrecognisedFailureKeepsItsCodeRatherThanBorrowingAMode() {
        let snapshot = StoreConnectionSnapshot.make(
            status: nil, error: failure("store_apply_failed"), isOnline: true)
        XCTAssertEqual(snapshot.state, .unexpected(code: "store_apply_failed"))
    }

    // MARK: - Offline, and the distinction the spec insists on

    func testOfflineIsNeverReportedAsAnAuthProblem() {
        let snapshot = StoreConnectionSnapshot.make(
            status: nil, error: failure("store_unauthenticated"), isOnline: false)
        XCTAssertEqual(snapshot.state, .offline,
                       "a connectivity blip must not read as 'go log in'")
        XCTAssertEqual(snapshot.fix, StoreConnectionSnapshot.offlineNote)
        XCTAssertTrue(StoreConnectionSnapshot.offlineNote.contains("work offline"))
    }

    func testOfflineDoesNotHideAMissingAsc() {
        // Missing/too-old are local facts: connectivity cannot make them true
        // or false, so they survive being offline.
        let snapshot = StoreConnectionSnapshot.make(
            status: nil, error: failure("store_asc_missing"), isOnline: false)
        XCTAssertEqual(snapshot.state, .ascMissing)
    }

    func testAnUnknownFailureWhileOfflineReadsAsOffline() {
        let snapshot = StoreConnectionSnapshot.make(
            status: nil, error: failure("store_asc_failed"), isOnline: false)
        XCTAssertEqual(snapshot.state, .offline)
    }

    func testNoStatusYetIsHonestAboutNotKnowing() {
        let online = StoreConnectionSnapshot.make(status: nil, error: nil, isOnline: true)
        XCTAssertEqual(online.state, .unexpected(code: "store_asc_failed"))
        XCTAssertTrue(online.rows.isEmpty)
        XCTAssertNil(online.fix)

        let offline = StoreConnectionSnapshot.make(status: nil, error: nil, isOnline: false)
        XCTAssertEqual(offline.state, .offline)
    }

    // MARK: - Details survive a failure

    func testAFailureKeepsTheRowsItDidLearn() {
        let known = status()
        let snapshot = StoreConnectionSnapshot.make(
            status: known, error: failure("store_web_session_missing"), isOnline: true)
        XCTAssertEqual(snapshot.state, .noWebSession)
        XCTAssertEqual(snapshot.rows.first { $0.label == "asc" }?.value, known.ascVersion)
    }
}
