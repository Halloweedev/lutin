import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

final class StoreCatalogEngineTests: XCTestCase {

    private let fakeAsc = "/fake/asc"

    private func project(appID: String?, bundleID: String? = nil) throws -> FixtureProject.Handle {
        try FixtureProject.make(metadata: [:], appID: appID, bundleID: bundleID)
    }

    /// Resolves `which asc` for every test that reaches the locator.
    private func stubAsc(_ fake: FakeCommandRunner) {
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
    }

    private func isExecutable(_ path: String) -> Bool { path == fakeAsc }

    /// `stub(executable:arguments:)` resolves before the fragment stub, and the
    /// fragment stub before the catch-all: one refresh runs several asc
    /// commands through one executable.
    func testExactArgumentStubsWinOverFragmentStubsAndTheCatchAll() throws {
        let fake = FakeCommandRunner()
        fake.stub(executable: fakeAsc,
                  result: ShellResult(exitCode: 0, stdout: "catch-all", stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 0, stdout: "versions-list", stderr: ""))
        fake.stub(executable: fakeAsc, arguments: ["apps", "view", "--id", "42"],
                  result: ShellResult(exitCode: 0, stdout: "apps-view", stderr: ""))

        XCTAssertEqual(try fake.run(fakeAsc, ["apps", "view", "--id", "42"]).stdout, "apps-view")
        XCTAssertEqual(try fake.run(fakeAsc, ["versions", "list", "--app", "42"]).stdout,
                       "versions-list")
        XCTAssertEqual(try fake.run(fakeAsc, ["capabilities"]).stdout, "catch-all")
    }

    func testVersionsPassTheAppPlatformAndPaginate() throws {
        let dir = try project(appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("versions-list.json"),
                                      stderr: ""))

        _ = try StoreLogic.versions(configURL: dir.configURL, runner: fake,
                                    isExecutable: isExecutable)

