import XCTest
import TestSupport
@testable import LutinSigning

final class NestedCodeDiscoveryTests: XCTestCase {
    /// Builds a throwaway .app with nested code and returns its URL.
    private func makeBundle() throws -> URL {
        let fm = FileManager.default
        let root = try Fixtures.makeTempDirectory()
        let app = root.appendingPathComponent("Demo.app")
        let frameworks = app.appendingPathComponent("Contents/Frameworks")
        let macos = app.appendingPathComponent("Contents/MacOS")
        try fm.createDirectory(at: frameworks.appendingPathComponent("Lib.framework"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: macos, withIntermediateDirectories: true)
        try Data().write(to: macos.appendingPathComponent("Demo"))
        try Data().write(to: frameworks.appendingPathComponent("extra.dylib"))
        return app
    }

    func testDiscoversNestedItemsDeepestFirst() throws {
        let app = try makeBundle()
        let items = CodeSigner.nestedCodePaths(in: app)
        XCTAssertTrue(items.contains { $0.lastPathComponent == "Lib.framework" })
        XCTAssertTrue(items.contains { $0.lastPathComponent == "extra.dylib" })
        XCTAssertFalse(items.contains { $0.lastPathComponent == "Demo.app" })
    }

    func testDeeperPathsComeFirst() throws {
        let app = try makeBundle()
        let items = CodeSigner.nestedCodePaths(in: app)
        let depths = items.map { $0.pathComponents.count }
        XCTAssertEqual(depths, depths.sorted(by: >))
    }
}
