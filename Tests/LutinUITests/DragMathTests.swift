import XCTest
@testable import LutinUI

final class DragMathTests: XCTestCase {
    func testSnapToGridRoundsToNearest() {
        XCTAssertEqual(DragMath.snap(13, grid: 4), 12)
        XCTAssertEqual(DragMath.snap(14, grid: 4), 16)
        XCTAssertEqual(DragMath.snap(0, grid: 4), 0)
        XCTAssertEqual(DragMath.snap(99, grid: 4), 100)
    }

    func testAlignmentGuidesFindCenterMatches() {
        let result = DragMath.alignmentGuides(forCenter: CGPoint(x: 100, y: 200),
                                              against: [CGPoint(x: 100, y: 50), CGPoint(x: 50, y: 200)],
                                              tolerance: 2)
        XCTAssertTrue(result.vertical)
        XCTAssertTrue(result.horizontal)
    }

    func testAlignmentGuidesIgnoresOutsideTolerance() {
        let result = DragMath.alignmentGuides(forCenter: CGPoint(x: 100, y: 200),
                                              against: [CGPoint(x: 105, y: 50)],
                                              tolerance: 2)
        XCTAssertFalse(result.vertical)
        XCTAssertFalse(result.horizontal)
    }
}
