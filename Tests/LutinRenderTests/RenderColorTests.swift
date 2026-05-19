import XCTest
import CoreGraphics
@testable import LutinRender

final class RenderColorTests: XCTestCase {
    func testParsesSixDigitHexWithHash() {
        let c = RenderColor.parse("#EEF4FF")
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.red, 0xEE / 255.0, accuracy: 0.001)
        XCTAssertEqual(c!.green, 0xF4 / 255.0, accuracy: 0.001)
        XCTAssertEqual(c!.blue, 0xFF / 255.0, accuracy: 0.001)
        XCTAssertEqual(c!.alpha, 1.0, accuracy: 0.001)
    }

    func testParsesWithoutHashAndIsCaseInsensitive() {
        XCTAssertNotNil(RenderColor.parse("ffffff"))
        XCTAssertEqual(RenderColor.parse("ffffff")!.red, 1.0, accuracy: 0.001)
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(RenderColor.parse("#FFF"))
        XCTAssertNil(RenderColor.parse("notacolor"))
        XCTAssertNil(RenderColor.parse(""))
    }

    func testProducesACGColor() {
        let cg = RenderColor.parse("#000000")!.cgColor
        XCTAssertEqual(cg.components?.count, 4)
    }
}
