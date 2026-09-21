import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

final class ASCAuthStateTests: XCTestCase {

    private func recorded() throws -> ASCAuthState {
        try ASCAuthState.parse(try Fixtures.data("auth-status.json"))
    }

    func testParsesTheRecordedFixture() throws {
        let state = try recorded()
        XCTAssertFalse(state.storageBackend.isEmpty)
    }

    /// The fixture is redacted at record time, so a real profile name must
    /// never reach the repository.
    func testRecordedFixtureIsRedacted() throws {
        let state = try recorded()
        for credential in state.credentials {
            XCTAssertEqual(credential.name, "REDACTED")
            XCTAssertEqual(credential.keyId, "REDACTED")
        }
    }

    func testDetectsWhetherAnyCredentialIsAvailable() throws {
        let state = try recorded()
        XCTAssertEqual(state.hasUsableCredential,
                       !state.credentials.isEmpty || state.environmentCredentialsProvided)
    }

    func testEmptyCredentialsAndNoEnvironmentMeansUnauthenticated() throws {
        let json = #"{"storageBackend":"System Keychain","credentials":[],"environmentCredentialsProvided":false,"environmentCredentialsComplete":false}"#
        let state = try ASCAuthState.parse(Data(json.utf8))
        XCTAssertFalse(state.hasUsableCredential)
    }

    func testEnvironmentCredentialsCountAsUsable() throws {
        let json = #"{"storageBackend":"None","credentials":[],"environmentCredentialsProvided":true,"environmentCredentialsComplete":true}"#
        XCTAssertTrue(try ASCAuthState.parse(Data(json.utf8)).hasUsableCredential)
    }

    func testMalformedAuthStatusRaises() {
        XCTAssertThrowsError(try ASCAuthState.parse(Data("nope".utf8))) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_failed")
        }
    }

    /// A non-zero exit from `asc auth status` is an execution failure, not an
    /// auth-state answer (an unauthenticated machine reports exit 0 with empty
    /// credentials) — so it raises `store_asc_failed`, never a login hint code.
    func testFailedAuthStatusLoadRaisesAscFailed() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/fake/asc",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: "keychain denied"))
        XCTAssertThrowsError(try ASCAuthState.load(ascPath: "/fake/asc", runner: fake)) { error in
            let e = error as? LutinError
            XCTAssertEqual(e?.code, "store_asc_failed")
            XCTAssertEqual(e?.details?["stderr"], "keychain denied")
        }
    }

    // MARK: - Web session (a different credential system)

    private func recordedWebSession() throws -> ASCWebSessionState {
        try ASCWebSessionState.parse(try Fixtures.data("web-auth-status.json"))
    }

    func testParsesTheRecordedWebSessionFixture() throws {
        _ = try recordedWebSession()   // must not throw
    }

    /// The raw output carries the Apple ID email and the developer team ID.
    /// Neither may ever reach the repository.
    func testRecordedWebSessionFixtureIsRedacted() throws {
        let state = try recordedWebSession()
        XCTAssertEqual(state.appleId, "REDACTED")
        XCTAssertEqual(state.developerTeamId, "REDACTED")
    }

    func testAuthenticatedFalseIsNotTreatedAsAvailable() throws {
        let json = #"{"authenticated":false,"passwordStored":true}"#
        XCTAssertFalse(try ASCWebSessionState.parse(Data(json.utf8)).isAvailable)
    }

    func testAuthenticatedTrueIsAvailable() throws {
        let json = #"{"authenticated":true,"passwordStored":true}"#
        XCTAssertTrue(try ASCWebSessionState.parse(Data(json.utf8)).isAvailable)
    }

    func testMalformedWebSessionRaises() {
        XCTAssertThrowsError(try ASCWebSessionState.parse(Data("nope".utf8))) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_failed")
        }
    }

    /// Review Focus: an unavailable web session must name its own fix, which is
    /// different from the API-key fix.
    func testUnavailableWebSessionRaisesItsOwnCode() {
        let state = ASCWebSessionState(authenticated: false, passwordStored: nil,
                                       appleId: nil, developerTeamId: nil)
        XCTAssertThrowsError(try state.assertAvailable(forCapability: "asc web apps create")) { error in
            let e = error as? LutinError
            XCTAssertEqual(e?.code, "store_web_session_missing")
            XCTAssertTrue(e?.message.contains("asc web auth login") == true)
        }
    }
}
