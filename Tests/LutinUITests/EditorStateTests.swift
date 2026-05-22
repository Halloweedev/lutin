import XCTest
@testable import LutinUI

final class EditorStateTests: XCTestCase {
    func testStartsAtDesignTab() {
        let s = EditorState(configPath: "/a/lutin.yml")
        XCTAssertEqual(s.selectedTab, .design)
    }
    func testRoundTripsTabSelection() {
        let store = EditorStateStore()
        let a = store.state(forConfigPath: "/a/lutin.yml")
        a.selectedTab = .release
        let aAgain = store.state(forConfigPath: "/a/lutin.yml")
        XCTAssertEqual(aAgain.selectedTab, .release, "state must be the same instance")
    }
    func testDifferentPathsAreIndependent() {
        let store = EditorStateStore()
        let a = store.state(forConfigPath: "/a/lutin.yml")
        let b = store.state(forConfigPath: "/b/lutin.yml")
        a.selectedTab = .release
        XCTAssertEqual(b.selectedTab, .design)
    }
    func testZoomDefaults100Percent() {
        XCTAssertEqual(EditorState(configPath: "/x").zoomPercent, 100)
    }
}
