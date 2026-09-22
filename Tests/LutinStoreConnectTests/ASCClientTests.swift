import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

private struct Probe: Decodable, Equatable, Sendable { let value: Int }

final class ASCClientTests: XCTestCase {

    private let fakeAsc = "/fake/asc"

    private func client(_ fake: FakeCommandRunner) -> ASCClient {
        ASCClient(ascPath: fakeAsc, runner: fake)
    }

    func testRunJSONDecodesAndRecordsExactArgv() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: #"{"value":7}"#, stderr: ""))
        let out = try client(fake).runJSON(["metadata", "status"], as: Probe.self)
        XCTAssertEqual(out.payload, Probe(value: 7))
        XCTAssertEqual(fake.invocations.first?.arguments, ["metadata", "status", "--output", "json"])
    }

    /// Every call goes through `--output json`; forgetting it would make asc
    /// emit a table and break decoding at runtime rather than at review time.
    func testJSONCallsAlwaysRequestJSONOutput() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: #"{"value":1}"#, stderr: ""))
        _ = try client(fake).runJSON(["metadata", "status"], as: Probe.self)
        XCTAssertTrue(fake.invocations.first?.arguments.contains("--output") == true)
        XCTAssertTrue(fake.invocations.first?.arguments.contains("json") == true)
    }

    func testRunJSONSurfacesSchemaExitTwo() {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 2, stdout: "",
                                      stderr: "Error: invalid metadata schema\nUSAGE\n  asc x"))
        XCTAssertThrowsError(try client(fake).runJSON(["metadata", "validate"], as: Probe.self)
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_schema")
        }
    }

    func testRunJSONSurfacesDecodingFailureAsStoreAscFailed() {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "not json", stderr: ""))
        XCTAssertThrowsError(try client(fake).runJSON(["metadata", "status"], as: Probe.self)
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_failed")
        }
    }

    /// `validate` exits 1 for a listing with errors, which is a *result*, not a
    /// transport failure — the caller needs the JSON to render findings.
    func testValidationFailureReturnsThePayloadRatherThanThrowing() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 1, stdout: #"{"value":3}"#, stderr: ""))
        let out = try client(fake).runAllowingValidationFailure(["metadata", "validate"])
        XCTAssertEqual(out.exitCode, 1)
        XCTAssertEqual(out.stdout, #"{"value":3}"#)
    }

    func testValidationSchemaErrorStillThrows() {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 2, stdout: "", stderr: "Error: bad schema"))
        XCTAssertThrowsError(
            try client(fake).runAllowingValidationFailure(["metadata", "validate"])
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_schema")
        }
    }
}
