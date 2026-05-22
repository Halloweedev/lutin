import XCTest
@testable import LutinUI

final class AlignmentGuidesTests: XCTestCase {
    func testHorizontalCenterSnapWithinThreshold() {
        let candidates = [100, 200, 300]
        let snap = AlignmentGuides.snap(value: 102, candidates: candidates, threshold: 4)
        XCTAssertEqual(snap.value, 100)
        XCTAssertEqual(snap.target, 100)
    }
    func testNoSnapOutsideThreshold() {
        let candidates = [100, 200]
        let snap = AlignmentGuides.snap(value: 150, candidates: candidates, threshold: 4)
        XCTAssertEqual(snap.value, 150)
        XCTAssertNil(snap.target)
    }
    func testEqualSpacingDetection() {
        let result = AlignmentGuides.equalSpacing(value: 49,
                                                  others: [0, 100],
                                                  threshold: 4)
        XCTAssertEqual(result?.snapped, 50)
        XCTAssertEqual(result?.distance, 50)
    }
}
