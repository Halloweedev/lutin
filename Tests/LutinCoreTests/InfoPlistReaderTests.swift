import XCTest
import TestSupport
@testable import LutinCore

final class InfoPlistReaderTests: XCTestCase {
    func testReadsBundleFields() throws {
        let info = try InfoPlistReader.read(appBundle: Fixtures.barryApp)
        XCTAssertEqual(info.bundleName, "Barry")
        XCTAssertEqual(info.bundleIdentifier, "com.anotheragence.barry")
        XCTAssertEqual(info.shortVersion, "1.0.0")
        XCTAssertEqual(info.bundleVersion, "42")
    }

    func testMissingBundleThrows() {
        let missing = Fixtures.examplesDirectory.appendingPathComponent("Nope.app")
        XCTAssertThrowsError(try InfoPlistReader.read(appBundle: missing)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "info_plist_unreadable")
        }
    }
}
