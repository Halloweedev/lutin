import XCTest
import SwiftUI
@testable import LutinUI

final class SidePanelClampingTests: XCTestCase {
    func testClampsToMin() {
        XCTAssertEqual(SidePanel<EmptyView>.clampWidth(100), Tokens.Size.sidePanelMin)
    }
    func testClampsToMax() {
        XCTAssertEqual(SidePanel<EmptyView>.clampWidth(9999), Tokens.Size.sidePanelMax)
    }
    func testReturnsValueInRange() {
        XCTAssertEqual(SidePanel<EmptyView>.clampWidth(300), 300)
    }
}
