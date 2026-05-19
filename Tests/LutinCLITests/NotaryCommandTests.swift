import XCTest
import LutinCore
@testable import LutinCLI

final class NotaryCommandTests: XCTestCase {
    func testNotarySetupBuildsStoreCredentialsArguments() {
        let args = CommandLogic.notarySetupArguments(
            profile: "lutin-notary", appleID: "me@x.com",
            teamID: "TEAM123", password: "secret")
        XCTAssertEqual(args.first, "notarytool")
        XCTAssertTrue(args.contains("store-credentials"))
        XCTAssertTrue(args.contains("lutin-notary"))
        XCTAssertTrue(args.contains("--apple-id"))
        XCTAssertTrue(args.contains("me@x.com"))
        XCTAssertTrue(args.contains("--team-id"))
        XCTAssertTrue(args.contains("TEAM123"))
        XCTAssertTrue(args.contains("--password"))
        XCTAssertTrue(args.contains("secret"))
    }

    func testNotarySetupArgumentsOmitMissingFlags() {
        let args = CommandLogic.notarySetupArguments(
            profile: "lutin-notary", appleID: nil, teamID: nil, password: nil)
        XCTAssertEqual(args, ["notarytool", "store-credentials", "lutin-notary"])
    }
}
