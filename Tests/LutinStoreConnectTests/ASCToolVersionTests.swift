import XCTest
@testable import LutinStoreConnect
import LutinCore

final class ASCToolVersionTests: XCTestCase {

    /// The exact shape asc 5.3.0 emits.
    func testParsesRealVersionString() {
        let v = ASCToolVersion("5.3.0 (commit: unknown, date: unknown)")
        XCTAssertEqual(v?.description, "5.3.0")
    }

    func testParsesBareVersionString() {
        XCTAssertEqual(ASCToolVersion("5.3.0")?.description, "5.3.0")
        XCTAssertEqual(ASCToolVersion("2.0")?.description, "2.0.0")
    }

    func testRejectsGarbage() {
        XCTAssertNil(ASCToolVersion("not a version"))
        XCTAssertNil(ASCToolVersion(""))
    }

    func testOrderingIsNumericNotLexical() {
        XCTAssertLessThan(ASCToolVersion("5.3.0")!, ASCToolVersion("5.10.0")!)
        XCTAssertLessThan(ASCToolVersion("5.3.0")!, ASCToolVersion("6.0.0")!)
    }

    func testMinimumIsTheProbedVersion() {
        XCTAssertEqual(ASCToolVersion.minimum.description, "5.3.0")
    }

    func testAssertSupportedAcceptsTheRecordedVersion() throws {
        let recorded = try Fixtures.text("version.txt")
        XCTAssertNoThrow(try ASCToolVersion.assertSupported(recorded))
    }

    func testAssertSupportedRejectsOlder() {
        XCTAssertThrowsError(try ASCToolVersion.assertSupported("2.0.0 (commit: unknown)")) { error in
            let e = error as? LutinError
            XCTAssertEqual(e?.code, "store_asc_too_old")
            XCTAssertEqual(e?.details?["required"], "5.3.0")
            XCTAssertEqual(e?.details?["found"], "2.0.0")
        }
    }

    func testAssertSupportedRejectsUnparseable() {
        XCTAssertThrowsError(try ASCToolVersion.assertSupported("who knows")) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_too_old")
        }
    }
}
