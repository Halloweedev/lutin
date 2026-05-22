import XCTest
import LutinConfig
import LutinDocument
import TestSupport
@testable import LutinUI

final class SelectionModelTests: XCTestCase {
    /// Barry has no items by default; seed an "app" item plus a dummy arrow
    /// referencing it so deletion semantics are observable.
    private func tempBarry() throws -> LutinProjectDocument {
        let dir = try Fixtures.makeTempDirectory()
        let url = dir.appendingPathComponent("lutin.yml")
        try FileManager.default.copyItem(at: Fixtures.barryConfig, to: url)
        var seeded = try LutinConfig.load(from: url)
        seeded.items = [
            LutinConfig.Item(type: "app", id: "app", x: 100, y: 100, label: nil),
            LutinConfig.Item(type: "applications", id: "apps", x: 400, y: 100, label: nil),
        ]
        seeded.decorations = [
            LutinConfig.Decoration(type: "arrow", from: "app", to: "apps", label: nil)
        ]
        try seeded.save(to: url)
        return try LutinProjectDocument(configURL: url)
    }

    func testDeleteItemSelectionAlsoRemovesArrowsReferencingIt() throws {
        let doc = try tempBarry()
        let model = CanvasSelectionModel()
        model.select(.item(id: "app"))
        try model.delete(in: doc)
        XCTAssertFalse(doc.config.items?.contains(where: { $0.id == "app" }) ?? false)
        XCTAssertFalse(doc.config.decorations?.contains(where: { $0.from == "app" || $0.to == "app" }) ?? false)
    }

    func testDuplicateItemAddsNewUniqueId() throws {
        let doc = try tempBarry()
        let model = CanvasSelectionModel()
        model.select(.item(id: "app"))
        try model.duplicate(in: doc)
        let appIDs = (doc.config.items ?? []).filter { $0.type == "app" }.map(\.id)
        XCTAssertEqual(appIDs.count, 2)
        XCTAssertEqual(Set(appIDs).count, 2)
    }
}
