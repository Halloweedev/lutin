import SwiftUI
import LutinAppKit

/// Square app-icon tile with two render paths:
///   • If the `.app` is reachable, show its real Finder icon (loaded via
///     `AppIconLoader.appBundleIcon`).
///   • Otherwise, show a deterministic gradient + first-letter glyph.
///
/// Used by both the Welcome recents grid card (44pt) and the Project
/// Switcher modal row (28pt). Callers control size; the view picks an
/// appropriate backing-pixel request (`sizePoints * 2` for Retina) and
/// glyph font scale.
struct ProjectIconTile: View {
    let name: String
    let appPath: String
    /// Edge length in points. Backing icon load asks for `sizePoints * 2`.
    let sizePoints: CGFloat

    @State private var appIcon: CGImage?

    var body: some View {
        Group {
            if let appIcon {
                // CGImage carries no scale; tell SwiftUI it's @2x so the
                // Retina request renders crisp without re-resampling.
                // No shadow on this branch — macOS app icons bake their own depth in.
                Image(decorative: appIcon, scale: 2, orientation: .up)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: sizePoints, height: sizePoints)
            } else {
                placeholder
            }
        }
        .task(id: appPath) {
            let url = URL(fileURLWithPath: appPath)
            appIcon = AppIconLoader.appBundleIcon(
                at: url, sizePoints: Int(sizePoints * 2))
        }
    }

    private var placeholder: some View {
        ZStack {
            // 0.22 × size and 0.42 × size are tuned at 44pt (≈10pt corner, ≈18pt glyph)
            // so the placeholder reads as a macOS app-icon tile at any size.
            RoundedRectangle(cornerRadius: sizePoints * 0.22,
                             style: .continuous)
                .fill(Self.gradient(for: name))
                .frame(width: sizePoints, height: sizePoints)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: sizePoints * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    /// Deterministic gradient palette keyed by the project name's first
    /// character. Keeps the grid visually varied without requiring the
    /// real .app icon (which isn't always available).
    static func gradient(for name: String) -> LinearGradient {
        let palette: [(Color, Color)] = [
            (Color(red: 0.77, green: 0.37, blue: 0.16), Color(red: 0.43, green: 0.23, blue: 0.10)), // orange
            (Color(red: 0.29, green: 0.48, blue: 0.72), Color(red: 0.16, green: 0.29, blue: 0.47)), // blue
            (Color(red: 0.44, green: 0.58, blue: 0.33), Color(red: 0.25, green: 0.33, blue: 0.19)), // green
            (Color(red: 0.72, green: 0.53, blue: 0.29), Color(red: 0.48, green: 0.35, blue: 0.16)), // amber
        ]
        let key = Int(name.unicodeScalars.first?.value ?? 0)
        let pick = palette[abs(key) % palette.count]
        return LinearGradient(colors: [pick.0, pick.1],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}
