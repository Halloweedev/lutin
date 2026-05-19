import XCTest
import CoreGraphics
import ImageIO
import LutinCore
import LutinConfig
@testable import LutinRender

final class LutinRendererTests: XCTestCase {
    private func config(background: LutinConfig.BackgroundInfo?,
                        decorations: [LutinConfig.Decoration]?) -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.x.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry.dmg", volumeName: "Barry"),
            window: .init(width: 200, height: 120, iconSize: 96, textSize: 13,
                          showToolbar: false, showSidebar: false),
            background: background,
            items: [.init(type: "app", id: "app", x: 60, y: 80, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 140, y: 80, label: nil)],
            decorations: decorations,
            signing: nil, notarization: nil, sparkle: nil)
    }

    private func generated() -> LutinConfig.BackgroundInfo {
        .init(type: "generated", template: "blueprint", path: nil, scale: 2,
              colorA: "#EEF4FF", colorB: "#DDE8FF", grid: true, noise: 0.03,
              cornerRadius: 24)
    }

    private func pngSize(_ url: URL) -> (w: Int, h: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return (img.width, img.height)
    }

    func testRendersGeneratedBackgroundAtWindowTimesScale() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = try LutinRenderer.renderBackground(
            config: config(background: generated(), decorations: nil),
            projectDirectory: dir)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(pngSize(url)?.w, 400)        // 200 * 2
        XCTAssertEqual(pngSize(url)?.h, 240)        // 120 * 2
    }

    func testRendersWithAnArrowDecoration() throws {
        let dir = FileManager.default.temporaryDirectory
        let decorations = [LutinConfig.Decoration(
            type: "arrow", from: "app", to: "applications", label: "Drag to install")]
        let url = try LutinRenderer.renderBackground(
            config: config(background: generated(), decorations: decorations),
            projectDirectory: dir)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNotNil(pngSize(url))
    }

    func testMissingDecorationImageSurfacesTypedError() {
        let dir = FileManager.default.temporaryDirectory
        let decorations = [LutinConfig.Decoration(
            type: "image", path: "nope/missing.png", x: 80, y: 60, width: 40)]
        XCTAssertThrowsError(try LutinRenderer.renderBackground(
            config: config(background: generated(), decorations: decorations),
            projectDirectory: dir)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "decoration_image_not_found")
        }
    }
}
