import XCTest
@testable import LutinUI
import LutinConfig
import LutinDocument

final class MarqueeIntersectionTests: XCTestCase {
    private func cfg() -> LutinConfig {
        var c = LutinConfig.empty(name: "T", bundleId: "c.t",
                                  appPath: "./x.app", outputDir: "o",
                                  dmgName: "t.dmg", volumeName: "T")
        c.window = LutinConfig.WindowInfo(width: 800, height: 600, iconSize: 80,
                                          textSize: nil, showToolbar: nil, showSidebar: nil)
        c.items = [
            LutinConfig.Item(type: "app", id: "a", x: 100, y: 100, label: nil, hidden: nil),
            LutinConfig.Item(type: "applications", id: "b", x: 300, y: 100, label: nil, hidden: nil),
            LutinConfig.Item(type: "app", id: "c", x: 500, y: 400, label: nil, hidden: nil),
        ]
        var arrow = LutinConfig.Decoration(type: "arrow"); arrow.from = "a"; arrow.to = "b"
        var image = LutinConfig.Decoration(type: "image"); image.path = "./i.png"; image.x = 200; image.y = 350; image.width = 80
        c.decorations = [arrow, image]
        return c
    }

    func testFullyEnclosingMarqueePicksUpEverything() {
        let r = CGRect(x: 0, y: 0, width: 800, height: 600)
        let hits = MarqueeSelection.hits(in: cfg(), rect: r)
        XCTAssertEqual(hits.count, 5) // 3 items + 1 image + 1 arrow
    }

    func testTopLeftMarqueePicksUpOneItem() {
        let r = CGRect(x: 40, y: 40, width: 120, height: 120)
        let hits = MarqueeSelection.hits(in: cfg(), rect: r)
        XCTAssertTrue(hits.contains(.item(id: "a")))
        XCTAssertFalse(hits.contains(.item(id: "b")))
    }

    func testArrowIncludedWhenMarqueeIntersectsItsLineBBox() {
        let r = CGRect(x: 80, y: 95, width: 240, height: 10)
        let hits = MarqueeSelection.hits(in: cfg(), rect: r)
        XCTAssertTrue(hits.contains(.arrow(from: "a", to: "b")))
    }
}
