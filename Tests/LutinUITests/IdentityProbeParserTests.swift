import XCTest
@testable import LutinUI

final class IdentityProbeParserTests: XCTestCase {
    func testParsesFindIdentityOutput() {
        let sample = """
          1) AB12CD34EF56 "Developer ID Application: Acme Inc. (TEAM1)"
          2) FF77AA88BB99 "Apple Development: dev@example.com (TEAM2)"
             2 valid identities found
        """
        let parsed = IdentityProbe.parse(securityOutput: sample)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].hash, "AB12CD34EF56")
        XCTAssertEqual(parsed[0].name, "Developer ID Application: Acme Inc. (TEAM1)")
        XCTAssertEqual(parsed[1].hash, "FF77AA88BB99")
    }
    func testParsesEmptyOutput() {
        let sample = "  0 valid identities found"
        XCTAssertTrue(IdentityProbe.parse(securityOutput: sample).isEmpty)
    }
    func testNotaryProfilesParser() {
        let sample = """
        Keychain Profiles:
          ci-notary
          dev-personal
        """
        let parsed = NotaryProbe.parse(notarytoolOutput: sample)
        XCTAssertEqual(parsed, ["ci-notary", "dev-personal"])
    }
}
