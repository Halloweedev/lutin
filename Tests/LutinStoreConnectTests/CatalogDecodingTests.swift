import XCTest
@testable import LutinStoreConnect

final class CatalogDecodingTests: XCTestCase {

    func testAppDecodesTheResourceEnvelope() throws {
        let json = try Fixtures.data("apps-view.json")
        let app = try JSONDecoder().decode(ASCApp.self, from: json)
        XCTAssertEqual(app.id, "1234567890")
        XCTAssertEqual(app.bundleID, "com.example.myapp")
        XCTAssertEqual(app.name, "MyApp")
    }

    func testVersionsDecodeTheResponseEnvelope() throws {
        let list = try JSONDecoder().decode(
            ASCAppStoreVersionList.self, from: try Fixtures.data("versions-list.json"))
        XCTAssertEqual(list.data.count, 3)
        XCTAssertEqual(list.data[0].state, "READY_FOR_SALE")
    }

    /// asc's own table falls back to `appVersionState` when `appStoreState` is
    /// empty; a row must never render a blank state.
    func testStateFallsBackToTheVersionState() {
        let v = ASCAppStoreVersion(id: "1", versionString: "2.0", platform: "IOS",
                                   appStoreState: "", appVersionState: "IN_REVIEW",
                                   createdDate: "2026-01-01T00:00:00Z",
                                   releaseType: nil, isDownloadable: nil)
        XCTAssertEqual(v.state, "IN_REVIEW")
    }

    func testNewestFirstOrderingIsByCreatedDateDescending() {
        let versions = [ASCAppStoreVersion(id: "1", versionString: "1.0", platform: "MAC_OS",
                                           appStoreState: "READY_FOR_SALE",
                                           appVersionState: nil,
                                           createdDate: "2025-01-01T00:00:00Z",
                                           releaseType: nil, isDownloadable: nil),
                        ASCAppStoreVersion(id: "2", versionString: "2.0", platform: "MAC_OS",
                                           appStoreState: "PREPARE_FOR_SUBMISSION",
                                           appVersionState: nil,
                                           createdDate: "2026-01-01T00:00:00Z",
                                           releaseType: nil, isDownloadable: nil),
                        ASCAppStoreVersion(id: "3", versionString: "1.5", platform: "MAC_OS",
                                           appStoreState: "READY_FOR_SALE",
                                           appVersionState: nil,
                                           createdDate: "2025-06-01T00:00:00Z",
                                           releaseType: nil, isDownloadable: nil)]
        XCTAssertEqual(ASCAppStoreVersion.newestFirst(versions).map(\.versionString),
                       ["2.0", "1.5", "1.0"])
    }

    func testUnknownAttributesAreIgnoredNotFatal() throws {
        // Apple adds fields; a new one must not break the Versions section.
        let json = #"{"data":[{"type":"appStoreVersions","id":"1","attributes":{"versionString":"1.0","someNewAppleField":true}}]}"#
        XCTAssertEqual(try JSONDecoder().decode(ASCAppStoreVersionList.self,
                                                from: Data(json.utf8)).data.count, 1)
    }
}
