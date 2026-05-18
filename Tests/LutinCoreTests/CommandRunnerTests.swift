import XCTest
@testable import LutinCore

final class CommandRunnerTests: XCTestCase {
    func testShellCommandRunnerCapturesOutput() throws {
        let runner: CommandRunning = ShellCommandRunner()
        let result = try runner.run("/bin/echo", ["hi"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hi")
    }

    func testShellCommandRunnerThrowsOnNonZeroExit() {
        let runner: CommandRunning = ShellCommandRunner()
        XCTAssertThrowsError(try runner.run("/bin/sh", ["-c", "exit 4"])) { error in
            XCTAssertEqual((error as? LutinError)?.code, "command_failed")
        }
    }
}
