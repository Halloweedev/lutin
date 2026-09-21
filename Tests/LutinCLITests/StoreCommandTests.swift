import XCTest
@testable import LutinCLI
import LutinStoreConnect
import LutinCore
import TestSupport

final class StoreCommandTests: XCTestCase {

    private let fakeAsc = "/fake/asc"

    // MARK: - validate is offline

    /// The whole reason `LutinStoreMetadata` is a separate module: CI can
    /// validate a listing on a runner with no asc and no network.
    func testValidateWorksWithNoAscInstalled() throws {
        let dir = try FixtureProject.make(metadata: [
            "app-info/en-US.json": #"{"name":"MyApp"}"#,
            "version/1.2.3/en-US.json": #"{"description":"A description."}"#,
        ])
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()   // no asc stub at all

        let report = try StoreLogic.validateOffline(configURL: dir.configURL, runner: fake)
        XCTAssertEqual(report.fileCount, 2)
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testOfflineValidateReportsUnknownKeys() throws {
        let dir = try FixtureProject.make(metadata: [
            "version/1.2.3/en-US.json": #"{"bogusField":"x"}"#,
        ])
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()

        XCTAssertThrowsError(
            try StoreLogic.validateOffline(configURL: dir.configURL, runner: fake)
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_schema")
        }
    }

    // MARK: - status

    func testStatusReportsMissingAscWithoutTouchingTheFilesystem() throws {
        let dir = try FixtureProject.make(metadata: [:])
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: ""))

        XCTAssertThrowsError(try StoreLogic.status(configURL: dir.configURL, runner: fake,
                                                   isExecutable: { _ in false })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_missing")
        }
    }

    // MARK: - plan / approve / apply argument shapes

    func testPlanPassesTheReviewDirAndPlatform() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "{}", stderr: ""))

        _ = try? StoreLogic.plan(configURL: dir.configURL, reviewDir: nil, runner: fake,
                                 isExecutable: { $0 == self.fakeAsc })

        let invocation = try XCTUnwrap(fake.invocations.first {
            $0.executable == fakeAsc && $0.arguments.first == "metadata"
        })
        XCTAssertTrue(invocation.arguments.starts(with: ["metadata", "plan"]))
        XCTAssertTrue(invocation.arguments.contains("--platform"))
        XCTAssertTrue(invocation.arguments.contains("MAC_OS"))
        XCTAssertTrue(invocation.arguments.contains("--app"))
    }

    func testApplyRequiresConfirmation() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "{}", stderr: ""))

        XCTAssertThrowsError(try StoreLogic.apply(configURL: dir.configURL, reviewDir: nil,
                                                  confirmed: false, runner: fake,
                                                  isExecutable: { $0 == self.fakeAsc })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_confirmation_required")
        }
        XCTAssertFalse(fake.invocations.contains { $0.executable == fakeAsc },
                       "An unconfirmed apply must not invoke asc at all.")
    }

    func testApplyPassesConfirmWhenConfirmed() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "{}", stderr: ""))

        _ = try? StoreLogic.apply(configURL: dir.configURL, reviewDir: nil,
                                  confirmed: true, runner: fake,
                                  isExecutable: { $0 == self.fakeAsc })
        let invocation = try XCTUnwrap(fake.invocations.first {
            $0.executable == fakeAsc && $0.arguments.first == "metadata"
        })
        XCTAssertTrue(invocation.arguments.contains("--confirm"))
    }

    // MARK: - pull

    func testPullRefusesToOverwriteWithoutForce() throws {
        let dir = try FixtureProject.make(metadata: [
            "app-info/en-US.json": #"{"name":"MyApp"}"#,
        ], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()

        XCTAssertThrowsError(try StoreLogic.pull(configURL: dir.configURL, version: nil,
                                                 force: false, runner: fake,
                                                 isExecutable: { $0 == self.fakeAsc })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_pull_would_overwrite")
        }
    }
}
