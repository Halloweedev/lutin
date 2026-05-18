import XCTest
import TestSupport
import LutinCore
@testable import LutinCLI

final class PipelineCommandsTests: XCTestCase {
    func testValidateReportsCleanFixture() throws {
        let issues = try CommandLogic.validateConfig(configURL: Fixtures.barryConfig)
        XCTAssertFalse(issues.contains { $0.severity == .error })
    }

    func testDoctorReportsChecks() throws {
        let report = try CommandLogic.doctor(configURL: Fixtures.barryConfig)
        // Doctor returns one check per inspected concern; all names are present.
        let names = Set(report.map(\.name))
        XCTAssertTrue(names.contains("config"))
        XCTAssertTrue(names.contains("appBundle"))
        XCTAssertTrue(names.contains("outputDirectory"))
        XCTAssertTrue(names.contains("tools"))
    }

    func testBuildDryRunListsSteps() throws {
        let result = try CommandLogic.build(configURL: Fixtures.barryConfig, dryRun: true)
        XCTAssertTrue(result.dryRun)
        XCTAssertFalse(result.plannedSteps.isEmpty)
    }

    func testReleaseStubReturnsNotImplemented() {
        XCTAssertThrowsError(try CommandLogic.notImplemented(verb: "release")) { error in
            XCTAssertEqual((error as? LutinError)?.code, "not_implemented")
        }
    }
}
