import XCTest
import TestSupport
@testable import LutinCore

final class FakeCommandRunnerTests: XCTestCase {
    func testRecordsInvocationsInOrder() throws {
        let fake = FakeCommandRunner()
        _ = try fake.run("/usr/bin/codesign", ["--sign", "ID", "a.app"])
        _ = try fake.run("/usr/bin/hdiutil", ["create", "x.dmg"])
        XCTAssertEqual(fake.invocations.count, 2)
        XCTAssertEqual(fake.invocations[0].executable, "/usr/bin/codesign")
        XCTAssertEqual(fake.invocations[0].arguments, ["--sign", "ID", "a.app"])
        XCTAssertEqual(fake.invocations[1].executable, "/usr/bin/hdiutil")
    }

    func testReturnsScriptedResultByExecutable() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/notarytool",
                  result: ShellResult(exitCode: 0, stdout: "status: Accepted", stderr: ""))
        let result = try fake.run("/usr/bin/notarytool", ["submit"])
        XCTAssertEqual(result.stdout, "status: Accepted")
    }

    func testScriptedFailureThrows() {
        let fake = FakeCommandRunner()
        fake.stubFailure(executable: "/usr/bin/codesign",
                         error: LutinError(code: "signing_failed", message: "bad"))
        XCTAssertThrowsError(try fake.run("/usr/bin/codesign", [])) { error in
            XCTAssertEqual((error as? LutinError)?.code, "signing_failed")
        }
    }
}
