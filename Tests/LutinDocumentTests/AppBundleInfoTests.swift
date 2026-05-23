import XCTest
@testable import LutinDocument

final class AppBundleInfoTests: XCTestCase {
    /// Builds a fake .app with an Info.plist at a temp location.
    private func makeApp(plist: [String: Any]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bundle-\(UUID().uuidString)", isDirectory: true)
        let appDir = tmp.appendingPathComponent("Fake.app", isDirectory: true)
        let contents = appDir.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents,
                                                withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml,
                                                      options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appDir
    }

    func testReadsRealisticInfoPlist() throws {
        let app = try makeApp(plist: [
            "CFBundleIdentifier": "com.acme.thunder",
            "CFBundleDisplayName": "Thunder",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42",
        ])
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        let meta = try AppBundleInfo.read(app)
        XCTAssertEqual(meta.bundleIdentifier, "com.acme.thunder")
        XCTAssertEqual(meta.displayName, "Thunder")
        XCTAssertEqual(meta.shortVersion, "1.2.3")
        XCTAssertEqual(meta.build, "42")
    }

    func testFallsBackToBundleNameThenFilename() throws {
        let appA = try makeApp(plist: [
            "CFBundleIdentifier": "com.x.y",
            "CFBundleName": "Plain",
        ])
        defer { try? FileManager.default.removeItem(at: appA.deletingLastPathComponent()) }
        let metaA = try AppBundleInfo.read(appA)
        XCTAssertEqual(metaA.displayName, "Plain")
        XCTAssertNil(metaA.shortVersion)
        XCTAssertNil(metaA.build)

        let appB = try makeApp(plist: ["CFBundleIdentifier": "com.x.y"])
        defer { try? FileManager.default.removeItem(at: appB.deletingLastPathComponent()) }
        let metaB = try AppBundleInfo.read(appB)
        XCTAssertEqual(metaB.displayName, "Fake",
                       "with no display/name fields, falls back to filename")
    }

    func testRejectsNonBundle() {
        let url = URL(fileURLWithPath: "/tmp/not-an-app.txt")
        XCTAssertThrowsError(try AppBundleInfo.read(url)) { err in
            if case AppBundleInfo.ReadError.notABundle = err {} else { XCTFail("wrong error") }
        }
    }

    func testRejectsBundleWithoutIdentifier() throws {
        let app = try makeApp(plist: ["CFBundleName": "NoID"])
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        XCTAssertThrowsError(try AppBundleInfo.read(app)) { err in
            if case AppBundleInfo.ReadError.missingBundleIdentifier = err {} else {
                XCTFail("wrong error: \(err)")
            }
        }
    }

    func testRejectsMissingInfoPlist() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString)", isDirectory: true)
        let appDir = tmp.appendingPathComponent("Empty.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir.appendingPathComponent("Contents"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertThrowsError(try AppBundleInfo.read(appDir)) { err in
            if case AppBundleInfo.ReadError.missingInfoPlist = err {} else {
                XCTFail("wrong error: \(err)")
            }
        }
    }
}
