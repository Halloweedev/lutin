import XCTest
@testable import LutinUI
import LutinDocument

final class AlignDistributeTests: XCTestCase {
    private struct E: AlignableElement {
        var idForTest: String
        var x: Int
        var y: Int
        func selectionID() -> CanvasSelectionID { .item(id: idForTest) }
    }
    func testAlignLeftMovesAllToMinX() {
        let elements = [E(idForTest: "a", x: 100, y: 0), E(idForTest: "b", x: 200, y: 0)]
        let deltas = AlignDistribute.align(elements, anchor: .left)
        XCTAssertEqual(deltas.first(where: {
            if case .item(let id) = $0.target { return id == "b" } else { return false }
        })?.dx, -100)
    }
    func testAlignCenterHorizontal() {
        let elements = [E(idForTest: "a", x: 100, y: 0), E(idForTest: "b", x: 300, y: 0)]
        let deltas = AlignDistribute.align(elements, anchor: .centerHorizontal)
        let midX = (100 + 300) / 2  // 200
        XCTAssertEqual(deltas.first(where: {
            if case .item(let id) = $0.target { return id == "a" } else { return false }
        })?.dx, midX - 100)
    }
    func testDistributeHorizontalEqualizesGaps() {
        let elements = [
            E(idForTest: "a", x: 0, y: 0),
            E(idForTest: "b", x: 100, y: 0),
            E(idForTest: "c", x: 300, y: 0),
        ]
        let deltas = AlignDistribute.distribute(elements, axis: .horizontal)
        XCTAssertEqual(deltas.first(where: {
            if case .item(let id) = $0.target { return id == "b" } else { return false }
        })?.dx, 50)
    }
}
