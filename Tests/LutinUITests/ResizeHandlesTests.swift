import XCTest
@testable import LutinUI

final class ResizeHandlesTests: XCTestCase {
    private let start = ResizeHandles.Rect(x: 100, y: 100, width: 200, height: 100)

    func testEastGrowsWidthOnly() {
        let r = ResizeHandles.resized(start, direction: .e, translation: .init(width: 50, height: 999))
        XCTAssertEqual(r, ResizeHandles.Rect(x: 100, y: 100, width: 250, height: 100))
    }

    func testSouthGrowsHeightOnly() {
        let r = ResizeHandles.resized(start, direction: .s, translation: .init(width: 999, height: 40))
        XCTAssertEqual(r, ResizeHandles.Rect(x: 100, y: 100, width: 200, height: 140))
    }

    func testWestAnchorsRightEdge() {
        // Dragging the west handle right by 30 shrinks width and shifts x so
        // the right edge (300) stays put.
        let r = ResizeHandles.resized(start, direction: .w, translation: .init(width: 30, height: 0))
        XCTAssertEqual(r, ResizeHandles.Rect(x: 130, y: 100, width: 170, height: 100))
        XCTAssertEqual(r.x + r.width, 300)
    }

    func testNorthAnchorsBottomEdge() {
        let r = ResizeHandles.resized(start, direction: .n, translation: .init(width: 0, height: 20))
        XCTAssertEqual(r, ResizeHandles.Rect(x: 100, y: 120, width: 200, height: 80))
        XCTAssertEqual(r.y + r.height, 200)
    }

    func testNorthWestCornerChangesBoth() {
        let r = ResizeHandles.resized(start, direction: .nw, translation: .init(width: 30, height: 20))
        XCTAssertEqual(r, ResizeHandles.Rect(x: 130, y: 120, width: 170, height: 80))
        XCTAssertEqual(r.x + r.width, 300)
        XCTAssertEqual(r.y + r.height, 200)
    }

    func testClampKeepsAnchorEdge() {
        // Over-shrinking from the west clamps width to 16 but the right edge
        // (300) must still hold, so x = 300 - 16.
        let r = ResizeHandles.resized(start, direction: .w, translation: .init(width: 500, height: 0))
        XCTAssertEqual(r.width, 16)
        XCTAssertEqual(r.x, 284)
        XCTAssertEqual(r.x + r.width, 300)
    }
}
