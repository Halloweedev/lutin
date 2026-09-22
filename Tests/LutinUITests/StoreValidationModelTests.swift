import XCTest
import LutinStoreConnect
import LutinStoreMetadata
@testable import LutinUI

final class StoreValidationModelTests: XCTestCase {

    private func report(_ issues: [StoreMetadataIssue], offline: Bool = false,
                        fileCount: Int = 2) -> StoreLogic.StoreValidateReport {
        StoreLogic.StoreValidateReport(fileCount: fileCount, issues: issues, offline: offline,
                                       errorCount: issues.filter(\.isError).count,
                                       warningCount: issues.filter { !$0.isError }.count,
                                       valid: !issues.contains(where: \.isError))
    }

    func testFindingsGroupByScopeThenLocaleErrorsFirst() {
        let model = StoreValidationModel.make(report: report([
            StoreMetadataIssue(scope: "version", locale: "fr-FR", field: "description",
                               severity: "warning", message: "short"),
            StoreMetadataIssue(scope: "app-info", locale: "en-US", field: "name",
                               severity: "error", message: "too long", length: 41, limit: 30),
            StoreMetadataIssue(scope: "app-info", locale: "fr-FR", field: "subtitle",
                               severity: "error", message: "too long", length: 31, limit: 30),
            StoreMetadataIssue(scope: "version", locale: "en-US", field: "keywords",
                               severity: "error", message: "too long", length: 120, limit: 100),
        ]))

        XCTAssertEqual(model.groups.map(\.title), ["App info", "Version"])
        let appInfo = model.groups[0]
        XCTAssertEqual(appInfo.localeGroups.map(\.locale), ["en-US", "fr-FR"])
        XCTAssertEqual(appInfo.errorCount, 2)
        XCTAssertEqual(model.groups[1].warningCount, 1)
        XCTAssertTrue(model.groups[0].localeGroups[0].findings[0].isOverLimit)
    }

    func testUnscopedFindingsLandInTheTreeGroup() {
        let model = StoreValidationModel.make(report: report([
            .strayPath("/tmp/x/store/metadata/versions"),
        ]))
        XCTAssertEqual(model.groups.map(\.title), ["Metadata tree"])
        XCTAssertEqual(model.groups[0].localeGroups[0].findings.count, 1)
    }

    func testOfflineReportSaysSoAndCarriesTheFix() {
        let model = StoreValidationModel.make(report: report([], offline: true))
        XCTAssertTrue(model.offline)
        XCTAssertTrue(model.headline.contains("Offline"))
        XCTAssertEqual(model.fix, FixSuggestions.suggestion(for: "store_asc_missing"))
    }

    func testCleanReportHeadlineNamesTheFileCount() {
        let model = StoreValidationModel.make(report: report([], fileCount: 6))
        XCTAssertTrue(model.headline.contains("6"))
        XCTAssertNil(model.fix)
    }
}
