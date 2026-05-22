import XCTest
@testable import LutinUI
import LutinConfig
import LutinDocument

final class LayersOrderingTests: XCTestCase {
    func testTopToBottomOrder() {
        var cfg = LutinConfig.empty(name: "T", bundleId: "c.t",
                                    appPath: "./x.app", outputDir: "out",
                                    dmgName: "t.dmg", volumeName: "T")
        cfg.items = [LutinConfig.Item(type: "app", id: "a", x: 0, y: 0, label: nil, hidden: nil),
                     LutinConfig.Item(type: "app", id: "b", x: 0, y: 0, label: nil, hidden: nil)]
        var arrow = LutinConfig.Decoration(type: "arrow")
        arrow.from = "a"; arrow.to = "b"
        var image = LutinConfig.Decoration(type: "image")
        image.path = "./i.png"; image.x = 0; image.y = 0; image.width = 10
        cfg.decorations = [arrow, image]
        let rows = LayersOrdering.rows(from: cfg)
        XCTAssertEqual(rows.map(\.id), [
            .item(id: "a"),
            .item(id: "b"),
            .image(index: 1),
            .arrow(from: "a", to: "b"),
        ])
    }
}
