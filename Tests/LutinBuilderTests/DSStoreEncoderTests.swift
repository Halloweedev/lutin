import XCTest
@testable import LutinBuilder

final class DSStoreEncoderTests: XCTestCase {
    private func sampleLayout() -> DMGLayout {
        DMGLayout(windowWidth: 680, windowHeight: 420, iconSize: 96, textSize: 13,
                  showSidebar: false, showToolbar: false,
                  placements: [
                    "Barry.app": .init(x: 180, y: 220),
                    "Applications": .init(x: 500, y: 220),
                  ])
    }

    func testStartsWithBud1Magic() throws {
        let bytes = try DSStoreEncoder.encode(layout: sampleLayout(), background: .none)
        XCTAssertEqual(Array(bytes.prefix(4)), [0x00, 0x00, 0x00, 0x01])
        XCTAssertEqual(Array(bytes[4..<8]), Array("Bud1".utf8))
    }

    func testContainsRecordStructIdsForItems() throws {
        let bytes = try DSStoreEncoder.encode(layout: sampleLayout(), background: .none)
        // The encoded blob must mention the record types.
        XCTAssertNotNil(bytes.range(of: Data("Iloc".utf8)))
        XCTAssertNotNil(bytes.range(of: Data("bwsp".utf8)))
        XCTAssertNotNil(bytes.range(of: Data("icvp".utf8)))
    }

    func testIsNonEmptyAndAllocatorOffsetWithinBounds() throws {
        let bytes = try DSStoreEncoder.encode(layout: sampleLayout(), background: .none)
        XCTAssertGreaterThan(bytes.count, 64)
        let rootOffset = bytes[8...11].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        XCTAssertLessThan(Int(rootOffset), bytes.count)
    }
}
