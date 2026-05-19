import XCTest
import CoreGraphics
import LutinCore
@testable import LutinRender

final class ImageDecorationTests: XCTestCase {
    private func solidBase(width: Int, height: Int) throws -> CGImage {
        let ctx = try RenderContext(pixelWidth: width, pixelHeight: height)
        ctx.cg.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.finish()
    }

    private func redSquarePNG(side: Int) throws -> URL {
        let ctx = try RenderContext(pixelWidth: side, pixelHeight: side)
        ctx.cg.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        ctx.cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-deco-\(UUID().uuidString).png")
        try RenderContext.writePNG(ctx.finish(), to: url)
        return url
    }

    /// Samples a pixel in top-left coordinates (y measured from the top edge).
    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: image.width, height: image.height,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        // Flip the row so `y` is measured from the top edge.
        let o = (image.height - 1 - y) * ctx.bytesPerRow + x * 4
        return (Int(p[o]), Int(p[o + 1]), Int(p[o + 2]))
    }

    func testImageDecorationLandsAtItsPosition() throws {
        let base = try solidBase(width: 800, height: 300)
        let asset = try redSquarePNG(side: 40)
        defer { try? FileManager.default.removeItem(at: asset) }
        // Place a 40-point-wide square at (100,60); scale 2 → pixel rect (200,120) 80x80.
        let deco = RenderDecoration.image(url: asset, x: 100, y: 60, widthPoints: 40)
        let result = try DecorationCompositor().composite(
            base: base, decorations: [deco], iconSizePoints: 96, scale: 2)
        let inside = pixel(result, x: 220, y: 140)   // within the placed square
        XCTAssertGreaterThan(inside.r, 200)
        XCTAssertLessThan(inside.g, 80)
        let outside = pixel(result, x: 10, y: 10)    // untouched white
        XCTAssertGreaterThan(outside.g, 200)
    }

    func testMissingDecorationImageThrowsTypedError() throws {
        let base = try solidBase(width: 100, height: 100)
        let deco = RenderDecoration.image(
            url: URL(fileURLWithPath: "/tmp/lutin-no-such-overlay.png"),
            x: 10, y: 10, widthPoints: 20)
        XCTAssertThrowsError(try DecorationCompositor().composite(
            base: base, decorations: [deco], iconSizePoints: 96, scale: 1)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "decoration_image_not_found")
        }
    }
}
