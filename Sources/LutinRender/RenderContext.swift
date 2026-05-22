import Foundation
import CoreGraphics
import ImageIO
import LutinCore

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// An sRGB bitmap drawing surface with a top-left origin, so callers draw in
/// the same coordinate space as `lutin.yml` `x`/`y` values.
final class RenderContext {
    let cg: CGContext

    /// - Throws: `LutinError(code: "render_failed")` if the bitmap cannot be created.
    init(pixelWidth: Int, pixelHeight: Int) throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                data: nil, width: pixelWidth, height: pixelHeight,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw LutinError(
                code: "render_failed",
                message: "Could not create a \(pixelWidth)x\(pixelHeight) drawing surface.")
        }
        // Flip to a top-left origin so drawing matches config coordinates.
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: 1, y: -1)
        self.cg = context
    }

    /// Snapshots the current bitmap as a `CGImage`.
    func finish() -> CGImage {
        // CGContext.makeImage cannot fail for a context we created above.
        return cg.makeImage()!
    }

    /// Encodes a `CGImage` to a PNG file.
    ///
    /// - Parameters:
    ///   - image: the bitmap to encode.
    ///   - url: destination path.
    ///   - dpi: DPI to record in the PNG metadata. Finder reads this to map
    ///     pixel dimensions back to window points: a 1360×840 px PNG at 144 DPI
    ///     is interpreted as 680×420 pt (the @2× Retina case). A `nil`
    ///     properties dict on `CGImageDestinationAddImage` defaults to 72 DPI,
    ///     which would make Finder render the background at twice the window
    ///     size.  Callers rendering at `scale: N` should pass `72 * N`.
    /// - Throws: `LutinError(code: "render_failed")` on an encoding failure.
    static func writePNG(_ image: CGImage, to url: URL, dpi: CGFloat = 72) throws {
        let type: CFString
        #if canImport(UniformTypeIdentifiers)
        type = UTType.png.identifier as CFString
        #else
        type = "public.png" as CFString
        #endif
        guard let dest = CGImageDestinationCreateWithURL(
                url as CFURL, type, 1, nil) else {
            throw LutinError(code: "render_failed",
                             message: "Could not create a PNG file at \(url.path).")
        }
        let properties: CFDictionary = [
            kCGImagePropertyDPIWidth as String: dpi,
            kCGImagePropertyDPIHeight as String: dpi,
        ] as CFDictionary
        CGImageDestinationAddImage(dest, image, properties)
        guard CGImageDestinationFinalize(dest) else {
            throw LutinError(code: "render_failed",
                             message: "Could not encode the rendered PNG at \(url.path).")
        }
    }
}
