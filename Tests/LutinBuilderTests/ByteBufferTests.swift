import XCTest
@testable import LutinBuilder

final class ByteBufferTests: XCTestCase {
    func testAppendUInt32BigEndian() {
        var buf = ByteBuffer()
        buf.appendUInt32(0x01020304)
        XCTAssertEqual(Array(buf.data), [0x01, 0x02, 0x03, 0x04])
    }

    func testAppendUInt16BigEndian() {
        var buf = ByteBuffer()
        buf.appendUInt16(0xABCD)
        XCTAssertEqual(Array(buf.data), [0xAB, 0xCD])
    }

    func testAppendBytesAndFourCC() {
        var buf = ByteBuffer()
        buf.appendFourCC("Iloc")
        XCTAssertEqual(Array(buf.data), Array("Iloc".utf8))
    }

    func testAppendUTF16BigEndian() {
        var buf = ByteBuffer()
        buf.appendUTF16BE("AB")
        XCTAssertEqual(Array(buf.data), [0x00, 0x41, 0x00, 0x42])
    }

    func testCountReflectsLength() {
        var buf = ByteBuffer()
        buf.appendUInt32(0)
        XCTAssertEqual(buf.count, 4)
    }
}
