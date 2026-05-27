import XCTest
@testable import LutinUI
import LutinConfig

final class ReleaseStatusKindTests: XCTestCase {
    // MARK: - Signing

    func testSigningInactiveWhenDisabled() {
        let signing = LutinConfig.SigningInfo(
            enabled: false, identity: "ID", hardenedRuntime: true,
            entitlements: nil, signDmg: nil)
        let v = ReleaseStatusKind.signing(signing)
        XCTAssertEqual(v.kind, .inactive)
        XCTAssertEqual(v.shortLabel, "disabled")
    }

    func testSigningBlockedWhenEnabledWithoutIdentity() {
        let signing = LutinConfig.SigningInfo(
            enabled: true, identity: "", hardenedRuntime: false,
            entitlements: nil, signDmg: nil)
        let v = ReleaseStatusKind.signing(signing)
        XCTAssertEqual(v.kind, .blocked)
        XCTAssertEqual(v.shortLabel, "needs identity")
    }

    func testSigningOkWhenEnabledWithIdentity() {
        let signing = LutinConfig.SigningInfo(
            enabled: true, identity: "Developer ID Application: X",
            hardenedRuntime: true, entitlements: nil, signDmg: nil)
        let v = ReleaseStatusKind.signing(signing)
        XCTAssertEqual(v.kind, .ok)
        XCTAssertEqual(v.shortLabel, "ready")
    }

    func testSigningNilDocumentTreatedAsInactive() {
        let v = ReleaseStatusKind.signing(nil)
        XCTAssertEqual(v.kind, .inactive)
    }

    // MARK: - Notarization

    func testNotarizationInactiveWhenDisabled() {
        let n = LutinConfig.NotarizationInfo(
            enabled: false, profile: "p", staple: true)
        let v = ReleaseStatusKind.notarization(
            n, signingHardenedRuntime: true)
        XCTAssertEqual(v.kind, .inactive)
    }

    func testNotarizationBlockedWithoutProfile() {
        let n = LutinConfig.NotarizationInfo(
            enabled: true, profile: "", staple: true)
        let v = ReleaseStatusKind.notarization(
            n, signingHardenedRuntime: true)
        XCTAssertEqual(v.kind, .blocked)
        XCTAssertEqual(v.shortLabel, "needs profile")
    }

    func testNotarizationBlockedWithoutHardenedRuntime() {
        let n = LutinConfig.NotarizationInfo(
            enabled: true, profile: "p", staple: true)
        let v = ReleaseStatusKind.notarization(
            n, signingHardenedRuntime: false)
        XCTAssertEqual(v.kind, .blocked)
        XCTAssertEqual(v.shortLabel, "needs hardened runtime")
    }

    func testNotarizationWarnWithoutStaple() {
        let n = LutinConfig.NotarizationInfo(
            enabled: true, profile: "p", staple: false)
        let v = ReleaseStatusKind.notarization(
            n, signingHardenedRuntime: true)
        XCTAssertEqual(v.kind, .warn)
        XCTAssertEqual(v.shortLabel, "staple off")
    }

    func testNotarizationOkWhenEverythingSet() {
        let n = LutinConfig.NotarizationInfo(
            enabled: true, profile: "p", staple: true)
        let v = ReleaseStatusKind.notarization(
            n, signingHardenedRuntime: true)
        XCTAssertEqual(v.kind, .ok)
        XCTAssertEqual(v.shortLabel, "ready")
    }

    func testNotarizationNilTreatedAsInactive() {
        let v = ReleaseStatusKind.notarization(
            nil, signingHardenedRuntime: true)
        XCTAssertEqual(v.kind, .inactive)
        XCTAssertEqual(v.shortLabel, "disabled")
    }
}
