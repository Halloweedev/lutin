import XCTest
import CoreGraphics
import LutinCore
@testable import LutinRender

final class ArrowCompositorTests: XCTestCase {
    private func solidBase(width: Int, height: Int) throws -> CGImage {
        let ctx = try RenderContext(pixelWidth: width, pixelHeight: height)
        ctx.cg.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.finish()
    }

    /// True if any pixel in the rect is not pure white.
    private func hasMark(_ image: CGImage, in rect: CGRect) -> Bool {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: image.width, height: image.height,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                // Flip the row so `rect` is in top-left coordinates.
                let o = (image.height - 1 - y) * ctx.bytesPerRow + x * 4
                if p[o] < 250 || p[o + 1] < 250 || p[o + 2] < 250 { return true }
            }
        }
        return false
    }

    func testArrowDrawsBetweenTwoItems() throws {
        let base = try solidBase(width: 800, height: 300)
        let arrow = RenderDecoration.arrow(
            from: RenderPoint(x: 80, y: 100), to: RenderPoint(x: 320, y: 100),
            label: nil)
        let result = try DecorationCompositor().composite(
            base: base, decorations: [arrow], iconSizePoints: 96, scale: 2)
        // The arrow line spans pixels x≈280...520 at y≈200; check its mid-span.
        XCTAssertTrue(hasMark(result, in: CGRect(x: 380, y: 185, width: 40, height: 30)))
    }

    func testNoDecorationsLeavesTheBaseUnchanged() throws {
        let base = try solidBase(width: 100, height: 100)
        let result = try DecorationCompositor().composite(
            base: base, decorations: [], iconSizePoints: 96, scale: 1)
        XCTAssertFalse(hasMark(result, in: CGRect(x: 0, y: 0, width: 100, height: 100)))
    }

    func testArrowWithLabelDrawsMoreThanWithout() throws {
        let base = try solidBase(width: 800, height: 300)
        func marks(_ decoration: RenderDecoration) throws -> Int {
            let img = try DecorationCompositor().composite(
                base: base, decorations: [decoration], iconSizePoints: 96, scale: 2)
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            let c = CGContext(data: nil, width: img.width, height: img.height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
            let p = c.data!.assumingMemoryBound(to: UInt8.self)
            var n = 0
            for i in stride(from: 0, to: c.bytesPerRow * img.height, by: 4) where p[i] < 250 { n += 1 }
            return n
        }
        let plain = try marks(.arrow(from: RenderPoint(x: 80, y: 100),
                                     to: RenderPoint(x: 320, y: 100), label: nil))
        let labelled = try marks(.arrow(from: RenderPoint(x: 80, y: 100),
                                        to: RenderPoint(x: 320, y: 100), label: "Drag to install"))
        XCTAssertGreaterThan(labelled, plain)
    }
}
