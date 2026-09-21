import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

final class ASCLocatorTests: XCTestCase {

    func testExplicitPathWins() throws {
        let fake = FakeCommandRunner()
        let path = try ASCLocator.resolve(explicit: "/custom/asc", ascPath: nil,
                                          runner: fake, isExecutable: { _ in true })
        XCTAssertEqual(path, "/custom/asc")
        XCTAssertTrue(fake.invocations.isEmpty, "An explicit path must not shell out.")
    }

    func testKnownHomebrewPathsAreCheckedBeforePATH() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "/somewhere/asc\n", stderr: ""))
        let path = try ASCLocator.resolve(explicit: nil, ascPath: nil, runner: fake,
                                          isExecutable: { $0 == "/opt/homebrew/bin/asc" })
        XCTAssertEqual(path, "/opt/homebrew/bin/asc")
    }

    func testFallsBackToWhich() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "/custom/bin/asc\n", stderr: ""))
        let path = try ASCLocator.resolve(explicit: nil, ascPath: nil, runner: fake,
                                          isExecutable: { $0 == "/custom/bin/asc" })
        XCTAssertEqual(path, "/custom/bin/asc")
    }

    func testMissingBinaryRaisesStoreAscMissing() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: ""))
        XCTAssertThrowsError(try ASCLocator.resolve(explicit: nil, ascPath: nil, runner: fake,
                                                    isExecutable: { _ in false })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_missing")
        }
    }

    /// A `store.ascPath` that does not exist is the user's mistake and must say so.
    func testNonExecutableExplicitPathRaises() {
        let fake = FakeCommandRunner()
        XCTAssertThrowsError(try ASCLocator.resolve(explicit: nil, ascPath: "/nope/asc",
                                                    runner: fake, isExecutable: { _ in false })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_missing")
            XCTAssertEqual((error as? LutinError)?.details?["ascPath"], "/nope/asc")
        }
    }

    func testKnownPathsMatchTheExistingResolver() {
        XCTAssertEqual(ASCLocator.knownPaths,
                       ["/opt/homebrew/bin/asc", "/usr/local/bin/asc"])
    }
}
