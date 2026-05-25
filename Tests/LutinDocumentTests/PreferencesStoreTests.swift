import XCTest
import TestSupport
@testable import LutinDocument

final class PreferencesStoreTests: XCTestCase {
    func testDefaultsWhenFileMissing() throws {
        let dir = try Fixtures.makeTempDirectory()
        let store = PreferencesStore(storeURL: dir.appendingPathComponent("preferences.json"))
        try store.reload()
        XCTAssertEqual(store.preferences.snapGridSize, 4)
        XCTAssertEqual(store.preferences.showAlignmentGuides, true)
        XCTAssertEqual(store.preferences.theme, .system)
    }

    func testRoundTrip() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("preferences.json")
        do {
            let store = PreferencesStore(storeURL: url)
            try store.reload()
            try store.update { $0.snapGridSize = 8; $0.showAlignmentGuides = false }
        }
        let reloaded = PreferencesStore(storeURL: url)
        try reloaded.reload()
        XCTAssertEqual(reloaded.preferences.snapGridSize, 8)
        XCTAssertEqual(reloaded.preferences.showAlignmentGuides, false)
    }

    /// Existing `preferences.json` files written before the `autosave`
    /// field was retired still contain the key. JSONDecoder ignores
    /// unknown fields by default, so loading them must just work.
    func testIgnoresLegacyAutosaveField() throws {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("preferences.json")
        let legacy = #"{"autosave": false, "snapGridSize": 12, "showAlignmentGuides": true, "theme": "dark", "knownNotaryProfiles": ["ci-notary"]}"#
        try legacy.write(to: url, atomically: true, encoding: .utf8)
        let store = PreferencesStore(storeURL: url)
        try store.reload()
        XCTAssertEqual(store.preferences.snapGridSize, 12)
        XCTAssertEqual(store.preferences.theme, .dark)
        XCTAssertEqual(store.preferences.knownNotaryProfiles, ["ci-notary"])
    }
}
