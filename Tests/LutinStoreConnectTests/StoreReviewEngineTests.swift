import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

final class StoreReviewEngineTests: XCTestCase {

    private let fakeAsc = "/fake/asc"

    private func isExecutable(_ path: String) -> Bool { path == fakeAsc }

    private func stubAsc(_ fake: FakeCommandRunner) {
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 0, stdout: "\(fakeAsc)\n", stderr: ""))
    }

    /// The default review dir asc uses, resolved against the project directory.
    private func reviewDir(_ handle: FixtureProject.Handle) -> URL {
        handle.root.appendingPathComponent(".asc/metadata/review")
    }

    private func write(_ name: String, in handle: FixtureProject.Handle) throws -> URL {
        let dir = reviewDir(handle)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Fixtures.data(name).write(to: url)
        return url
    }

    // MARK: - reviewPlan

    func testReviewPlanIsNilWhenNoArtifactExists() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        let fake = FakeCommandRunner()

        let plan = try StoreLogic.reviewPlan(configURL: handle.configURL, runner: fake)

        XCTAssertNil(plan, "no plan artifact is an empty state, not an error")
        XCTAssertTrue(fake.invocations.isEmpty,
                      "reading the plan artifact never spawns a subprocess")
    }

    func testReviewPlanReadsTheDefaultReviewDirRelativeToTheProject() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        _ = try write("plan.json", in: handle)
        let fake = FakeCommandRunner()

        let plan = try StoreLogic.reviewPlan(configURL: handle.configURL, runner: fake)

        XCTAssertEqual(plan?.plan.adds.count, 2)
        XCTAssertEqual(plan?.changes.count, 4)
    }

    func testReviewPlanRejectsAMalformedArtifactWithThePath() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        let dir = reviewDir(handle)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("plan.json")
        try Data("{ not json".utf8).write(to: url)
        let fake = FakeCommandRunner()

        XCTAssertThrowsError(
            try StoreLogic.reviewPlan(configURL: handle.configURL, runner: fake)
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["path"], url.path)
        }
    }

    // MARK: - reviewStatus

    func testReviewStatusPassesTheReviewDir() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        _ = try write("plan.json", in: handle)
        let fake = FakeCommandRunner()
        stubAsc(fake)
        let dir = reviewDir(handle).path
        fake.stub(executable: fakeAsc,
                  arguments: ["metadata", "status", "--review-dir", dir, "--output", "json"],
                  result: ShellResult(exitCode: 0,
                                      stdout: try Fixtures.text("review-status.json"),
                                      stderr: ""))

        let status = try StoreLogic.reviewStatus(configURL: handle.configURL, runner: fake,
                                                 isExecutable: isExecutable)

        XCTAssertEqual(status?.ready, false)
        XCTAssertEqual(status?.pendingCount, 3)
        XCTAssertEqual(status?.approvedKeys, ["app-info:en-US:name"])
        let invocation = try XCTUnwrap(fake.invocations.first { $0.executable == fakeAsc })
        XCTAssertEqual(invocation.arguments,
                       ["metadata", "status", "--review-dir", dir, "--output", "json"])
    }

    /// No plan artifact means no subprocess at all — the empty state is
    /// discovered by reading the filesystem, not by asking asc.
    func testReviewStatusIsNilWhenThereIsNoPlanArtifact() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        let fake = FakeCommandRunner()
        stubAsc(fake)

        let status = try StoreLogic.reviewStatus(configURL: handle.configURL, runner: fake,
                                                 isExecutable: isExecutable)

        XCTAssertNil(status)
        XCTAssertTrue(fake.invocations.isEmpty)
    }

    func testReviewStatusSurfacesMissingAscAsStoreAscMissing() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        _ = try write("plan.json", in: handle)
        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/which",
                  result: ShellResult(exitCode: 1, stdout: "", stderr: ""))

        XCTAssertThrowsError(
            try StoreLogic.reviewStatus(configURL: handle.configURL, runner: fake,
                                        isExecutable: { _ in false })
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_missing")
        }
    }

    /// asc exits 2 for a schema error, but its one legitimate exit 2 here is
    /// "metadata plan artifact not found". That must read as "run plan first",
    /// not "fix the named file and field" — so `store_plan_failed`, not
    /// `store_metadata_schema`.
    func testReviewStatusMapsTheMissingArtifactMessageToAnExplanation() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        _ = try write("plan.json", in: handle)
        let fake = FakeCommandRunner()
        stubAsc(fake)
        let exitCode = Int32(try Fixtures.text("review-status-missing.exitcode")) ?? 2
        fake.stub(executable: fakeAsc, argumentsContaining: "metadata",
                  result: ShellResult(exitCode: exitCode,
                                      stdout: try Fixtures.text("review-status-missing.stdout"),
                                      stderr: try Fixtures.text("review-status-missing.stderr")))

        XCTAssertThrowsError(
            try StoreLogic.reviewStatus(configURL: handle.configURL, runner: fake,
                                        isExecutable: isExecutable)
        ) { error in
            let error = error as? LutinError
            XCTAssertEqual(error?.code, "store_plan_failed")
            XCTAssertNotEqual(error?.code, "store_metadata_schema")
            XCTAssertEqual(error?.details?["reviewDir"], reviewDir(handle).path)
        }
    }

    // MARK: - reviewApproval

    func testReviewApprovalReadsTheApprovalRecord() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        _ = try write("approved.json", in: handle)
        let fake = FakeCommandRunner()

        let approval = try StoreLogic.reviewApproval(configURL: handle.configURL, runner: fake)

        XCTAssertEqual(approval?.mode, "key")
        XCTAssertEqual(approval?.note, "Checked the French subtitle against the app.")
        XCTAssertTrue(fake.invocations.isEmpty)
    }

    func testReviewApprovalIsNilWhenNothingIsApproved() throws {
        let handle = try FixtureProject.make(metadata: [:], appID: "42")
        defer { try? FileManager.default.removeItem(at: handle.root) }
        let fake = FakeCommandRunner()

        XCTAssertNil(try StoreLogic.reviewApproval(configURL: handle.configURL, runner: fake))
    }
}
