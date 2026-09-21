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

    // MARK: - capability gating

    // The recorded fixture cannot exercise `web-session` or `not-public-api`
    // for our commands — its one `not-public-api` entry names no commands and
    // none of its `web-session` entries cover `metadata *` — so these three
    // tests drive the gate with inline synthetic payloads, not re-recorded
    // fixtures. FakeCommandRunner keys stubs by executable, so the
    // web-session payload doubles as the `web auth status` response: the
    // `capabilities` key makes the probe parse, and `authenticated: false`
    // makes `assertAvailable` throw `store_web_session_missing`.

    func testPlanGatesWebSessionCapability() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: """
                  {"capabilities":[{"area":"metadata","capability":"plan",
                    "status":"web-session","commands":["asc metadata plan"],
                    "notes":null,"nextAction":null}],"authenticated":false}
                  """, stderr: ""))

        XCTAssertThrowsError(try StoreLogic.plan(configURL: dir.configURL, reviewDir: nil,
                                                 runner: fake,
                                                 isExecutable: { $0 == self.fakeAsc })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_web_session_missing")
        }
    }

    func testPlanRejectsNotPublicAPICapabilityWithAscNextAction() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: """
                  {"capabilities":[{"area":"metadata","capability":"plan",
                    "status":"not-public-api","commands":["asc metadata plan"],
                    "notes":null,"nextAction":"Use the App Store Connect website instead."}]}
                  """, stderr: ""))

        XCTAssertThrowsError(try StoreLogic.plan(configURL: dir.configURL, reviewDir: nil,
                                                 runner: fake,
                                                 isExecutable: { $0 == self.fakeAsc })
        ) { error in
            let lutinError = error as? LutinError
            XCTAssertEqual(lutinError?.code, "store_unsupported")
            XCTAssertTrue(lutinError?.message
                            .contains("Use the App Store Connect website instead.") ?? false)
        }
    }

    /// A successful capabilities probe that simply does not enumerate the
    /// command is absence of evidence and must not block it.
    func testPlanProceedsWhenCapabilitiesDoNotEnumerateTheCommand() throws {
        let dir = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: """
                  {"capabilities":[{"area":"builds","capability":"upload",
                    "status":"cli-supported","commands":["asc builds upload"],
                    "notes":null,"nextAction":null}]}
                  """, stderr: ""))

        _ = try StoreLogic.plan(configURL: dir.configURL, reviewDir: nil, runner: fake,
                                isExecutable: { $0 == self.fakeAsc })
        let invocation = try XCTUnwrap(fake.invocations.first {
            $0.executable == fakeAsc && $0.arguments.first == "metadata"
        })
        XCTAssertTrue(invocation.arguments.starts(with: ["metadata", "plan"]))
    }

    // MARK: - empty tree

    /// Spec §3.4: an empty metadata directory is an error, not a clean bill
    /// of health — validating before the first `pull` must not be green.
    func testOfflineValidateReportsEmptyTree() throws {
        let dir = try FixtureProject.make(metadata: [:])
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()

        let report = try StoreLogic.validateOffline(configURL: dir.configURL, runner: fake)
        XCTAssertEqual(report.fileCount, 0)
        XCTAssertEqual(report.issues.count, 1)
        XCTAssertEqual(report.issues.first?.severity, "error")
        XCTAssertFalse(report.valid)
    }
}
