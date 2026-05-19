import XCTest
import TestSupport
import LutinCore
@testable import LutinNotarization

final class StaplerTests: XCTestCase {
    func testStapleInvokesStaplerStaple() throws {
        let fake = FakeCommandRunner()
        try Stapler.staple(URL(fileURLWithPath: "/tmp/Barry.dmg"), runner: fake)
        let calls = fake.invocations.filter { $0.executable.hasSuffix("xcrun") }
        XCTAssertEqual(calls.first?.arguments.first, "stapler")
        XCTAssertTrue(calls.first!.arguments.contains("staple"))
        XCTAssertTrue(calls.first!.arguments.contains("/tmp/Barry.dmg"))
    }

    func testStapleFailureThrowsStapleFailed() {
        let fake = FakeCommandRunner()
        fake.stubFailure(executable: "/usr/bin/xcrun",
                         error: LutinError(code: "command_failed", message: "no ticket"))
        XCTAssertThrowsError(try Stapler.staple(
            URL(fileURLWithPath: "/tmp/Barry.dmg"), runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "staple_failed")
        }
    }
}
