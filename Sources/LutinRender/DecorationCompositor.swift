import Foundation
import CoreGraphics
import CoreText
import LutinCore

/// A point in window-point coordinates (top-left origin), as used by `lutin.yml`.
struct RenderPoint: Equatable {
    let x: Int
    let y: Int
}

/// A renderer-local decoration. `LutinRenderer` builds these from config so the
/// compositor never depends on `LutinConfig`.
enum RenderDecoration {
    /// An install arrow between two icon centres.
    case arrow(from: RenderPoint, to: RenderPoint, label: String?)
    /// A user-supplied overlay image at an absolute position.
    case image(url: URL, x: Int, y: Int, widthPoints: Int?)
}

/// Bakes decorations onto a base image.
struct DecorationCompositor {
    /// - Parameters:
    ///   - base: the rendered background.
    ///   - decorations: arrows and image overlays, in draw order.
    ///   - iconSizePoints: icon edge length, so arrows start clear of the icons.
    ///   - scale: points-to-pixels multiplier.
    func composite(base: CGImage, decorations: [RenderDecoration],
                   iconSizePoints: Int, scale: Int) throws -> CGImage {
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
        // This plain CGContext has y=0 at the bottom; decoration y-coordinates (RenderPoint.y * scale) map directly to bottom-up pixel rows.
        cg.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h))

        for decoration in decorations {
            switch decoration {
            case let .arrow(from, to, label):
                drawArrow(in: cg, from: from, to: to, label: label,
                          iconSizePoints: iconSizePoints, scale: s)
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

    private func drawArrow(in cg: CGContext,
                           from: RenderPoint, to: RenderPoint,
                           label: String?, iconSizePoints: Int, scale: CGFloat) {
        // Plain bottom-up CGContext: RenderPoint.y * scale maps directly to the pixel row; no flip needed.
        let p0 = CGPoint(x: CGFloat(from.x) * scale, y: CGFloat(from.y) * scale)
        let p1 = CGPoint(x: CGFloat(to.x) * scale, y: CGFloat(to.y) * scale)
        let dx = p1.x - p0.x, dy = p1.y - p0.y
        let length = max(1, hypot(dx, dy))
        let ux = dx / length, uy = dy / length
        // Inset both ends past the icon edge plus a small gap.
        let inset = (CGFloat(iconSizePoints) / 2 + 12) * scale
        let start = CGPoint(x: p0.x + ux * inset, y: p0.y + uy * inset)
        let end = CGPoint(x: p1.x - ux * inset, y: p1.y - uy * inset)
        let color = CGColor(srgbRed: 0.35, green: 0.47, blue: 0.78, alpha: 0.95)

        cg.setStrokeColor(color)
        cg.setLineWidth(3 * scale)
        cg.setLineCap(.round)
        cg.move(to: start)
        cg.addLine(to: end)
        cg.strokePath()

        // Solid triangular arrowhead at `end`.
        let head = 11 * scale
        let nx = -uy, ny = ux       // perpendicular
        cg.setFillColor(color)
        cg.move(to: end)
        cg.addLine(to: CGPoint(x: end.x - ux * head + nx * head * 0.6,
                               y: end.y - uy * head + ny * head * 0.6))
        cg.addLine(to: CGPoint(x: end.x - ux * head - nx * head * 0.6,
                               y: end.y - uy * head - ny * head * 0.6))
        cg.closePath()
        cg.fillPath()

        if let label, !label.isEmpty {
            let mid = CGPoint(x: (start.x + end.x) / 2,
                              y: (start.y + end.y) / 2 + 16 * scale)
            drawLabel(in: cg, text: label, centeredAt: mid, scale: scale, color: color)
        }
    }

    /// Draws centred text using Core Text (no AppKit dependency).
    private func drawLabel(in cg: CGContext, text: String, centeredAt: CGPoint,
                           scale: CGFloat, color: CGColor) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 13 * scale, nil)
        // CoreText attribute keys (no AppKit dependency).
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetImageBounds(line, cg)
        cg.saveGState()
        // Core Text draws in the current coordinate system (bottom-up).
        cg.textMatrix = .identity
        cg.textPosition = CGPoint(x: centeredAt.x - bounds.width / 2 - bounds.origin.x, y: centeredAt.y)
        CTLineDraw(line, cg)
        cg.restoreGState()
    }

    /// Implemented in Task 9.
    private func drawImage(in cg: CGContext, imageHeight: Int, url: URL, x: Int, y: Int,
                           widthPoints: Int?, scale: CGFloat) throws {
        throw LutinError(code: "render_failed",
                         message: "Image decorations are implemented in a later task.")
    }
}
