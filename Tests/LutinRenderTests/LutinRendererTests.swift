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
        // legacy "generated" type — renderer treats it as solid (solid fallback)
        .init(type: "generated", template: nil, path: nil, scale: 2,
              colorA: "#EEF4FF", colorB: "#DDE8FF", grid: false, noise: 0,
              cornerRadius: 0)
    }

    private func pngSize(_ url: URL) -> (w: Int, h: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return (img.width, img.height)
    }

    // config.window.{width,height} is the content area — the canvas users
    // design against. The renderer must emit a PNG at exactly that size
    // (× scale for Retina) so Finder draws it 1:1. Growing the outer frame
    // for chrome is the builder's job, not the renderer's.
    func testRendersSolidBackgroundAtWindowDimsTimesScale() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = try LutinRenderer.renderBackground(
            config: config(background: generated(), decorations: nil),
            projectDirectory: dir)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(pngSize(url)?.w, 400)        // 200 * 2
        XCTAssertEqual(pngSize(url)?.h, 240)        // 120 * 2
    }

    /// Drawn arrows were removed; the renderer rejects `type: arrow`
    /// because the resolver only knows the `image` case now.
    func testArrowDecorationIsRejectedByRenderer() {
        let dir = FileManager.default.temporaryDirectory
        let decorations = [LutinConfig.Decoration(type: "arrow")]
        XCTAssertThrowsError(try LutinRenderer.renderBackground(
            config: config(background: generated(), decorations: decorations),
            projectDirectory: dir))
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
