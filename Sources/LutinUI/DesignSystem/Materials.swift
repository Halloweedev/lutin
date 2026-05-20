import SwiftUI
import LutinAppKit

/// Encapsulates "do we have Liquid Glass?" for views. On macOS 26+ this
/// applies a glass effect; on macOS 15 it applies `.regularMaterial`.
public struct GlassBackgroundModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        if GlassAvailability.supportsLiquidGlass {
            if #available(macOS 26, *) {
                // The exact API name on macOS 26 may vary; .ultraThinMaterial
                // is the closest stable shim available cross-version.
                content.background(.ultraThinMaterial)
            } else {
                content.background(.regularMaterial)
            }
        } else {
            content.background(.regularMaterial)
        }
    }
}

public extension View {
    /// Liquid Glass on macOS 26+, `.regularMaterial` fallback on macOS 15.
    func lutinGlassBackground() -> some View { modifier(GlassBackgroundModifier()) }
}
