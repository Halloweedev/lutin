import Foundation
import CoreGraphics
import ImageIO
import LutinCore
import LutinConfig

/// The public entry point for rendering. Maps a `LutinConfig` onto the renderer
/// primitives, produces the finished `.background/background.png` content, and
/// returns the URL of the written PNG in a temporary work file.
public enum LutinRenderer {
    /// Renders the background (and bakes decorations) for `config`.
    ///
    /// - Parameters:
    ///   - config: a config already passed through `Templates.applyDefaults`,
    ///     so `window` and `background` fields are populated.
    ///   - projectDirectory: base for resolving relative image paths.
    ///   - onOutput: optional sink for non-fatal warnings (size mismatches).
    /// - Returns: the URL of a freshly written PNG.
    /// - Throws: `LutinError` with code `render_failed` or
    ///   `decoration_image_not_found`.
    public static func renderBackground(config: LutinConfig,
                                        projectDirectory: URL,
                                        onOutput: ((String) -> Void)? = nil) throws -> URL {
        let window = config.window
        let widthPoints = window?.width ?? 680
        let heightPoints = window?.height ?? 420
        let iconSize = window?.iconSize ?? 96
        let bg = config.background
        let scale = max(1, bg?.scale ?? 2)

        let kind: BackgroundSpec.Kind = (bg?.type == "image") ? .image : .generated
        var imageURL: URL?
        if kind == .image {
            guard let path = bg?.path, !path.isEmpty else {
                throw LutinError(
                    code: "render_failed",
                    message: "background.type is 'image' but background.path is not set.")
            }
            let resolved = URL(fileURLWithPath: path, relativeTo: projectDirectory)
                .standardizedFileURL
            imageURL = resolved
            warnIfWrongSize(resolved, expectedW: widthPoints * scale,
                            expectedH: heightPoints * scale, onOutput: onOutput)
        }

        let spec = BackgroundSpec(
            kind: kind, widthPoints: widthPoints, heightPoints: heightPoints, scale: scale,
            colorA: bg?.colorA ?? "#EEF4FF", colorB: bg?.colorB ?? "#DDE8FF",
            grid: bg?.grid ?? false, noise: bg?.noise ?? 0,
            cornerRadius: bg?.cornerRadius ?? 0, imageURL: imageURL)

        let base = try BackgroundRenderer().renderBase(spec)
        let decorations = try resolveDecorations(config: config,
                                                 projectDirectory: projectDirectory)
        let final = try DecorationCompositor().composite(
            base: base, decorations: decorations, iconSizePoints: iconSize, scale: scale)

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-render-\(UUID().uuidString).png")
        try RenderContext.writePNG(final, to: outURL)
        return outURL
    }

    /// Maps config `decorations` onto renderer-local `RenderDecoration` values.
    private static func resolveDecorations(config: LutinConfig,
                                           projectDirectory: URL) throws -> [RenderDecoration] {
        let items = config.items ?? []
        func point(forItemId id: String?) -> RenderPoint? {
            guard let id, let item = items.first(where: { $0.id == id }) else { return nil }
            return RenderPoint(x: item.x, y: item.y)
        }
        var result: [RenderDecoration] = []
        for decoration in config.decorations ?? [] {
            switch decoration.type {
            case "arrow":
                guard let from = point(forItemId: decoration.from),
                      let to = point(forItemId: decoration.to) else {
                    throw LutinError(
                        code: "render_failed",
                        message: "An arrow decoration references an item id that "
                               + "is not in `items`.")
                }
                result.append(.arrow(from: from, to: to, label: decoration.label))
            case "image":
                guard let path = decoration.path, !path.isEmpty,
                      let x = decoration.x, let y = decoration.y else {
                    throw LutinError(
                        code: "render_failed",
                        message: "An image decoration is missing `path`, `x`, or `y`.")
                }
                let url = URL(fileURLWithPath: path, relativeTo: projectDirectory)
                    .standardizedFileURL
                result.append(.image(url: url, x: x, y: y, widthPoints: decoration.width))
            default:
                throw LutinError(
                    code: "render_failed",
                    message: "Unknown decoration type '\(decoration.type)'.")
            }
        }
        return result
    }

    /// Emits a non-fatal warning if a user image's pixel size differs from the
    /// recommended `window × scale`.
    private static func warnIfWrongSize(_ url: URL, expectedW: Int, expectedH: Int,
                                        onOutput: ((String) -> Void)?) {
        guard let onOutput,
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
        if image.width != expectedW || image.height != expectedH {
            onOutput("Warning: background image is \(image.width)x\(image.height)px; "
                   + "recommended is \(expectedW)x\(expectedH)px. It will be scaled to fit.")
        }
    }
}
