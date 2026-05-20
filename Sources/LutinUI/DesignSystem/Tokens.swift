import SwiftUI

/// One indirection between views and the asset catalog so renames are mechanical
/// and dark/light contrast can be unit-tested. Views read `Tokens.color(.x)`.
public enum Tokens {
    public enum ColorToken: String {
        case brandAccent = "BrandAccent"
        case brandAccentSubtle = "BrandAccentSubtle"
        case surface = "Surface"
        case surfaceElevated = "SurfaceElevated"
        case divider = "Divider"
        case canvasBackground = "CanvasBackground"
        case itemSelected = "ItemSelected"
        case arrowDefault = "ArrowDefault"
        case arrowSelected = "ArrowSelected"
        case alignmentGuide = "AlignmentGuide"
        case gridLine = "GridLine"
        case logStdout = "LogStdout"
        case logStderr = "LogStderr"
        case logProgress = "LogProgress"
        case logSuccess = "LogSuccess"
        case logError = "LogError"
    }

    public static func color(_ token: ColorToken) -> Color {
        Color(token.rawValue, bundle: .module)
    }

    public enum Spacing: CGFloat { case xs = 2, sm = 4, md = 8, lg = 16, xl = 24 }
    public static func spacing(_ s: Spacing) -> CGFloat { s.rawValue }

    public enum Radius: CGFloat { case button = 8, surface = 12, window = 16 }
    public static func radius(_ r: Radius) -> CGFloat { r.rawValue }
}
