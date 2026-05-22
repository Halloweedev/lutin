import XCTest
@testable import LutinUI

final class EditorTabsTests: XCTestCase {
    func testAllTabsExist() {
        XCTAssertEqual(EditorTab.allCases.count, 4)
        XCTAssertEqual(EditorTab.allCases, [.design, .window, .project, .release])
    }
    func testIconNamesNonEmpty() {
        for tab in EditorTab.allCases {
            XCTAssertFalse(tab.iconName.isEmpty)
            XCTAssertFalse(tab.title.isEmpty)
        }
    }
}
