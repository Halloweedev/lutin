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
        // Item at x=292 with width 96 → center 340. Canvas centerX 340.
        // rawTranslation 0 → proposed center 340 == canvas center.
        let result = DragMath.canvasCenterSnap(
            elementOrigin: 292,
            elementSize: 96,
            rawTranslation: 0,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 0)  // translation needed to keep center on canvas center
    }

    func testCanvasCenterSnapFiresWithinThresholdAndReturnsSnappedTranslation() {
        // Item origin 292, size 96, raw translation 3 → proposed center 343.
        // |343 - 340| = 3 ≤ 4 → snap. Required translation: 340 - 292 - 48 = 0.
        let result = DragMath.canvasCenterSnap(
            elementOrigin: 292,
            elementSize: 96,
            rawTranslation: 3,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 0)
    }

    func testCanvasCenterSnapNegativeSideOfCenterStillFires() {
        // Item origin 295, size 96, raw translation -2 → proposed center 295 - 2 + 48 = 341.
        // |341 - 340| = 1 ≤ 4 → snap. Required translation: 340 - 295 - 48 = -3.
        let result = DragMath.canvasCenterSnap(
            elementOrigin: 295,
            elementSize: 96,
            rawTranslation: -2,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, -3)
    }

    func testCanvasCenterSnapAtExactThresholdBoundaryFires() {
        // proposed center 344, canvas center 340, |Δ| = 4 = threshold → fires (≤).
        let result = DragMath.canvasCenterSnap(
            elementOrigin: 292,
            elementSize: 96,
            rawTranslation: 4,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertEqual(result, 0)
    }

    func testCanvasCenterSnapOutsideThresholdReturnsNil() {
        // proposed center 345, canvas center 340, |Δ| = 5 > threshold 4 → no snap.
        let result = DragMath.canvasCenterSnap(
            elementOrigin: 292,
            elementSize: 96,
            rawTranslation: 5,
            canvasCenter: 340,
            threshold: 4)
        XCTAssertNil(result)
    }

    func testCanvasCenterSnapHandlesNonSquareSize() {
        // Image decoration: width 200, height 100 (aspect 0.5).
        // For the Y axis: origin 165, size 100, raw 0 → proposed center 215.
        // Canvas centerY 210. |215 - 210| = 5 > 4 → nil.
        XCTAssertNil(DragMath.canvasCenterSnap(
            elementOrigin: 165,
            elementSize: 100,
            rawTranslation: 0,
            canvasCenter: 210,
            threshold: 4))
        // Same shape but raw -2 → proposed center 213. |3| ≤ 4 → snap.
        // Required translation: 210 - 165 - 50 = -5.
        XCTAssertEqual(DragMath.canvasCenterSnap(
            elementOrigin: 165,
            elementSize: 100,
            rawTranslation: -2,
            canvasCenter: 210,
            threshold: 4), -5)
    }
}
