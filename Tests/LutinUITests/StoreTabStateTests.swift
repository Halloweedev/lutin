import XCTest
import LutinCore
import LutinDocument
import LutinStoreConnect
import TestSupport
@testable import LutinUI

/// The Store tab's state machine against one injected runner. Every command is
/// stubbed by argument, so the test asserts the exact argv Lutin builds and can
/// never reach a real `asc`.
@MainActor
final class StoreTabStateTests: XCTestCase {

    private static let fakeAsc = "/fake/asc"

    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()          // Tests/LutinUITests
        .deletingLastPathComponent()          // Tests
        .appendingPathComponent("LutinStoreConnectTests/Fixtures")

    private func isExecutable(_ path: String) -> Bool { path == Self.fakeAsc }

    /// A project with the pinned app, a review artifact on disk, and an
    /// approval record — the state a developer sees after `plan` + `approve`.
    private func makeDocument(withApproval: Bool = true) throws -> LutinProjectDocument {
        let dir = try Fixtures.makeTempDirectory()
        let yaml = """
        project:
          name: Sayrise
          bundleId: com.example.sayrise
        app:
          path: ./build/Sayrise.app
        output:
          directory: ./release
          dmgName: Sayrise-${version}.dmg
          volumeName: Sayrise
        store:
          appID: "1234567890"
          metadataDir: store/metadata
        """
        try Data(yaml.utf8).write(to: dir.appendingPathComponent("lutin.yml"))

        let review = dir.appendingPathComponent(".asc/metadata/review")
        try FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
        try Data(contentsOf: Self.fixtures.appendingPathComponent("plan.json"))
            .write(to: review.appendingPathComponent("plan.json"))
        if withApproval {
            try Data(contentsOf: Self.fixtures.appendingPathComponent("approved.json"))
                .write(to: review.appendingPathComponent("approved.json"))
        }
        return try LutinProjectDocument(configURL: dir.appendingPathComponent("lutin.yml"))
    }

    private func reviewDir(_ document: LutinProjectDocument) -> String {
        document.projectDirectory.appendingPathComponent(".asc/metadata/review").path
    }

