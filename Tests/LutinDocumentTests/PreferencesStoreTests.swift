import XCTest
import TestSupport
@testable import LutinDocument

final class PreferencesStoreTests: XCTestCase {
    func testDefaultsWhenFileMissing() throws {
        let dir = try Fixtures.makeTempDirectory()
        let store = PreferencesStore(storeURL: dir.appendingPathComponent("preferences.json"))
        try store.reload()
        XCTAssertEqual(store.preferences.autosave, false)
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
            try store.update { $0.autosave = true; $0.snapGridSize = 8 }
        }
        let reloaded = PreferencesStore(storeURL: url)
        try reloaded.reload()
        XCTAssertEqual(reloaded.preferences.autosave, true)
        XCTAssertEqual(reloaded.preferences.snapGridSize, 8)
    }
}
