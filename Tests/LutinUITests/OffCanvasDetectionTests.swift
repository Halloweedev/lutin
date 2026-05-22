import XCTest
@testable import LutinUI
import LutinConfig
import LutinDocument

final class OffCanvasDetectionTests: XCTestCase {
    func testItemFullyInside() {
        var c = LutinConfig.empty(name: "T", bundleId: "c.t",
                                  appPath: "./x.app", outputDir: "o",
                                  dmgName: "t.dmg", volumeName: "T")
        c.window = LutinConfig.WindowInfo(width: 800, height: 600, iconSize: 80,
                                          textSize: nil, showToolbar: nil, showSidebar: nil)
        c.items = [LutinConfig.Item(type: "app", id: "a", x: 100, y: 100, label: nil, hidden: nil)]
        XCTAssertTrue(OffCanvasDetection.outsiders(in: c).isEmpty)
    }

    func testItemOutsideRight() {
        var c = LutinConfig.empty(name: "T", bundleId: "c.t",
                                  appPath: "./x.app", outputDir: "o",
                                  dmgName: "t.dmg", volumeName: "T")
        c.window = LutinConfig.WindowInfo(width: 800, height: 600, iconSize: 80,
                                          textSize: nil, showToolbar: nil, showSidebar: nil)
        c.items = [LutinConfig.Item(type: "app", id: "a", x: 900, y: 100, label: nil, hidden: nil)]
        let out = OffCanvasDetection.outsiders(in: c)
        XCTAssertEqual(out.first, .item(id: "a"))
    }

    func testImageOutsideTop() {
        var c = LutinConfig.empty(name: "T", bundleId: "c.t",
                                  appPath: "./x.app", outputDir: "o",
                                  dmgName: "t.dmg", volumeName: "T")
        c.window = LutinConfig.WindowInfo(width: 800, height: 600, iconSize: 80,
                                          textSize: nil, showToolbar: nil, showSidebar: nil)
        var img = LutinConfig.Decoration(type: "image")
        img.path = "./i.png"; img.x = 100; img.y = -100; img.width = 80
        c.decorations = [img]
        let out = OffCanvasDetection.outsiders(in: c)
        XCTAssertEqual(out.first, .image(index: 0))
    }
}
