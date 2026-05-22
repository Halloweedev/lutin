import XCTest
@testable import LutinBuilder

final class AliasRecordTests: XCTestCase {
    private func sampleInputs(posixPath: String = "/.background/background.png") -> AliasRecord.Inputs {
        AliasRecord.Inputs(
            volumeName: "Barry",
            fileName: "background.png",
            volumeRelativePOSIXPath: posixPath,
            folderName: ".background",
            carbonPath: Data("Barry:.background:\0background.png".utf8),
            volumeCreated: 3788000000,
            fileCreated: 3788000000,
            parentCNID: 123,
            fileCNID: 456,
            cnidPath: [123]
        )
    }

    func testRecordStartsWithVersion2Header() {
        let data = AliasRecord.encode(sampleInputs())
        // application info (4 bytes 0), then record size (2), then version (2) == 2.
        XCTAssertEqual(Array(data.prefix(4)), [0, 0, 0, 0])
        let version = (UInt16(data[6]) << 8) | UInt16(data[7])
        XCTAssertEqual(version, 2)
    }

    func testRecordSizeFieldMatchesActualLength() {
        let data = AliasRecord.encode(sampleInputs())
        let recordSize = (UInt16(data[4]) << 8) | UInt16(data[5])
        XCTAssertEqual(Int(recordSize), data.count)
    }

    func testRecordEndsWithTerminatorTag() {
        let data = AliasRecord.encode(sampleInputs())
        // Last 4 bytes: tag type 0xFFFF, length 0x0000.
        XCTAssertEqual(Array(data.suffix(4)), [0xFF, 0xFF, 0x00, 0x00])
    }

    func testContainsPosixPath() {
        let path = "/.background/background.png"
        let data = AliasRecord.encode(sampleInputs(posixPath: path))
        XCTAssertNotNil(data.range(of: Data(path.utf8)))
    }
}
