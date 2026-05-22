import XCTest
@testable import LutinBuilder

final class DSStoreRecordsTests: XCTestCase {
    func testIlocBlobLayout() {
        let blob = DSStoreRecords.ilocBlob(x: 180, y: 220)
        XCTAssertEqual(blob.count, 16)
        XCTAssertEqual(Array(blob.prefix(4)), [0, 0, 0, 180])           // x BE
        XCTAssertEqual(Array(blob[4..<8]), [0, 0, 0, 220])              // y BE
        XCTAssertEqual(Array(blob.suffix(8)), [0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00])
    }

    func testBwspIsValidBinaryPlistWithWindowBounds() throws {
        let blob = DSStoreRecords.bwspBlob(windowWidth: 680, windowHeight: 420,
                                           showSidebar: false, showToolbar: false)
        let plist = try PropertyListSerialization.propertyList(
            from: blob, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["WindowBounds"] as? String, "{{100, 100}, {680, 420}}")
        XCTAssertEqual(plist?["ShowSidebar"] as? Bool, false)
    }

    func testIcvpColorBackgroundIsValidBinaryPlist() throws {
        let blob = DSStoreRecords.icvpBlob(iconSize: 96, textSize: 13,
                                           background: .color(red: 1, green: 1, blue: 1))
        let plist = try PropertyListSerialization.propertyList(
            from: blob, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["backgroundType"] as? Int, 1)
        XCTAssertEqual(plist?["iconSize"] as? Double, 96)
    }

    func testIcvpImageBackgroundCarriesAliasData() throws {
        let alias = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let bookmark = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let blob = DSStoreRecords.icvpBlob(iconSize: 96, textSize: 13,
                                           background: .image(alias: alias, bookmark: bookmark))
        let plist = try PropertyListSerialization.propertyList(
            from: blob, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["backgroundType"] as? Int, 2)
        XCTAssertEqual(plist?["backgroundImageAlias"] as? Data, alias)
    }
}
