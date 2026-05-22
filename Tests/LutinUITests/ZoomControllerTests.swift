import XCTest
@testable import LutinUI

final class ZoomControllerTests: XCTestCase {
    func testStepUpFromOneHundred() {
        XCTAssertEqual(ZoomController.stepUp(from: 100), 125)
    }
    func testStepDownFromOneHundred() {
        XCTAssertEqual(ZoomController.stepDown(from: 100), 75)
    }
    func testStepUpAtMax() {
        XCTAssertEqual(ZoomController.stepUp(from: 200), 200)
    }
    func testStepDownAtMin() {
        XCTAssertEqual(ZoomController.stepDown(from: 25), 25)
    }
    func testNonStandardValuesRoundToNearest() {
        XCTAssertEqual(ZoomController.stepUp(from: 80), 100)
        XCTAssertEqual(ZoomController.stepDown(from: 80), 75)
    }
    func testFitForLargerCanvas() {
        XCTAssertEqual(ZoomController.fitPercent(
            canvas: CGSize(width: 1200, height: 800),
            pane: CGSize(width: 600, height: 400)), 50)
    }
    func testFitNeverExceedsHundred() {
        XCTAssertEqual(ZoomController.fitPercent(
            canvas: CGSize(width: 100, height: 100),
            pane: CGSize(width: 1000, height: 1000)), 100)
    }
}
