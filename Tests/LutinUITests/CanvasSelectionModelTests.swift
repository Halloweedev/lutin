import XCTest
@testable import LutinUI
import LutinDocument

final class CanvasSelectionModelTests: XCTestCase {
    func testStartsEmpty() {
        let m = CanvasSelectionModel()
        XCTAssertTrue(m.selection.isEmpty)
    }
    func testSelectReplaces() {
        let m = CanvasSelectionModel()
        m.select(.item(id: "a"))
        m.select(.item(id: "b"))
        XCTAssertEqual(m.selection, [.item(id: "b")])
    }
    func testToggleAddsAndRemoves() {
        let m = CanvasSelectionModel()
        m.toggle(.item(id: "a"))
        XCTAssertEqual(m.selection, [.item(id: "a")])
        m.toggle(.item(id: "b"))
        XCTAssertEqual(m.selection, [.item(id: "a"), .item(id: "b")])
        m.toggle(.item(id: "a"))
        XCTAssertEqual(m.selection, [.item(id: "b")])
    }
    func testReplaceAll() {
        let m = CanvasSelectionModel()
        m.replace(with: [.item(id: "a"), .image(index: 0)])
        XCTAssertEqual(m.selection.count, 2)
    }
    func testClear() {
        let m = CanvasSelectionModel()
        m.select(.item(id: "a"))
        m.clear()
        XCTAssertTrue(m.selection.isEmpty)
    }
    func testMoveableSubset() {
        let m = CanvasSelectionModel()
        m.replace(with: [.item(id: "a"), .arrow(from: "a", to: "b"), .image(index: 0)])
        XCTAssertEqual(m.moveableIDs.count, 2)
        XCTAssertFalse(m.moveableIDs.contains(.arrow(from: "a", to: "b")))
    }
}
