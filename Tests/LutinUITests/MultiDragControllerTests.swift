import XCTest
@testable import LutinUI
import LutinDocument

final class MultiDragControllerTests: XCTestCase {
    func testDeltasIncludeEveryKind() {
        let sel: Set<CanvasSelectionID> = [
            .item(id: "a"),
            .image(index: 0),
        ]
        let deltas = ItemDragController.deltas(forSelection: sel, dx: 5, dy: 7)
        XCTAssertEqual(deltas.count, 2)
        XCTAssertTrue(deltas.contains(where: {
            if case .item(let id) = $0.target { return id == "a" && $0.dx == 5 && $0.dy == 7 }
            return false
        }))
        XCTAssertTrue(deltas.contains(where: {
            if case .imageDecoration(let i) = $0.target { return i == 0 }
            return false
        }))
    }
    func testSnapToGridUpDown() {
        XCTAssertEqual(ItemDragController.snap(13, gridSize: 8), 16)
        XCTAssertEqual(ItemDragController.snap(11, gridSize: 8), 8)
        XCTAssertEqual(ItemDragController.snap(0, gridSize: 0), 0)
        XCTAssertEqual(ItemDragController.snap(5, gridSize: 0), 5)
    }
}
