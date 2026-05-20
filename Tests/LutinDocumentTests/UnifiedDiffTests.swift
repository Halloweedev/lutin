import XCTest
@testable import LutinDocument

final class UnifiedDiffTests: XCTestCase {
    func testIdenticalProducesNoHunks() {
        let diff = UnifiedDiff.diff(left: "a\nb\nc", right: "a\nb\nc")
        XCTAssertTrue(diff.hunks.isEmpty)
    }

    func testSimpleReplacement() {
        let diff = UnifiedDiff.diff(left: "a\nb\nc", right: "a\nB\nc")
        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertEqual(diff.hunks[0].lines.filter { $0.kind == .removed }.map(\.text), ["b"])
        XCTAssertEqual(diff.hunks[0].lines.filter { $0.kind == .added }.map(\.text), ["B"])
    }

    func testInsertion() {
        let diff = UnifiedDiff.diff(left: "a\nc", right: "a\nb\nc")
        let added = diff.hunks.flatMap { $0.lines }.filter { $0.kind == .added }
        XCTAssertEqual(added.map(\.text), ["b"])
    }
}
