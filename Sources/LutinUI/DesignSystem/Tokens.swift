import SwiftUI
import AppKit

/// Design tokens. Every value resolves through the Asset Catalog so light
/// and dark modes are first-class. No materials, no inline gradients, no
/// translucency. Square corners by default — when a shape needs rounding
/// (e.g. an OS-drawn app icon), the call site uses `RoundedRectangle`
/// directly, not a token.
public enum Tokens {
    // MARK: - Token Keys (v2)

    /// Flat token key set. rawValue is the asset catalog color name.
    /// New keys use camelCase colorsets; legacy keys retain their existing
    /// PascalCase colorset names so the asset catalog entries are unchanged.
    public enum Key: String, CaseIterable, Sendable {
        // Surfaces — new v2 (camelCase colorsets)
        case panelBackground
        case railBackground
        case toolbarBackground
        case sheetBackground

        // Strokes — new v2 (camelCase colorsets)
        case marqueeStroke
        case offCanvasOutline

        // Text — new v2 (camelCase colorsets)
        case textPrimary
        case textSecondary
        case textTertiary
        case textOnAccent

        // Accent — new v2 (camelCase colorsets)
        case brandAccentMuted

        // Interaction — new v2 (camelCase colorsets).
        // Pure-grey hover fill used by `LutinIconButton` and `LutinToggle`.
        // Decoupled from `surfaceElevated` once the chrome surfaces went
        // pure white — surfaceElevated meant "white above grey panel", which
        // gave invisible hover affordance against a white panel.
        case controlHoverFill

        // ── Legacy keys — rawValue maps to existing PascalCase colorsets ─────

        // Surfaces
        case canvasBackground  = "CanvasBackground"
        case surface           = "Surface"
        case surfaceElevated   = "SurfaceElevated"

        // Strokes / overlays
        case divider           = "Divider"
        case itemSelected      = "ItemSelected"
        case alignmentGuide    = "AlignmentGuide"
        /// Magenta used by the Option-key measurement overlay
        /// (`MeasurementGuides`). Distinct from `alignmentGuide`
        /// (blue) so the two overlays never compete visually when
        /// they appear in the same frame.
        case measurementGuide  = "MeasurementGuide"
        case gridLine          = "GridLine"

        // Accent
        case brandAccent       = "BrandAccent"
        case brandAccentSubtle = "BrandAccentSubtle"

        // Arrows
        case arrowDefault      = "ArrowDefault"
        case arrowSelected     = "ArrowSelected"

        // Log / status
        case logError          = "LogError"
        case logSuccess        = "LogSuccess"
        case logProgress       = "LogProgress"
        case logStdout         = "LogStdout"
        case logStderr         = "LogStderr"
    }

    // MARK: - Color resolution

    public static func color(_ key: Key) -> Color {
        // Route every SwiftUI Color lookup through a dynamic NSColor so the
        // JSON-fallback path in `nsColor(_:appearance:)` is honored when the
        // asset catalog isn't compiled (SPM debug builds copy .xcassets
        // verbatim instead of emitting a .car). The dynamicProvider closure
        // re-resolves on appearance change so light/dark transitions still
        // animate without a relaunch.
        Color(nsColor: NSColor(name: NSColor.Name(key.rawValue),
                                dynamicProvider: { appearance in
            nsColor(key, appearance: appearance)
        }))
    }

    /// Resolves a token to a concrete NSColor for the given appearance.
    ///
    /// In production (compiled `.car` catalog) this uses `NSColor(named:bundle:)`.
    /// In SwiftPM test bundles (uncompiled `.xcassets` directory) it falls back
    /// to parsing `Contents.json` directly, so the parity test works in both
    /// environments.
    public static func nsColor(_ key: Key, appearance: NSAppearance) -> NSColor {
        let isDark = appearance.name == .darkAqua
            || appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Fast path: compiled asset catalog (app bundle / Xcode tests).
        var namedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            namedColor = NSColor(named: key.rawValue, bundle: .module)
        }
        if let nc = namedColor,
           let resolved = nc.usingColorSpace(.sRGB) {
            return resolved
        }