        let invocation = try XCTUnwrap(
            fake.invocations.first { $0.executable == fakeAsc && $0.arguments.contains("versions") })
        XCTAssertEqual(invocation.arguments,
                       ["versions", "list", "--app", "42", "--platform", "MAC_OS",
                        "--paginate", "--output", "json"])
    }

    func testVersionsAreReturnedNewestFirst() throws {
        let dir = try project(appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("versions-list.json"),
                                      stderr: ""))

        let versions = try StoreLogic.versions(configURL: dir.configURL, runner: fake,
                                               isExecutable: isExecutable)
        XCTAssertEqual(versions.map(\.versionString), ["2.0", "1.5", "1.0"])
        XCTAssertEqual(versions[1].state, "IN_REVIEW",
                       "the empty appStoreState falls back to appVersionState")
    }

    func testAppVerificationAcceptsAMatchingBundleID() throws {
        let dir = try project(appID: "42", bundleID: "com.example.myapp")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "apps",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("apps-view.json"),
                                      stderr: ""))

        let app = try StoreLogic.app(configURL: dir.configURL, runner: fake,
                                     isExecutable: isExecutable)
        XCTAssertEqual(app?.bundleID, "com.example.myapp")
    }

    /// Spec §4.2: a mismatch is an error. It is never used to resolve.
    func testAppVerificationRejectsAMismatchedBundleID() throws {
        let dir = try project(appID: "42", bundleID: "com.other.app")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "apps",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("apps-view.json"),
                                      stderr: ""))

        XCTAssertThrowsError(
            try StoreLogic.app(configURL: dir.configURL, runner: fake,
                               isExecutable: isExecutable)
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_bundle_id_mismatch")
            XCTAssertEqual(error?.details?["expected"], "com.other.app")
            XCTAssertEqual(error?.details?["actual"], "com.example.myapp")
            XCTAssertEqual(error?.details?["appID"], "42")
        }
    }

    /// The resolved record carries no `bundleId`, so there is nothing to
    /// compare against: the engine must not throw, and it must not pretend the
    /// configured value was verified. The app is returned as-is and the UI
    /// derives the "could not verify" note from the same absent pair.
    func testAppVerificationPassesWhenTheRecordHasNoBundleID() throws {
        let dir = try project(appID: "42", bundleID: "com.example.myapp")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "apps",
                  result: ShellResult(exitCode: 0,
                                      stdout: #"{"type":"apps","id":"42","attributes":{"name":"MyApp"}}"#,
                                      stderr: ""))

        let app = try StoreLogic.app(configURL: dir.configURL, runner: fake,
                                     isExecutable: isExecutable)
        XCTAssertEqual(app?.id, "42")
        XCTAssertNil(app?.bundleID)
    }

    /// A blank `store.bundleID` is absent, not an expectation — it must not
    /// throw against a perfectly good resolved app.
    func testABlankConfiguredBundleIDDoesNotThrow() throws {
        for blank in ["", "   ", "\n"] {
            let dir = try project(appID: "42", bundleID: blank)
            defer { try? FileManager.default.removeItem(at: dir.root) }
            let fake = FakeCommandRunner()
            stubAsc(fake)
            fake.stub(executable: fakeAsc, argumentsContaining: "apps",
                      result: ShellResult(exitCode: 0,
                                          stdout: try Fixtures.text("apps-view.json"),
                                          stderr: ""))

            let app = try StoreLogic.app(configURL: dir.configURL, runner: fake,
                                         isExecutable: isExecutable)
            XCTAssertEqual(app?.bundleID, "com.example.myapp",
                           "\(blank.debugDescription) is not an expectation to enforce")
        }
    }

    /// With no store.appID there is nothing to verify against — asc resolves
    /// the app, and Lutin says so rather than inventing one.
    func testAppIsNilWhenNoAppIDIsConfigured() throws {
        let dir = try project(appID: nil)
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)

        let app = try StoreLogic.app(configURL: dir.configURL, runner: fake,
                                     isExecutable: isExecutable)
        XCTAssertNil(app)
        XCTAssertFalse(fake.invocations.contains { $0.arguments.contains("apps") },
                       "no store.appID means asc apps view is never invoked")
    }

    func testVersionsMapAnUnresolvableAppToStoreAppNotFound() throws {
        let dir = try project(appID: nil)
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 2, stdout: "",
                                      stderr: "Error: --app is required (or set ASC_APP_ID)\n"))

        XCTAssertThrowsError(
            try StoreLogic.versions(configURL: dir.configURL, runner: fake,
                                    isExecutable: isExecutable)
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_app_not_found")
        }
    }

    // MARK: - The §4.3 capability cache

    /// Two engine calls through one cache probe asc's capabilities once.
    /// Without the cache the GUI re-probed `--version` and `capabilities` on
    /// every command it ran.
    func testTheCapabilityProbeIsCachedAcrossCalls() throws {
        let dir = try project(appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let cacheURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-asc-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let cache = ASCCapabilitiesCache(url: cacheURL, ttl: 3600)
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0, stdout: try Fixtures.text("version.txt"),
                                      stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "capabilities",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("capabilities.json"), stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "auth",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("auth-status.json"), stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "web",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("web-auth-status.json"), stderr: ""))

        _ = try StoreLogic.status(configURL: dir.configURL, runner: fake,
                                  isExecutable: isExecutable, cache: cache)
        _ = try StoreLogic.status(configURL: dir.configURL, runner: fake,
                                  isExecutable: isExecutable, cache: cache)

        XCTAssertEqual(probes(fake, "capabilities"), 1, "asc capabilities is probed once")
        XCTAssertEqual(probes(fake, "--version"), 1, "asc --version is probed once")
    }

    /// No cache means today's behaviour: the CLI's one-shot commands probe
    /// every time rather than reading a file they will never reuse.
    func testWithoutACacheEveryCallProbesAsBefore() throws {
        let dir = try project(appID: "42")
        defer { try? FileManager.default.removeItem(at: dir.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)
        fake.stub(executable: fakeAsc, argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0, stdout: try Fixtures.text("version.txt"),
                                      stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "capabilities",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("capabilities.json"), stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "auth",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("auth-status.json"), stderr: ""))
        fake.stub(executable: fakeAsc, argumentsContaining: "web",
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("web-auth-status.json"), stderr: ""))

        _ = try StoreLogic.status(configURL: dir.configURL, runner: fake,
                                  isExecutable: isExecutable)
        _ = try StoreLogic.status(configURL: dir.configURL, runner: fake,
                                  isExecutable: isExecutable)

        XCTAssertEqual(probes(fake, "capabilities"), 2)
        XCTAssertEqual(probes(fake, "--version"), 2)
    }

    private func probes(_ fake: FakeCommandRunner, _ argument: String) -> Int {
        fake.invocations.filter {
            $0.executable == fakeAsc && $0.arguments.contains(argument)
        }.count
    }
}
