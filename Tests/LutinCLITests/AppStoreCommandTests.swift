import XCTest
import TestSupport
import LutinCore
@testable import LutinCLI

final class AppStoreCommandTests: XCTestCase {
    /// A real executable path — never executed (the fake runner intercepts),
    /// but satisfies the executability check hermetically on any machine.
    private let fakeAsc = "/bin/echo"

    private func makeArtifact(in dir: URL, named: String = "App.pkg") throws -> String {
        let url = dir.appendingPathComponent(named)
        try Data("pkg".utf8).write(to: url)
        return url.path
    }

    // MARK: - Path resolution

    func testResolveAscPathUsesExplicitPath() throws {
        let fake = FakeCommandRunner()
        let path = try AppStoreLogic.resolveAscPath(
            explicit: fakeAsc, runner: fake,
            isExecutable: { $0 == self.fakeAsc })
        XCTAssertEqual(path, fakeAsc)
        XCTAssertTrue(fake.invocations.isEmpty, "Explicit path must not spawn a process")
    }

    func testResolveAscPathRejectsNonExecutableExplicitPath() {
        let fake = FakeCommandRunner()
        XCTAssertThrowsError(try AppStoreLogic.resolveAscPath(
            explicit: "/nonexistent/asc", runner: fake,
            isExecutable: { _ in false })) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_store_tool_missing")
        }
    }

    func testResolveAscPathFallsBackToWhich() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "/custom/asc\n", stderr: ""))
        let path = try AppStoreLogic.resolveAscPath(
            explicit: nil, runner: fake,
            isExecutable: { $0 == "/custom/asc" })
        XCTAssertEqual(path, "/custom/asc")
    }

    func testResolveAscPathThrowsWhenNothingFound() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: ""))
        XCTAssertThrowsError(try AppStoreLogic.resolveAscPath(
            explicit: nil, runner: fake,
            isExecutable: { _ in false })) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_store_tool_missing")
        }
    }

    // MARK: - Upload

    func testUploadBuildsAscArguments() {
        let args = AppStoreLogic.uploadArguments(
            artifact: "/tmp/App.pkg", kind: .pkg, app: "123",
            version: "1.2.3", buildNumber: "45", wait: true)
        XCTAssertEqual(args, ["builds", "upload", "--app", "123",
                              "--pkg", "/tmp/App.pkg",
                              "--output", "json",
                              "--version", "1.2.3", "--build-number", "45",
                              "--wait"])
    }

    func testUploadUsesIpaFlagForIpa() throws {
        let dir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let artifact = try makeArtifact(in: dir, named: "App.ipa")

        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "{}", stderr: ""))
        _ = try AppStoreLogic.upload(
            artifact: artifact, kind: .ipa, app: "123",
            version: nil, buildNumber: nil, wait: false,
            ascPath: fakeAsc, dryRun: false, runner: fake)
        let invoked = try XCTUnwrap(fake.invocations.first)
        XCTAssertTrue(invoked.arguments.contains("--ipa"))
        XCTAssertFalse(invoked.arguments.contains("--pkg"))
    }

    func testUploadMissingArtifactThrows() {
        let fake = FakeCommandRunner()
        XCTAssertThrowsError(try AppStoreLogic.upload(
            artifact: "/nonexistent/App.pkg", kind: .pkg, app: "123",
            version: nil, buildNumber: nil, wait: false,
            ascPath: fakeAsc, dryRun: false, runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_store_artifact_missing")
        }
    }

    func testUploadDryRunSpawnsNothing() throws {
        let dir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let artifact = try makeArtifact(in: dir)

        let fake = FakeCommandRunner()
        let result = try AppStoreLogic.upload(
            artifact: artifact, kind: .pkg, app: "123",
            version: nil, buildNumber: nil, wait: false,
            ascPath: fakeAsc, dryRun: true, runner: fake)
        XCTAssertTrue(result.dryRun)
        XCTAssertTrue(result.output.contains("builds upload"))
        XCTAssertTrue(fake.invocations.isEmpty)
    }

    func testUploadFailureMapsToUploadFailed() throws {
        let dir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let artifact = try makeArtifact(in: dir)

        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 1, stdout: "", stderr: "build not found"))
        XCTAssertThrowsError(try AppStoreLogic.upload(
            artifact: artifact, kind: .pkg, app: "123",
            version: nil, buildNumber: nil, wait: false,
            ascPath: fakeAsc, dryRun: false, runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_store_upload_failed")
        }
    }

    func testUploadAuthFailureMapsToAuthFailed() throws {
        let dir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let artifact = try makeArtifact(in: dir)

        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 1, stdout: "",
                                      stderr: "ERROR: not authenticated — run asc auth login"))
        XCTAssertThrowsError(try AppStoreLogic.upload(
            artifact: artifact, kind: .pkg, app: "123",
            version: nil, buildNumber: nil, wait: false,
            ascPath: fakeAsc, dryRun: false, runner: fake)) { error in
            let lutinError = try? XCTUnwrap(error as? LutinError)
            XCTAssertEqual(lutinError?.code, "app_store_auth_failed")
            XCTAssertTrue(lutinError?.message.contains("asc auth login") ?? false)
        }
    }

    // MARK: - Status

    func testStatusIsReadOnlyPassthrough() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "{\"app\":{}}", stderr: ""))
        let result = try AppStoreLogic.status(
            app: "123", platform: "MAC_OS",
            ascPath: fakeAsc, dryRun: false, runner: fake)
        XCTAssertEqual(result.output, "{\"app\":{}}")
        let invoked = try XCTUnwrap(fake.invocations.first)
        XCTAssertEqual(invoked.arguments,
                       ["status", "--app", "123", "--output", "json",
                        "--platform", "MAC_OS"])
    }

    func testStatusAuthFailureMapsToAuthFailed() {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 1, stdout: "",
                                      stderr: "invalid API key"))
        XCTAssertThrowsError(try AppStoreLogic.status(
            app: "123", platform: nil,
            ascPath: fakeAsc, dryRun: false, runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_store_auth_failed")
        }
    }

    // MARK: - Doctor

    func testDoctorDetailReportsMissingTool() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: ""))
        let detail = AppStoreLogic.doctorDetail(runner: fake,
                                                isExecutable: { _ in false })
        XCTAssertTrue(detail.contains("brew install asc"))
    }

    func testDoctorDetailReportsReadyTool() {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/opt/homebrew/bin/asc",
                  result: ShellResult(exitCode: 0, stdout: "5.0.0", stderr: ""))
        let detail = AppStoreLogic.doctorDetail(
            runner: fake,
            isExecutable: { $0 == "/opt/homebrew/bin/asc" })
        XCTAssertTrue(detail.contains("5.0.0"), "Got: \(detail)")
        XCTAssertTrue(detail.contains("lutin app-store"))
    }

    func testDoctorIncludesInformationalAppStoreCheck() throws {
        let fake = FakeCommandRunner()
        let checks = try CommandLogic.doctor(configURL: Fixtures.barryConfig, runner: fake)
        let check = try XCTUnwrap(checks.first { $0.name == "appStore" })
        XCTAssertTrue(check.ok, "The optional asc companion must never fail readiness")
    }
}
