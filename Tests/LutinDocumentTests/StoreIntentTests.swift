import XCTest
@testable import LutinDocument
import LutinConfig
import LutinCore

final class StoreIntentTests: XCTestCase {

    private func document() throws -> LutinProjectDocument {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-store-intent-\(UUID().uuidString).yml")
        let config = LutinConfig.empty(name: "MyApp", bundleId: "com.example.myapp",
                                       appPath: "./MyApp.app", outputDir: "./release",
                                       dmgName: "MyApp.dmg", volumeName: "MyApp")
        try config.save(to: url)
        return try LutinProjectDocument(configURL: url)
    }

    func testSetStoreAppCreatesTheBlock() throws {
        let doc = try document()
        try doc.apply(.setStoreApp(appID: "42", bundleID: nil, platform: "MAC_OS"))
        XCTAssertEqual(doc.config.store?.appID, "42")
        XCTAssertEqual(doc.config.store?.platform, "MAC_OS")
    }

    func testSetStoreAppIsUndoable() throws {
        let doc = try document()
        try doc.apply(.setStoreApp(appID: "42", bundleID: nil, platform: nil))
        doc.undo()
        XCTAssertNil(doc.config.store?.appID)
    }

    func testSetStoreMetadataDirPreservesExistingAppID() throws {
        let doc = try document()
        try doc.apply(.setStoreApp(appID: "42", bundleID: nil, platform: nil))
        try doc.apply(.setStoreMetadataDir(path: "store/meta"))
        XCTAssertEqual(doc.config.store?.appID, "42",
                       "Editing one store field must not clear the others.")
        XCTAssertEqual(doc.config.store?.metadataDir, "store/meta")
    }

    func testSetStoreASCPathIsUndoable() throws {
        let doc = try document()
        try doc.apply(.setStoreASCPath(path: "/custom/asc"))
        XCTAssertEqual(doc.config.store?.ascPath, "/custom/asc")
        doc.undo()
        XCTAssertNil(doc.config.store?.ascPath)
    }
}
