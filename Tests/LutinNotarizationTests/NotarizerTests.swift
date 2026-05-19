import XCTest
import TestSupport
import LutinCore
@testable import LutinNotarization

final class NotarizerTests: XCTestCase {
    func testSubmitInvokesNotarytoolWithProfileAndWait() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0,
                    stdout: "  status: Accepted\n  id: abc-123", stderr: ""))
        try Notarizer.submit(dmg: URL(fileURLWithPath: "/tmp/Barry.dmg"),
                             profile: "lutin-notary", runner: fake)
        let call = fake.invocations.first { $0.executable.hasSuffix("xcrun") }!
        XCTAssertEqual(call.arguments.first, "notarytool")
        XCTAssertTrue(call.arguments.contains("submit"))
        XCTAssertTrue(call.arguments.contains("--keychain-profile"))
        XCTAssertTrue(call.arguments.contains("lutin-notary"))
        XCTAssertTrue(call.arguments.contains("--wait"))
    }

    func testRejectedSubmissionThrowsNotarizationRejected() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0,
                    stdout: "  status: Invalid\n  id: bad-1", stderr: ""))
        XCTAssertThrowsError(try Notarizer.submit(
            dmg: URL(fileURLWithPath: "/tmp/Barry.dmg"),
            profile: "lutin-notary", runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "notarization_rejected")
        }
    }

    func testToolFailureThrowsNotarizationFailed() {
        let fake = FakeCommandRunner()
        fake.stubFailure(executable: "/usr/bin/xcrun",
                         error: LutinError(code: "command_failed", message: "network down"))
        XCTAssertThrowsError(try Notarizer.submit(
            dmg: URL(fileURLWithPath: "/tmp/Barry.dmg"),
            profile: "lutin-notary", runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "notarization_failed")
        }
    }
}
