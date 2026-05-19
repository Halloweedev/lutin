import XCTest
import TestSupport
import LutinCore
@testable import LutinSigning

final class SignAppTests: XCTestCase {
    private func makeBundle() throws -> URL {
        let fm = FileManager.default
        let root = try Fixtures.makeTempDirectory()
        let app = root.appendingPathComponent("Demo.app")
        let fw = app.appendingPathComponent("Contents/Frameworks/Lib.framework")
        try fm.createDirectory(at: fw, withIntermediateDirectories: true)
        try fm.createDirectory(at: app.appendingPathComponent("Contents/MacOS"),
                               withIntermediateDirectories: true)
        return app
    }

    func testSignsNestedItemsBeforeTopLevelApp() throws {
        let app = try makeBundle()
        let fake = FakeCommandRunner()
        try CodeSigner.signApp(app, identity: "Developer ID Application",
                               entitlements: nil, runner: fake)
        let signCalls = fake.invocations.filter { $0.executable.hasSuffix("codesign") }
        XCTAssertGreaterThanOrEqual(signCalls.count, 2)
        XCTAssertTrue(signCalls.last!.arguments.contains(app.path))
        let fwIndex = signCalls.firstIndex { $0.arguments.contains { $0.contains("Lib.framework") } }!
        let appIndex = signCalls.firstIndex { $0.arguments.last == app.path }!
        XCTAssertLessThan(fwIndex, appIndex)
    }

    func testTopLevelAppSignedWithHardenedRuntime() throws {
        let app = try makeBundle()
        let fake = FakeCommandRunner()
        try CodeSigner.signApp(app, identity: "ID", entitlements: nil, runner: fake)
        let appSign = fake.invocations.last { $0.arguments.last == app.path }!
        XCTAssertTrue(appSign.arguments.contains("runtime"))
    }

    func testEntitlementsPassedWhenProvided() throws {
        let app = try makeBundle()
        let fake = FakeCommandRunner()
        try CodeSigner.signApp(app, identity: "ID",
                               entitlements: "/tmp/E.plist", runner: fake)
        let appSign = fake.invocations.last { $0.arguments.last == app.path }!
        XCTAssertTrue(appSign.arguments.contains("--entitlements"))
        XCTAssertTrue(appSign.arguments.contains("/tmp/E.plist"))
    }

    func testIdentityNotFoundSurfacesTypedError() {
        let fake = FakeCommandRunner()
        fake.stubFailure(executable: "/usr/bin/codesign",
                         error: LutinError(code: "command_failed",
                                           message: "no identity found"))
        XCTAssertThrowsError(try CodeSigner.signApp(
            URL(fileURLWithPath: "/tmp/Demo.app"), identity: "Missing",
            entitlements: nil, runner: fake)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "signing_failed")
        }
    }
}
