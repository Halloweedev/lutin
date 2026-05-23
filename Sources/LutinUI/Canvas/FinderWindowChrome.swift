import SwiftUI
import LutinCore

/// Wraps the canvas content in chrome that mimics a mounted DMG's Finder
/// window: title bar with traffic lights + volume name on top, and the
/// always-on volume strip Finder adds at the bottom of macOS 26 Tahoe.
///
/// The chrome heights are sourced from `LutinCore.FinderChrome` so the
/// editor preview stays in lock-step with what `lutin build` writes to
/// the `.DS_Store` `WindowBounds`.
public struct FinderWindowChrome<Content: View>: View {
    let title: String
    let contentSize: CGSize
    let content: Content

    public init(title: String,
                contentSize: CGSize,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.contentSize = contentSize
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            titleBar
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: 1)
            content
                .frame(width: contentSize.width, height: contentSize.height)
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: 1)
            volumeStrip
        }
        .background(Tokens.color(.toolbarBackground))
        .overlay(
            // Hairline outer border — defines the window edges.
            Rectangle().stroke(Tokens.color(.divider), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        .allowsHitTesting(true)
    }

    /// macOS Finder title bar: traffic lights flush-left, centered title,
    /// minimal vertical inset. Total height matches FinderChrome.title-
    /// BarHeightPoints so the canvas-below has exactly the same vertical
    /// budget the built DMG will have.
    private var titleBar: some View {
        ZStack {
            HStack(spacing: 8) {
                trafficLight(color: Color(red: 1.00, green: 0.36, blue: 0.36))
                trafficLight(color: Color(red: 1.00, green: 0.74, blue: 0.18))
                trafficLight(color: Color(red: 0.32, green: 0.78, blue: 0.30))
                Spacer()
            }
            .padding(.leading, 12)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.color(.textPrimary))
        }
        .frame(height: CGFloat(FinderChrome.titleBarHeightPoints))
        .background(Tokens.color(.toolbarBackground))
    }

    private func trafficLight(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
    }

    /// macOS 26 Tahoe always-on volume strip — a slim band at the bottom
    /// of the window. Renders the volume name centered, matching what the
    /// DMG will show when mounted.
    private var volumeStrip: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.color(.textSecondary))
            Spacer()
        }
        .frame(height: CGFloat(FinderChrome.bottomChromeHeightPoints))
        .background(Tokens.color(.toolbarBackground))
    }
}
