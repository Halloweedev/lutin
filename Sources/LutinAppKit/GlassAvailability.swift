import Foundation

/// One place that branches on macOS 26. Every view that needs glass reads
/// from `GlassStyle` in the environment instead of using `#available` itself.
public enum GlassAvailability {
    public static var supportsLiquidGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }
}
