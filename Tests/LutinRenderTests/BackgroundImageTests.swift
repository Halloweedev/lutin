import XCTest
import CoreGraphics
import LutinCore
@testable import LutinRender

final class BackgroundImageTests: XCTestCase {
    /// Writes a solid-colour PNG of the given pixel size and returns its URL.
    private func makePNG(width: Int, height: Int) throws -> URL {
        let ctx = try RenderContext(pixelWidth: width, pixelHeight: height)
        ctx.cg.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        ctx.cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-bgimg-\(UUID().uuidString).png")
        try RenderContext.writePNG(ctx.finish(), to: url)
        return url
    }

    func testImageBaseIsScaledToTheCanvasSize() throws {
        let src = try makePNG(width: 100, height: 100)
        defer { try? FileManager.default.removeItem(at: src) }
        let spec = BackgroundSpec(
            kind: .image, widthPoints: 200, heightPoints: 120, scale: 2,
            colorA: "#000000", colorB: "#000000", grid: false, noise: 0,
            cornerRadius: 0, imageURL: src)
        let image = try BackgroundRenderer().renderBase(spec)
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 240)
    }

    func testMissingImageThrowsRenderFailed() {
        let spec = BackgroundSpec(
            kind: .image, widthPoints: 100, heightPoints: 100, scale: 1,
            colorA: "#000000", colorB: "#000000", grid: false, noise: 0,
            cornerRadius: 0,
            imageURL: URL(fileURLWithPath: "/tmp/lutin-does-not-exist.png"))
        XCTAssertThrowsError(try BackgroundRenderer().renderBase(spec)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "render_failed")
        }
    }
}
