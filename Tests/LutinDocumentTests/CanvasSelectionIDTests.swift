import XCTest
@testable import LutinDocument

final class CanvasSelectionIDTests: XCTestCase {
    func testItemEquality() {
        XCTAssertEqual(CanvasSelectionID.item(id: "a"), .item(id: "a"))
        XCTAssertNotEqual(CanvasSelectionID.item(id: "a"), .item(id: "b"))
    }
    func testArrowEquality() {
        XCTAssertEqual(CanvasSelectionID.arrow(from: "a", to: "b"),
                       .arrow(from: "a", to: "b"))
        XCTAssertNotEqual(CanvasSelectionID.arrow(from: "a", to: "b"),
                          .arrow(from: "b", to: "a"))
    }
    func testImageEquality() {
        XCTAssertEqual(CanvasSelectionID.image(index: 0), .image(index: 0))
    }
    func testHashableForSet() {
        let s: Set<CanvasSelectionID> = [.item(id: "a"), .item(id: "a"), .image(index: 0)]
        XCTAssertEqual(s.count, 2)
    }
    func testIsMoveable() {
        XCTAssertTrue(CanvasSelectionID.item(id: "a").isMoveable)
        XCTAssertTrue(CanvasSelectionID.image(index: 0).isMoveable)
        XCTAssertFalse(CanvasSelectionID.arrow(from: "a", to: "b").isMoveable)
    }
}
