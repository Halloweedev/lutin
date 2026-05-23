import Foundation
import CoreGraphics
import ImageIO
import LutinCore

/// A fully-resolved description of the background to render. The caller
/// (`LutinRenderer`) builds this from `LutinConfig`; the renderer never reads
/// config types directly, so it stays independently testable.
struct BackgroundSpec {
    /// The three supported background variants. Legacy `"generated"` configs
    /// are treated as `.solid` by `LutinRenderer` — no grid, no pattern.
    enum Kind { case solid, gradient, image }
    let kind: Kind
    let widthPoints: Int
    let heightPoints: Int
    let scale: Int
    let colorA: String
    let colorB: String
    let grid: Bool  // reserved for future image-overlay use; not applied to solid/gradient
    let noise: Double
    let cornerRadius: Int
    /// For `.image`: the resolved on-disk URL of the user's background image.
    let imageURL: URL?

    var pixelWidth: Int { widthPoints * max(1, scale) }
    var pixelHeight: Int { heightPoints * max(1, scale) }
}

/// Draws the base background layer: solid fill or gradient, optional noise,
/// corner rounding, and the user-supplied background image.
struct BackgroundRenderer {
    func renderBase(_ spec: BackgroundSpec) throws -> CGImage {
        switch spec.kind {
        case .solid:
            return try renderSolid(spec)
        case .gradient:
            return try renderGradient(spec)
        case .image:
            return try renderImage(spec)
        }
    }

    /// Fills the canvas with `colorA` — a flat solid colour. Applies corner
    /// radius and optional noise. No grid, no gradient.
    private func renderSolid(_ spec: BackgroundSpec) throws -> CGImage {
        guard let colorA = RenderColor.parse(spec.colorA) else {
            throw LutinError(code: "render_failed",
                             message: "background.colorA is not a valid #RRGGBB colour: '\(spec.colorA)'.")
        }
        let ctx = try RenderContext(pixelWidth: spec.pixelWidth, pixelHeight: spec.pixelHeight)
        let scale = CGFloat(max(1, spec.scale))
        let radius = CGFloat(spec.cornerRadius) * scale

        if radius > 0 {
            ctx.cg.setFillColor(colorA.withAlpha(1).cgColor)
            ctx.cg.fill(CGRect(x: 0, y: 0, width: ctx.cg.width, height: ctx.cg.height))
            let margin = 14 * scale
            let panel = CGRect(x: margin, y: margin,
                               width: CGFloat(ctx.cg.width) - 2 * margin,
                               height: CGFloat(ctx.cg.height) - 2 * margin)
            ctx.cg.saveGState()
            ctx.cg.addPath(CGPath(roundedRect: panel, cornerWidth: radius,
                                  cornerHeight: radius, transform: nil))
            ctx.cg.clip()
            ctx.cg.setFillColor(colorA.withAlpha(1).cgColor)
            ctx.cg.fill(CGRect(x: 0, y: 0, width: ctx.cg.width, height: ctx.cg.height))
            if spec.noise > 0 { drawNoise(in: ctx, intensity: spec.noise, scale: scale) }
            ctx.cg.restoreGState()
        } else {
            ctx.cg.setFillColor(colorA.withAlpha(1).cgColor)
            ctx.cg.fill(CGRect(x: 0, y: 0, width: ctx.cg.width, height: ctx.cg.height))
            if spec.noise > 0 { drawNoise(in: ctx, intensity: spec.noise, scale: scale) }
        }
        return ctx.finish()
    }

    /// Draws a linear gradient from `colorA` (top-left) to `colorB`
    /// (bottom-right), with optional corner radius and noise. No grid.
    private func renderGradient(_ spec: BackgroundSpec) throws -> CGImage {
        guard let colorA = RenderColor.parse(spec.colorA) else {
            throw LutinError(code: "render_failed",
                             message: "background.colorA is not a valid #RRGGBB colour: '\(spec.colorA)'.")
        }
        guard let colorB = RenderColor.parse(spec.colorB) else {
            throw LutinError(code: "render_failed",
                             message: "background.colorB is not a valid #RRGGBB colour: '\(spec.colorB)'.")
        }
        let ctx = try RenderContext(pixelWidth: spec.pixelWidth, pixelHeight: spec.pixelHeight)
        let scale = CGFloat(max(1, spec.scale))
        let radius = CGFloat(spec.cornerRadius) * scale

        if radius > 0 {
            // Backdrop fill, then a rounded-rect panel inset by a fixed margin.
            ctx.cg.setFillColor(colorA.withAlpha(1).cgColor)
            ctx.cg.fill(CGRect(x: 0, y: 0, width: ctx.cg.width, height: ctx.cg.height))
            let margin = 14 * scale
            let panel = CGRect(x: margin, y: margin,
                               width: CGFloat(ctx.cg.width) - 2 * margin,
                               height: CGFloat(ctx.cg.height) - 2 * margin)
            ctx.cg.saveGState()
            ctx.cg.addPath(CGPath(roundedRect: panel, cornerWidth: radius,
                                  cornerHeight: radius, transform: nil))
            ctx.cg.clip()
            drawLinearGradient(in: ctx, from: colorA, to: colorB)
            if spec.noise > 0 { drawNoise(in: ctx, intensity: spec.noise, scale: scale) }
            ctx.cg.restoreGState()
        } else {
            drawLinearGradient(in: ctx, from: colorA, to: colorB)
            if spec.noise > 0 { drawNoise(in: ctx, intensity: spec.noise, scale: scale) }
        }
        return ctx.finish()
    }

