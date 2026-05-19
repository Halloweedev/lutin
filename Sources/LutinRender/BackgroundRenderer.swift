import Foundation
import CoreGraphics
import LutinCore

/// A fully-resolved description of the background to render. The caller
/// (`LutinRenderer`) builds this from `LutinConfig`; the renderer never reads
/// config types directly, so it stays independently testable.
struct BackgroundSpec {
    enum Kind { case generated, image }
    let kind: Kind
    let widthPoints: Int
    let heightPoints: Int
    let scale: Int
    let colorA: String
    let colorB: String
    let grid: Bool
    let noise: Double
    let cornerRadius: Int
    /// For `.image`: the resolved on-disk URL of the user's background image.
    let imageURL: URL?

    var pixelWidth: Int { widthPoints * max(1, scale) }
    var pixelHeight: Int { heightPoints * max(1, scale) }
}

/// Draws the base background layer — gradient (this task), with grid/noise/
/// corners (Task 6) and the user-image case (Task 7) layered in later.
struct BackgroundRenderer {
    func renderBase(_ spec: BackgroundSpec) throws -> CGImage {
        switch spec.kind {
        case .generated:
            return try renderGenerated(spec)
        case .image:
            return try renderImage(spec)
        }
    }

    private func renderGenerated(_ spec: BackgroundSpec) throws -> CGImage {
        guard let colorA = RenderColor.parse(spec.colorA) else {
            throw LutinError(code: "render_failed",
                             message: "background.colorA is not a valid #RRGGBB colour: '\(spec.colorA)'.")
        }
        guard let colorB = RenderColor.parse(spec.colorB) else {
            throw LutinError(code: "render_failed",
                             message: "background.colorB is not a valid #RRGGBB colour: '\(spec.colorB)'.")
        }
        let ctx = try RenderContext(pixelWidth: spec.pixelWidth, pixelHeight: spec.pixelHeight)
        drawGradient(in: ctx, from: colorA, to: colorB)
        return ctx.finish()
    }

    /// Replaced in Task 7 with real user-image loading.
    private func renderImage(_ spec: BackgroundSpec) throws -> CGImage {
        throw LutinError(code: "render_failed",
                         message: "Image backgrounds are implemented in a later task.")
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
    func drawGradient(in ctx: RenderContext, from colorA: RenderColor, to colorB: RenderColor) {
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