        // Slow path: uncompiled xcassets directory (SwiftPM `swift test`).
        return nsColorFromColorset(named: key.rawValue, dark: isDark)
    }

    // MARK: - Spacing (unchanged — existing tests rely on these raw values)

    /// Spacing scale. Bumped from {2, 4, 8, 16, 24} in 2026-05-23 — the old
    /// tighter values made form rows feel cramped and section gutters
    /// disappear. The new scale leans roomier so chrome surfaces breathe
    /// without needing per-site overrides.
    public enum Spacing: CGFloat { case xs = 4, sm = 8, md = 14, lg = 20, xl = 32 }
    public static func spacing(_ s: Spacing) -> CGFloat { s.rawValue }

    // MARK: - Darken (state-machine math)

    /// Returns a copy of `color` with each sRGB component reduced by `ratio`.
    /// Clamps each component at 0; preserves alpha. Used by every interactive
    /// control's hover/press/focus state.
    public static func darken(_ color: NSColor, by ratio: Double) -> NSColor {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = max(0, srgb.redComponent - CGFloat(ratio))
        let g = max(0, srgb.greenComponent - CGFloat(ratio))
        let b = max(0, srgb.blueComponent - CGFloat(ratio))
        return NSColor(srgbRed: r, green: g, blue: b, alpha: srgb.alphaComponent)
    }

    // MARK: - Sizes (v2)

    public enum Size {
        public static let railWidth: CGFloat = 44
        public static let sidePanelDefault: CGFloat = 280
        public static let sidePanelMin: CGFloat = 240
        public static let sidePanelMax: CGFloat = 360
        public static let hairline: CGFloat = 1
        /// Minimum hit-target height for any chrome control. Matches the
        /// existing `LutinIconButton` frame and aligns with macOS HIG
        /// pointer-control guidance. Applied via `.lutinHitTarget()` —
        /// see `View+LutinHitTarget.swift`.
        public static let controlHeight: CGFloat = 28
    }
}

// MARK: - Colorset JSON parsing (SwiftPM slow path)

private func nsColorFromColorset(named name: String, dark: Bool) -> NSColor {
    guard let url = colorsetURL(named: name) else { return .clear }
    guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents.json")),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let colors = json["colors"] as? [[String: Any]] else { return .clear }

    // The dark entry has an "appearances" array; the light entry does not.
    var lightEntry: [String: Any]?
    var darkEntry: [String: Any]?
    for entry in colors {
        let hasAppearances = (entry["appearances"] as? [[String: Any]])?.isEmpty == false
        if hasAppearances { darkEntry = entry } else { lightEntry = entry }
    }

    let entry = dark ? (darkEntry ?? lightEntry) : lightEntry
    return nsColor(fromEntry: entry) ?? .clear
}

private func colorsetURL(named name: String) -> URL? {
    let bundle = Bundle.module
    let colorsetName = "\(name).colorset"
    // SwiftPM copies the whole .xcassets directory into the bundle.
    // Try the nested path first, then a flat resource lookup.
    if let url = bundle.url(forResource: colorsetName, withExtension: nil,
                            subdirectory: "Assets.xcassets") {
        return url
    }
    if let url = bundle.url(forResource: name, withExtension: "colorset",
                            subdirectory: "Assets.xcassets") {
        return url
    }
    return nil
}

private func nsColor(fromEntry entry: [String: Any]?) -> NSColor? {
    guard let color = entry?["color"] as? [String: Any],
          let components = color["components"] as? [String: Any] else { return nil }
    let r = Double(components["red"] as? String ?? "") ?? 0
    let g = Double(components["green"] as? String ?? "") ?? 0
    let b = Double(components["blue"] as? String ?? "") ?? 0
    let a = Double(components["alpha"] as? String ?? "") ?? 1
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
