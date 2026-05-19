import Foundation
import CoreGraphics

/// An sRGB colour with components in 0...1, parsed from a `#RRGGBB` hex string.
struct RenderColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// Parses `#RRGGBB` or `RRGGBB` (case-insensitive). Returns nil if malformed.
    static func parse(_ hex: String) -> RenderColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return RenderColor(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            alpha: 1.0)
    }

    /// An sRGB `CGColor` for this colour.
    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(red), green: CGFloat(green),
                blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    /// Returns a copy with a different alpha.
    func withAlpha(_ a: Double) -> RenderColor {
        RenderColor(red: red, green: green, blue: blue, alpha: a)
    }
}