    /// A subtle, deterministic noise dither. `intensity` (0...1) scales how many
    /// faint specks are drawn. A fixed seed keeps renders reproducible.
    private func drawNoise(in ctx: RenderContext, intensity: Double, scale: CGFloat) {
        var rng = SeededRNG(seed: 0x6C7574696E)   // "lutin"
        let w = ctx.cg.width
        let h = ctx.cg.height
        let count = Int(Double(w * h) * min(0.5, max(0, intensity)) * 0.25)
        let dot = max(1, scale)
        for _ in 0..<count {
            let px = Int(rng.next() % UInt64(w))
            let py = Int(rng.next() % UInt64(h))
            let dark = (rng.next() & 1) == 0
            let v: CGFloat = dark ? 0 : 1
            ctx.cg.setFillColor(CGColor(srgbRed: v, green: v, blue: v, alpha: 0.05))
            ctx.cg.fill(CGRect(x: CGFloat(px), y: CGFloat(py), width: dot, height: dot))
        }
    }

    /// Loads the user's background image and cover-fits it to the canvas.
    private func renderImage(_ spec: BackgroundSpec) throws -> CGImage {
        guard let url = spec.imageURL,
              FileManager.default.fileExists(atPath: url.path) else {
            throw LutinError(
                code: "render_failed",
                message: "The background image could not be found at "
                       + "\(spec.imageURL?.path ?? "(no path)").")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let loaded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LutinError(code: "render_failed",
                             message: "The background image at \(url.path) could not be decoded.")
        }
        let ctx = try RenderContext(pixelWidth: spec.pixelWidth, pixelHeight: spec.pixelHeight)
        let canvasW = CGFloat(spec.pixelWidth)
        let canvasH = CGFloat(spec.pixelHeight)
        let imgW = CGFloat(loaded.width)
        let imgH = CGFloat(loaded.height)
        // Cover-fit: scale so the image fills the canvas, centred, excess cropped.
        let scale = max(canvasW / imgW, canvasH / imgH)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let rect = CGRect(x: (canvasW - drawW) / 2, y: (canvasH - drawH) / 2,
                          width: drawW, height: drawH)
        // RenderContext applies a y-flipped CTM so callers can think in
        // top-left coordinates. `CGContext.draw(image, in:)` lays out the
        // image with its bottom-left origin, which combined with the
        // flipped CTM renders the image upside-down. Locally invert the
        // flip around the draw so the image lands right-side-up.
        ctx.cg.saveGState()
        ctx.cg.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        ctx.cg.scaleBy(x: 1, y: -1)
        ctx.cg.draw(loaded, in: CGRect(origin: .zero, size: rect.size))
        ctx.cg.restoreGState()
        return ctx.finish()
    }

    /// Fills the whole context with a top-left → bottom-right linear gradient.
    ///
    /// `RenderContext` sets up a y-flipped CTM (top-left origin), so
    /// `drawLinearGradient` receives user-space coordinates where y increases
    /// downward but the underlying bitmap stores rows with y=0 at the bottom.
    /// To paint colorA at the visual top-left and colorB at the visual
    /// bottom-right we must convert: visual top-left is device (0, 0), which
    /// in the flipped user space is (0, h); visual bottom-right is device
    /// (w, h), which in user space is (w, 0).
    private func drawLinearGradient(in ctx: RenderContext, from colorA: RenderColor, to colorB: RenderColor) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [colorA.cgColor, colorB.cgColor] as CFArray,
            locations: [0, 1])!
        let w = CGFloat(ctx.cg.width)
        let h = CGFloat(ctx.cg.height)
        ctx.cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: h),   // visual top-left in flipped user space
            end: CGPoint(x: w, y: 0),     // visual bottom-right in flipped user space
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

/// A tiny deterministic PRNG (linear congruential) so noise renders are
/// byte-for-byte reproducible across runs.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
