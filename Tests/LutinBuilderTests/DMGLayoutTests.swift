import XCTest
import LutinConfig
import LutinCore
@testable import LutinBuilder

final class DMGLayoutTests: XCTestCase {
    private func config(items: [LutinConfig.Item]?) -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.x.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry.dmg", volumeName: "Barry"),
            window: LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                textSize: 13, showToolbar: false, showSidebar: false),
            background: nil, items: items, decorations: nil,
            signing: nil, notarization: nil, sparkle: nil)
    }

    func testResolvesWindowAndIconPlacements() throws {
        let items: [LutinConfig.Item] = [
            .init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
            .init(type: "applications", id: "applications", x: 500, y: 220, label: "Applications"),
        ]
        let layout = try LayoutResolver.resolve(config: config(items: items),
                                                appFileName: "Barry.app")
        // config.window.height (420) is the content area; the layout's outer
        // frame grows by FinderChrome.totalHeightPoints so WindowBounds leaves
        // exactly 420 pt of content area for the background.
        XCTAssertEqual(layout.windowWidth, 680)
        XCTAssertEqual(layout.windowHeight, 420 + FinderChrome.totalHeightPoints)
        XCTAssertEqual(layout.iconSize, 96)
        XCTAssertEqual(layout.placements["Barry.app"]?.x, 180)
        XCTAssertEqual(layout.placements["Applications"]?.x, 500)
    }

    func testAppItemMapsToActualAppFileName() throws {
        let items: [LutinConfig.Item] = [
            .init(type: "app", id: "app", x: 100, y: 100, label: nil),
        ]
        let layout = try LayoutResolver.resolve(config: config(items: items),
                                                appFileName: "MyCoolApp.app")
        XCTAssertNotNil(layout.placements["MyCoolApp.app"])
        XCTAssertNil(layout.placements["Barry.app"])
    }

    func testNilItemsProducesEmptyPlacements() throws {
        let layout = try LayoutResolver.resolve(config: config(items: nil),
                                                appFileName: "Barry.app")
        XCTAssertTrue(layout.placements.isEmpty)
        XCTAssertEqual(layout.windowWidth, 680)
    }
}
