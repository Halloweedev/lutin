import Foundation
import CoreGraphics
import ImageIO
import LutinCore

/// A renderer-local decoration. `LutinRenderer` builds these from config
/// so the compositor never depends on `LutinConfig`. Drawn arrows were
/// dropped — the only decoration is a user-supplied overlay image.
enum RenderDecoration {
    case image(url: URL, x: Int, y: Int, widthPoints: Int?)
}

/// Bakes decorations onto a base image.
struct DecorationCompositor {
    /// - Parameters:
    ///   - base: the rendered background.
    ///   - decorations: image overlays, in draw order.
    ///   - iconSizePoints: icon edge length, reserved for future overlap
    ///     math against icons (kept for ABI parity).
    ///   - scale: points-to-pixels multiplier.
    func composite(base: CGImage, decorations: [RenderDecoration],
                   iconSizePoints: Int, scale: Int) throws -> CGImage {
        _ = iconSizePoints
        if decorations.isEmpty { return base }
        let s = CGFloat(max(1, scale))
        let w = base.width, h = base.height
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cg = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw LutinError(code: "render_failed",
                             message: "Could not create a \(w)x\(h) composite surface.")
        }
        // Bottom-up CGContext: y=0 at the bottom. drawImage positions a
        // rect whose origin is its bottom-left corner, so it computes
        // rectY = h - y*scale - drawH to land the image at top-left
        // y = y*scale (the config convention).
        cg.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h))

        for decoration in decorations {
            switch decoration {
            case let .image(url, x, y, widthPoints):
                try drawImage(in: cg, imageHeight: h, url: url, x: x, y: y,
                              widthPoints: widthPoints, scale: s)
            }
        }
        guard let result = cg.makeImage() else {
            throw LutinError(code: "render_failed", message: "Could not snapshot composite.")
        }
        return result
    }

    private func drawImage(in cg: CGContext, imageHeight: Int, url: URL, x: Int, y: Int,
                           widthPoints: Int?, scale: CGFloat) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LutinError(code: "decoration_image_not_found",
                             message: "Decoration image not found at path: \(url.path)",
                             details: ["path": url.path])
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LutinError(code: "render_failed",
                             message: "Could not decode decoration image at \(url.path).")
        }
        let drawW: CGFloat
        let drawH: CGFloat
        if let wp = widthPoints {
            drawW = CGFloat(wp) * scale
            drawH = drawW * CGFloat(image.height) / CGFloat(max(1, image.width))
        } else {
            drawW = CGFloat(image.width)
            drawH = CGFloat(image.height)
        }
        // x/y are window points with top-left origin.
        // In a bottom-up CGContext, the draw rect's origin y is measured from the bottom.
        let rectX = CGFloat(x) * scale
        let rectY = CGFloat(imageHeight) - CGFloat(y) * scale - drawH
        let rect = CGRect(x: rectX, y: rectY, width: drawW, height: drawH)
        cg.draw(image, in: rect)
    }
}
