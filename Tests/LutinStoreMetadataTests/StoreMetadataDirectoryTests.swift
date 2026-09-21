import XCTest
@testable import LutinStoreMetadata
import LutinCore

final class StoreMetadataDirectoryTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ relativePath: String, _ contents: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeDirectory() -> StoreMetadataDirectory { StoreMetadataDirectory(root: root) }

    // MARK: - Enumeration

    func testEnumeratesLocalesAcrossBothScopes() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("app-info/fr-FR.json", #"{"name":"MonApp"}"#)
        try write("version/1.2.3/en-US.json", #"{"description":"D"}"#)
        let dir = makeDirectory()
        XCTAssertEqual(try dir.appInfoLocales().sorted(), ["en-US", "fr-FR"])
        XCTAssertEqual(try dir.versionLocales(version: "1.2.3"), ["en-US"])
        XCTAssertEqual(dir.allLocales.sorted(), ["en-US", "fr-FR"])
    }

    /// `default.json` is the shared fallback, not a locale.
    func testDefaultIsNotALocaleButIsCounted() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("app-info/default.json", #"{"subtitle":"Shared"}"#)
        let dir = makeDirectory()
        XCTAssertEqual(try dir.appInfoLocales(), ["en-US"])
        XCTAssertTrue(dir.hasDefaultFallback)
        XCTAssertEqual(try dir.enumeratedFileCount(), 2)
    }

    /// Review Focus #4: a directory of nothing but default.json files is
    /// readable and non-empty, not an empty directory.
    func testDefaultOnlyDirectoryIsNotEmpty() throws {
        try write("app-info/default.json", #"{"name":"MyApp"}"#)
        try write("version/1.2.3/default.json", #"{"description":"D"}"#)
        let dir = makeDirectory()
        XCTAssertEqual(try dir.enumeratedFileCount(), 2)
        XCTAssertTrue(dir.hasDefaultFallback)
        XCTAssertTrue(dir.allLocales.isEmpty)
    }

    func testMissingDirectoryEnumeratesToZero() throws {
        let missing = StoreMetadataDirectory(
            root: root.appendingPathComponent("does-not-exist"))
        XCTAssertEqual(try missing.enumeratedFileCount(), 0)
    }

    /// Multiple version directories are all scanned — verified against asc,
    /// which reported filesScanned=3 for two version dirs plus app-info.
    func testAllVersionDirectoriesAreCounted() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("version/1.2.2/en-US.json", #"{"description":"D"}"#)
        try write("version/1.2.3/en-US.json", #"{"description":"D"}"#)
        XCTAssertEqual(try makeDirectory().enumeratedFileCount(), 3)
    }

    func testNonJSONFilesAreIgnored() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("app-info/notes.txt", "ignore me")
        try write(".DS_Store", "junk")
        XCTAssertEqual(try makeDirectory().enumeratedFileCount(), 1)
    }

    // MARK: - Stray paths asc would silently ignore

    /// Review Focus #1: the plural form. asc ignores it and reports a clean
    /// validation, so a push would succeed while changing nothing.
    func testPluralVersionsDirectoryIsReportedAsStray() throws {
        try write("version/1.2.3/en-US.json", #"{"description":"D"}"#)
        try write("versions/1.2.3/en-US.json", #"{"description":"D"}"#)
        let stray = try makeDirectory().strayDirectories()
        XCTAssertTrue(stray.contains { $0.hasSuffix("versions") },
                      "A plural `versions/` directory must be reported — asc ignores it silently.")
    }

    /// Review Focus #5: a locale nested one level too deep. asc ignores it,
    /// and a naive recursive walk would count it.
    func testNestedLocaleDirectoryIsReportedAsStray() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("version/1.2.3/ja-JP/en-US.json", #"{"description":"D"}"#)
        let dir = makeDirectory()
        XCTAssertEqual(try dir.enumeratedFileCount(), 1,
                       "The nested file must not be counted as a recognised locale file.")
        XCTAssertTrue(try dir.strayDirectories().contains { $0.contains("ja-JP") })
    }

    func testUnknownTopLevelDirectoryIsStray() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("screenshots/en-US/1.png", "not really a png")
        XCTAssertTrue(try makeDirectory().strayDirectories().contains { $0.hasSuffix("screenshots") })
    }

    func testCleanDirectoryHasNoStrayPaths() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("version/1.2.3/en-US.json", #"{"description":"D"}"#)
        XCTAssertTrue(try makeDirectory().strayDirectories().isEmpty)
    }

    // MARK: - The guard

    func testGuardPassesWhenCountsAgree() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("version/1.2.3/en-US.json", #"{"description":"D"}"#)
        XCTAssertNoThrow(try StoreMetadataGuard.assertConsistent(
            ascScanned: 2, local: makeDirectory()))
    }

    func testGuardRaisesOnMismatch() throws {
        try write("app-info/en-US.json", #"{"name":"MyApp"}"#)
        try write("versions/1.2.3/en-US.json", #"{"description":"D"}"#)
        XCTAssertThrowsError(try StoreMetadataGuard.assertConsistent(
            ascScanned: 1, local: makeDirectory())
        ) { error in
            let e = error as? LutinError
            XCTAssertEqual(e?.code, "store_layout_mismatch")
            XCTAssertNotNil(e?.details?["stray"])
        }
    }

    func testGuardTreatsZeroAgainstZeroAsConsistent() throws {
        XCTAssertNoThrow(try StoreMetadataGuard.assertConsistent(
            ascScanned: 0, local: makeDirectory()))
    }

    // MARK: - Reading

    func testReadsALocalization() throws {
        try write("version/1.2.3/en-US.json", #"{"description":"D","keywords":"a,b"}"#)
        let loc = try makeDirectory().localization(scope: .version, locale: "en-US", version: "1.2.3")
        XCTAssertEqual(loc.values[.description], "D")
        XCTAssertEqual(loc.values[.keywords], "a,b")
    }

    func testReadingMissingFileRaisesConfigStyleError() throws {
        XCTAssertThrowsError(
            try makeDirectory().localization(scope: .version, locale: "en-US", version: "9.9.9")
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_missing")
        }
    }
}