    /// Every asc command one refresh runs, stubbed by argument. The review
    /// `status` command gets an exact-argument stub because a bare "status"
    /// fragment would also catch `auth status` and `web auth status`.
    private func makeState(_ document: LutinProjectDocument) throws -> (StoreTabState, FakeCommandRunner) {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(Self.fakeAsc)\n", stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0,
                                      stdout: try text("version.txt"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "web",
                  result: ShellResult(exitCode: 0, stdout: try text("web-auth-status.json"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "auth",
                  result: ShellResult(exitCode: 0, stdout: try text("auth-status.json"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "capabilities",
                  result: ShellResult(exitCode: 0, stdout: try text("capabilities.json"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "apps",
                  result: ShellResult(exitCode: 0, stdout: try text("apps-view.json"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "versions",
                  result: ShellResult(exitCode: 0, stdout: try text("versions-list.json"), stderr: ""))
        fake.stub(executable: Self.fakeAsc, argumentsContaining: "validate",
                  result: ShellResult(exitCode: 0,
                                      stdout: #"{"filesScanned":0,"issues":[],"errorCount":0,"warningCount":0,"valid":true}"#,
                                      stderr: ""))
        fake.stub(executable: Self.fakeAsc,
                  arguments: ["metadata", "status", "--review-dir", reviewDir(document),
                              "--output", "json"],
                  result: ShellResult(exitCode: 0, stdout: try text("review-status.json"), stderr: ""))
        return (StoreTabState(runner: fake, isExecutable: isExecutable), fake)
    }

    private func text(_ name: String) throws -> String {
        try String(contentsOf: Self.fixtures.appendingPathComponent(name), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func statusInvocations(_ fake: FakeCommandRunner) -> [FakeCommandRunner.Invocation] {
        fake.invocations.filter { $0.arguments.starts(with: ["metadata", "status"]) }
    }

    // MARK: - Loading

    func testRefreshLoadsEverySectionFromOneRunner() async throws {
        let document = try makeDocument()
        let (state, fake) = try makeState(document)

        await state.refresh(document: document)

        XCTAssertNotNil(state.connection)
        guard case .loaded(let app) = state.app else { return XCTFail("app: \(state.app)") }
        XCTAssertEqual(app.rows.first { $0.label == "App ID" }?.value, "1234567890")
        guard case .loaded = state.versions else { return XCTFail("versions: \(state.versions)") }
        guard case .loaded = state.validation else { return XCTFail("validation: \(state.validation)") }
        guard case .loaded(let review) = state.review else { return XCTFail("review: \(state.review)") }
        XCTAssertTrue(state.hasReviewPlan)
        XCTAssertEqual(review.planHash,
                       "9f2c1b0e5d4a3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f1e0d9c8b")
        XCTAssertEqual(review.groups.count, 2)

        XCTAssertFalse(fake.invocations.isEmpty)
        XCTAssertTrue(fake.invocations.allSatisfy {
            $0.executable == Self.fakeAsc || $0.executable == "/usr/bin/which"
        }, "one injected runner serves every section")
    }

    // MARK: - Approve

    func testApproveSendsTheReviewerNoteAndTheKey() async throws {
        let document = try makeDocument(withApproval: false)
        let (state, fake) = try makeState(document)
        await state.refresh(document: document)
        state.reviewerNote = "Checked the French subtitle."

        await state.approve(document: document, all: false,
                            keys: ["app-info:fr-FR:subtitle"], scope: nil)

        let approve = try XCTUnwrap(fake.invocations.first {
            $0.executable == Self.fakeAsc && $0.arguments.contains("approve")
        })
        XCTAssertEqual(approve.arguments,
                       ["metadata", "approve",
                        "--review-dir", reviewDir(document),
                        "--key", "app-info:fr-FR:subtitle",
                        "--note", "Checked the French subtitle."])
        // The reload after a successful approve reads asc's status again.
        XCTAssertEqual(statusInvocations(fake).count, 2)
    }

    func testAFailedApproveSurfacesItsFixAndLeavesTheStatusAlone() async throws {
        let document = try makeDocument(withApproval: false)
        let (state, fake) = try makeState(document)
        await state.refresh(document: document)
        guard case .loaded(let before) = state.review else { return XCTFail("review: \(state.review)") }
        let statusCallsBefore = statusInvocations(fake).count

        fake.stub(executable: Self.fakeAsc, argumentsContaining: "approve",
                  result: ShellResult(exitCode: 2, stdout: "",
                                      stderr: "Error: json: unknown field \"bogus\"\n"))
        await state.approve(document: document, all: true, keys: [], scope: nil)

        XCTAssertEqual(state.approveFailure?.code, "store_metadata_schema")
        XCTAssertNotNil(state.approveFailure?.fix, "the failure carries its fix")
        XCTAssertNil(state.applyFailure,
                     "an approve failure is not an apply failure — Apply keeps its own")
        guard case .loaded(let after) = state.review else { return XCTFail("review: \(state.review)") }
        XCTAssertEqual(after.planHash, before.planHash, "the status is left alone")
        XCTAssertEqual(statusInvocations(fake).count, statusCallsBefore,
                       "a failed approve does not reload the status")
    }

    // MARK: - Apply

    func testApplyIsNotRunWithoutConfirmation() async throws {
        let document = try makeDocument()
        let (state, fake) = try makeState(document)
        await state.refresh(document: document)

        state.beginApply()

        XCTAssertTrue(state.isConfirmingApply)
        XCTAssertFalse(fake.invocations.contains { $0.arguments.contains("apply") },
                       "beginApply arms the gate; it does not write")
        state.cancelApply()
        XCTAssertFalse(state.isConfirmingApply)
    }

    /// The gate is the only thing between a click and a live listing write, so
    /// the state enforces it — not the view's choice of which buttons to draw.
    func testConfirmApplyRefusesWhenTheGateWasNeverArmed() async throws {
        let document = try makeDocument()
        let (state, fake) = try makeState(document)
        await state.refresh(document: document)

        await state.confirmApply(document: document)

        XCTAssertFalse(fake.invocations.contains { $0.arguments.contains("apply") },
                       "an unarmed confirmApply writes nothing")
        XCTAssertNil(state.applyResult)
    }

    /// asc answering "not authenticated" is not the same as asc being absent.
    /// The code and its fix survive to the Apply section instead of being
    /// discarded into a hard-coded "install asc".
    func testAFailedStatusKeepsItsCodeInsteadOfLookingLikeAMissingAsc() async throws {
        let document = try makeDocument()
        let (state, fake) = try makeState(document)
        fake.stub(executable: Self.fakeAsc,
                  arguments: ["metadata", "status", "--review-dir", reviewDir(document),
                              "--output", "json"],
                  result: ShellResult(exitCode: 1, stdout: "",
                                      stderr: "Error: not authenticated\n"))

        await state.refresh(document: document)

        XCTAssertEqual(state.statusFailure?.code, "store_unauthenticated")
        XCTAssertNotNil(state.statusFailure?.fix, "the failure carries its fix")
        guard case .loaded(let model) = state.review else { return XCTFail("review: \(state.review)") }
        XCTAssertFalse(model.hasStatus, "the changes still render; the approval does not")
        XCTAssertFalse(model.isReady, "Lutin never guesses an approval")
    }

    func testApplyRunsOnceConfirmedAndReloadsTheStatus() async throws {
        let document = try makeDocument()
        let (state, fake) = try makeState(document)
        await state.refresh(document: document)
        state.beginApply()

        await state.confirmApply(document: document)

        let apply = try XCTUnwrap(fake.invocations.first {
            $0.executable == Self.fakeAsc && $0.arguments.contains("apply")
        })
        XCTAssertTrue(apply.arguments.starts(with: ["metadata", "apply"]))
        XCTAssertTrue(apply.arguments.contains("--confirm"))
        XCTAssertFalse(state.isConfirmingApply)
        XCTAssertNil(state.applyFailure)
        XCTAssertNotNil(state.applyResult)
        XCTAssertEqual(statusInvocations(fake).count, 2,
                       "a confirmed apply reloads asc's status")
    }
}
