import CoreGraphics
import LutinConfig

/// Geometry helpers for arrows. Mirrors `DecorationCompositor` so what the
/// canvas shows equals what gets baked into the rendered PNG.
public enum ArrowRouting {
    public struct Route: Equatable {
        public let start: CGPoint
        public let end: CGPoint
    }

    public static func route(from src: String, to dst: String,
                             items: [LutinConfig.Item], iconSize: Int) -> Route? {
        guard let a = items.first(where: { $0.id == src }),
              let b = items.first(where: { $0.id == dst }) else { return nil }
        let half = CGFloat(iconSize) / 2.0
        let start = CGPoint(x: CGFloat(a.x) + half, y: CGFloat(a.y) + half)
        let end   = CGPoint(x: CGFloat(b.x) + half, y: CGFloat(b.y) + half)
        return Route(start: start, end: end)
    }
}
