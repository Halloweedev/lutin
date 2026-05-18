import XCTest
@testable import LutinCore

final class ShellTests: XCTestCase {
    func testCapturesStdout() throws {
        let result = try Shell.run("/bin/echo", ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertTrue(result.stderr.isEmpty)
    }

    func testNonZeroExitThrowsLutinError() {
        XCTAssertThrowsError(try Shell.run("/bin/sh", ["-c", "echo oops 1>&2; exit 3"])) { error in
            guard let lutin = error as? LutinError else { return XCTFail("wrong error type") }
            XCTAssertEqual(lutin.code, "command_failed")
            XCTAssertEqual(lutin.details?["exitCode"], "3")
            XCTAssertTrue((lutin.details?["stderr"] ?? "").contains("oops"))
        }
    }

    func testCheckExitFalseReturnsResultInsteadOfThrowing() throws {
        let result = try Shell.run("/bin/sh", ["-c", "exit 7"], checkExit: false)
        XCTAssertEqual(result.exitCode, 7)
    }
}
