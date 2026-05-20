import CoreGraphics
import LutinConfig

/// Geometry helpers for arrows. Mirrors `DecorationCompositor` so what the
/// canvas shows equals what gets baked into the rendered PNG.
///
/// `LutinConfig.Item.x/y` are icon-CENTER coordinates in window points
/// (matches the convention `DMGLayout` writes to `.DS_Store` and the
/// renderer's `RenderPoint(x: item.x, y: item.y)`). Arrows therefore route
/// center-to-center; the visible stroke is inset past the icon edge by the
/// shape that draws it (see `ArrowLayer.ArrowShape`).
public enum ArrowRouting {
    public struct Route: Equatable {
        public let start: CGPoint
        public let end: CGPoint
    }

    public static func route(from src: String, to dst: String,
                             items: [LutinConfig.Item], iconSize: Int) -> Route? {
        guard let a = items.first(where: { $0.id == src }),
              let b = items.first(where: { $0.id == dst }) else { return nil }
        // `iconSize` is reserved for future inset/clipping math (we still need
        // it to keep the stroke from poking into the icon glyph), so the
        // parameter is preserved but unused at this layer.
        _ = iconSize
        let start = CGPoint(x: CGFloat(a.x), y: CGFloat(a.y))
        let end   = CGPoint(x: CGFloat(b.x), y: CGFloat(b.y))
        return Route(start: start, end: end)
    }
}
