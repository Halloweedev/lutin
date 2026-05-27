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

    // MARK: - canvasCenterSnap

    func testCanvasCenterSnapFiresWhenProposedCenterIsExactlyOnCanvasCenter() {
        // Element visual center 340, canvas center 340, no movement.
        let result = DragMath.canvasCenterSnap(
            currentCenter: 340,
            rawTranslation: 0,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 0)
    }

    func testCanvasCenterSnapFiresWithinThresholdAndReturnsSnappedTranslation() {
        // Current center 337, raw 3 → proposed 340. |0| ≤ 4 → snap.
        // Required translation: 340 - 337 = 3.
        let result = DragMath.canvasCenterSnap(
            currentCenter: 337,
            rawTranslation: 3,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 3)
    }

    func testCanvasCenterSnapNegativeSideOfCenterStillFires() {
        // Current center 343, raw -2 → proposed 341. |1| ≤ 4 → snap.
        // Required translation: 340 - 343 = -3.
        let result = DragMath.canvasCenterSnap(
            currentCenter: 343,
            rawTranslation: -2,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, -3)
    }

    func testCanvasCenterSnapAtExactThresholdBoundaryFires() {
        // Current center 340, raw 4 → proposed 344. |4| = threshold → fires.
        // Required translation: 340 - 340 = 0.
        let result = DragMath.canvasCenterSnap(
            currentCenter: 340,
            rawTranslation: 4,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 0)
    }

    func testCanvasCenterSnapOutsideThresholdReturnsNil() {
        // Current center 340, raw 5 → proposed 345. |5| > 4 → nil.
        let result = DragMath.canvasCenterSnap(
            currentCenter: 340,
            rawTranslation: 5,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertNil(result)
    }

    func testCanvasCenterSnapWorksOnArbitraryAxisValues() {
        // Y axis example: current center 215, canvas center 210, raw 0 → nil.
        XCTAssertNil(DragMath.canvasCenterSnap(
            currentCenter: 215,
            rawTranslation: 0,
            canvasCenter: 210,
            threshold: 4))
        // Same center, raw -2 → proposed 213. |3| ≤ 4 → snap.
        // Required translation: 210 - 215 = -5.
        XCTAssertEqual(DragMath.canvasCenterSnap(
            currentCenter: 215,
            rawTranslation: -2,
            canvasCenter: 210,
            threshold: 4), -5)
    }
}
