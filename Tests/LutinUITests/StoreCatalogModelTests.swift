import XCTest
import LutinStoreConnect
@testable import LutinUI

final class StoreCatalogModelTests: XCTestCase {

    private func version(_ string: String, state: String? = "READY_FOR_REVIEW",
                         created: String? = "2026-01-01T00:00:00Z") -> ASCAppStoreVersion {
        ASCAppStoreVersion(id: "v\(string)", versionString: string, platform: "MAC_OS",
                           appStoreState: state, appVersionState: nil,
                           createdDate: created, releaseType: nil, isDownloadable: nil)
    }

    func testVersionRowsKeepNewestFirstAndCarryTheirState() {
        let model = StoreVersionsModel.make(
            versions: [version("1.0", created: "2025-01-01T00:00:00Z"),
                       version("2.0", state: "READY_FOR_SALE", created: "2026-01-01T00:00:00Z")],
            platform: "MAC_OS")
        XCTAssertEqual(model.versions.map(\.versionString), ["2.0", "1.0"])
        XCTAssertTrue(model.versions[0].isLive)
        XCTAssertEqual(model.versions[0].createdLabel, "2026-01-01")
    }

    func testTheAppModelNamesTheConfiguredAppAndItsResolvedRecord() {
        let model = StoreAppModel.make(
            app: ASCApp(id: "42", name: "MyApp", bundleID: "com.example.myapp", sku: "MYAPP"),
            appID: "42", bundleID: "com.example.myapp", platform: "MAC_OS")
        XCTAssertEqual(model.rows.first { $0.label == "Bundle ID" }?.value, "com.example.myapp")
        XCTAssertEqual(model.rows.first { $0.label == "Platform" }?.value, "MAC_OS")
        XCTAssertTrue(model.note?.contains("verified") ?? false)
    }

    func testWithNoAppIDTheModelSaysAscResolvesIt() {
        let model = StoreAppModel.make(app: nil, appID: nil, bundleID: nil, platform: "MAC_OS")
        XCTAssertTrue(model.note?.contains("asc resolves") ?? false)
        XCTAssertEqual(model.rows.first { $0.label == "App ID" }?.value, "resolved by asc")
    }

    func testWithNoBundleIDTheModelSaysNothingIsVerified() {
        let model = StoreAppModel.make(
            app: ASCApp(id: "42", name: "MyApp", bundleID: "com.example.myapp", sku: "MYAPP"),
            appID: "42", bundleID: nil, platform: "MAC_OS")
        XCTAssertTrue(model.note?.contains("Set store.bundleID") ?? false)
    }
}
