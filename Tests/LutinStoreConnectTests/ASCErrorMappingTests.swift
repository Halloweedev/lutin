import XCTest
@testable import LutinStoreConnect
import LutinCore

final class ASCErrorMappingTests: XCTestCase {

    private func result(_ code: Int32, out: String = "", err: String = "") -> ShellResult {
        ShellResult(exitCode: code, stdout: out, stderr: err)
    }

    // MARK: - Exit 2: schema errors

    /// Review Focus #3: asc prints the error line and then its full help text.
    /// Only the first line is the error.
    func testSchemaErrorTakesOnlyTheFirstStderrLine() throws {
        let stderr = try Fixtures.text("validate-schema.stderr")
        let first = ASCErrorMapping.firstLine(of: stderr)
        XCTAssertTrue(first.hasPrefix("Error:"))
        XCTAssertFalse(first.contains("USAGE"), "Help text leaked into the message.")
        XCTAssertFalse(first.contains("--check-urls"), "Help text leaked into the message.")
    }

    func testSchemaErrorMapsToStoreMetadataSchema() {
        let mapped = ASCErrorMapping.map(
            result: result(2, err: "Error: invalid metadata schema in /x/en-US.json: json: unknown field \"bogus\"\nUSAGE\n  asc metadata validate"),
            command: ["metadata", "validate"], fallbackCode: "store_asc_failed")
        XCTAssertEqual(mapped.code, "store_metadata_schema")
        XCTAssertTrue(mapped.message.contains("unknown field"))
        XCTAssertFalse(mapped.message.contains("USAGE"))
        XCTAssertEqual(mapped.details?["ascCommand"], "asc metadata validate")
    }

    func testSchemaExitCodeIsRecognisedRegardlessOfStderrWording() {
        let mapped = ASCErrorMapping.map(result: result(2, err: "something unexpected"),
                                         command: ["metadata", "validate"],
                                         fallbackCode: "store_asc_failed")
        XCTAssertEqual(mapped.code, "store_metadata_schema")
    }

    // MARK: - Exit 1: validation errors

    func testValidationFailureMapsToStoreValidationFailed() {
        let mapped = ASCErrorMapping.map(result: result(1, out: #"{"valid":false,"errorCount":1}"#),
                                         command: ["metadata", "validate"],
                                         fallbackCode: "store_asc_failed")
        XCTAssertEqual(mapped.code, "store_validation_failed")
        XCTAssertEqual(mapped.details?["exitCode"], "1")
    }

    // MARK: - Auth

    /// Review Focus #2: an installed but unauthenticated asc must never be
    /// reported as missing — that sends the user to reinstall a tool they have.
    func testAuthFailureMapsToStoreUnauthenticated() {
        for marker in ["unauthorized", "401", "api key", "issuer", "credential"] {
            let mapped = ASCErrorMapping.map(
                result: result(1, err: "Error: \(marker) rejected"),
                command: ["metadata", "plan"], fallbackCode: "store_plan_failed")
            XCTAssertEqual(mapped.code, "store_unauthenticated",
                           "Marker '\(marker)' should map to store_unauthenticated.")
        }
    }

    func testAuthFailureNeverMapsToAscMissing() {
        let mapped = ASCErrorMapping.map(result: result(1, err: "unauthorized"),
                                         command: ["metadata", "plan"],
                                         fallbackCode: "store_plan_failed")
        XCTAssertNotEqual(mapped.code, "store_asc_missing")
    }

    /// A word that merely embeds "auth" (e.g. "author" in app metadata) must
    /// not be misreported as an authentication failure.
    func testNonAuthFailureContainingAuthorIsNotMisreportedAsUnauthenticated() {
        let mapped = ASCErrorMapping.map(
            result: result(1, err: "Error: app metadata mentions its author"),
            command: ["metadata", "plan"],
            fallbackCode: "store_plan_failed")
        XCTAssertEqual(mapped.code, "store_plan_failed")
    }

    // MARK: - Rate limiting

    func testRateLimitMapsToStoreRateLimited() {
        let mapped = ASCErrorMapping.map(result: result(1, err: "429 Too Many Requests"),
                                         command: ["metadata", "apply"],
                                         fallbackCode: "store_apply_failed")
        XCTAssertEqual(mapped.code, "store_rate_limited")
    }

    // MARK: - Fallback

    func testUnrecognisedFailureKeepsTheCallerFallbackCode() {
        let mapped = ASCErrorMapping.map(result: result(1, err: "kaboom"),
                                         command: ["metadata", "apply"],
                                         fallbackCode: "store_apply_failed")
        XCTAssertEqual(mapped.code, "store_apply_failed")
        XCTAssertEqual(mapped.details?["stderr"], "kaboom")
    }

    func testEveryMappedErrorCarriesTheAscCommand() {
        let mapped = ASCErrorMapping.map(result: result(1, err: "x"),
                                         command: ["metadata", "plan", "--app", "1"],
                                         fallbackCode: "store_plan_failed")
        XCTAssertEqual(mapped.details?["ascCommand"], "asc metadata plan --app 1")
    }
}
