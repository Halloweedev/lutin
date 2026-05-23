import XCTest
import CoreGraphics
import LutinCore
import LutinConfig
@testable import LutinRender

final class BackgroundGradientTests: XCTestCase {
    /// Samples a pixel in top-left coordinates (y measured from the top edge).
    private func sample(_ image: CGImage, x: Int, y: Int) -> (r: Double, g: Double, b: Double) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: image.width, height: image.height,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = ctx.data!.assumingMemoryBound(to: UInt8.self)
        // Bitmap memory row 0 is the bottom; flip so `y` is measured from the top.
        let offset = ((image.height - 1 - y) * ctx.bytesPerRow) + (x * 4)
        return (Double(pixels[offset]) / 255.0,
                Double(pixels[offset + 1]) / 255.0,
                Double(pixels[offset + 2]) / 255.0)
    }

    func testGradientBackgroundHasPixelSizeWindowTimesScale() throws {
        let spec = BackgroundSpec(
            kind: .gradient, widthPoints: 200, heightPoints: 100, scale: 2,
            colorA: "#FF0000", colorB: "#0000FF", grid: false, noise: 0,
            cornerRadius: 0, imageURL: nil)
        let image = try BackgroundRenderer().renderBase(spec)
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 200)
    }

    func testGradientRunsFromColorAToColorB() throws {
        // Pure-red to pure-blue, top-left to bottom-right, no grid/noise/corners.
        let spec = BackgroundSpec(
            kind: .gradient, widthPoints: 100, heightPoints: 100, scale: 1,
            colorA: "#FF0000", colorB: "#0000FF", grid: false, noise: 0,
            cornerRadius: 0, imageURL: nil)
        let image = try BackgroundRenderer().renderBase(spec)
        let topLeft = sample(image, x: 2, y: 2)
        let bottomRight = sample(image, x: 97, y: 97)
        XCTAssertGreaterThan(topLeft.r, 0.7)        // near red
        XCTAssertLessThan(topLeft.b, 0.3)
        XCTAssertGreaterThan(bottomRight.b, 0.7)    // near blue
        XCTAssertLessThan(bottomRight.r, 0.3)
    }

    func testMalformedColorThrowsRenderFailed() {
        let spec = BackgroundSpec(
            kind: .gradient, widthPoints: 50, heightPoints: 50, scale: 1,
            colorA: "not-a-color", colorB: "#000000", grid: false, noise: 0,
            cornerRadius: 0, imageURL: nil)
        XCTAssertThrowsError(try BackgroundRenderer().renderBase(spec)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "render_failed")
        }
    }

    func testMalformedColorBThrowsRenderFailed() {
        let spec = BackgroundSpec(
            kind: .gradient, widthPoints: 50, heightPoints: 50, scale: 1,
            colorA: "#FF0000", colorB: "not-a-color", grid: false, noise: 0,
            cornerRadius: 0, imageURL: nil)
        XCTAssertThrowsError(try BackgroundRenderer().renderBase(spec)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "render_failed")
        }
    }
}
