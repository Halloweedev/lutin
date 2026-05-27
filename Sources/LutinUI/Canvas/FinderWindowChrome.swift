import SwiftUI
import LutinCore
import LutinAppKit

/// Wraps the canvas content in chrome that mimics a mounted DMG's Finder
/// window: title bar with traffic lights + volume name on top, and the
/// always-on volume strip Finder adds at the bottom of macOS 26 Tahoe.
///
/// The chrome heights are sourced from `LutinCore.FinderChrome` so the
/// editor preview stays in lock-step with what `lutin build` writes to
/// the `.DS_Store` `WindowBounds`.
public struct FinderWindowChrome<Content: View>: View {
    let title: String
    /// Preferred source for the small volume-icon glyph. `volumeIconURL`
    /// wins over `appBundleURL` — mirrors `ReleasePipeline.resolveVolumeIcon`:
    /// real Finder prefers a `assets/VolumeIcon.icns` over the .app's
    /// AppIcon when displaying the volume's badge.
    let volumeIconURL: URL?
    let appBundleURL: URL?
    let contentSize: CGSize
    let content: Content

    public init(title: String,
                volumeIconURL: URL? = nil,
                appBundleURL: URL? = nil,
                contentSize: CGSize,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.volumeIconURL = volumeIconURL
        self.appBundleURL = appBundleURL
        self.contentSize = contentSize
        self.content = content()
    }

    public var body: some View {
        // macOS Tahoe 26 windows: ~10pt continuous-curve corner radius.
        // Lives in `body` because Swift forbids static stored
        // properties on generic types. Inline rather than a global
        // since this radius is only meaningful for the Finder mimic.
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 0) {
            // No divider between title bar and content — Tahoe Finder
            // unifies the toolbar with the content area when no actual
            // toolbar widgets are present, which is exactly the DMG
            // install case. The title bar background flows into the
            // content background as one continuous white surface.
            titleBar
            content
                .frame(width: contentSize.width, height: contentSize.height)
                // Decorations that drift above or below the content area
                // would otherwise overlap the title bar (drawn first in
                // the VStack, so z-below the content) and slip under the
                // volume strip (drawn after, so z-above). Clipping makes
                // both edges behave the same way: nothing extends past
                // the content rectangle, which matches what Finder will
                // actually show when the DMG mounts.
                .clipped()
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: 1)
            volumeStrip
        }
        .background(Tokens.color(.toolbarBackground))
        // Clip to a rounded corner so the volume-strip divider butts
        // cleanly into the rounded edges instead of poking past them.
        .clipShape(shape)
        // Faint outline tracing the rounded edge. Half-pt at low
        // opacity reads as anti-aliasing assist rather than a hard
        // border — Tahoe relies on the shadow for edge definition.
        .overlay(shape.stroke(Color.black.opacity(0.10), lineWidth: 0.5))
        // Two-layer shadow approximating Tahoe's window drop shadow:
        // a tight dense layer for contact, and a soft diffuse layer
        // for depth. Single-layer shadows read flat against the
        // canvas background.
        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 10)
        .allowsHitTesting(true)
    }

    /// macOS Tahoe 26 title bar: traffic lights flush-left, then a small
    /// volume-bullet, then the volume name — all left-aligned, no centered
    /// title (Tahoe dropped centered titles on toolbar-less windows). No
    /// bottom divider; the bar's background flows into the content area
    /// as one continuous surface.
    private var titleBar: some View {
        HStack(spacing: 8) {
            trafficLight(color: Color(red: 1.00, green: 0.36, blue: 0.36))
            trafficLight(color: Color(red: 1.00, green: 0.74, blue: 0.18))
            trafficLight(color: Color(red: 0.32, green: 0.78, blue: 0.30))
            // ~4pt gap separates the lights from the volume icon,
            // matching the screenshot's optical spacing.
            volumeIcon(sizePoints: 14)
                .padding(.leading, 4)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.color(.textPrimary))
            Spacer()
        }
        .padding(.leading, 12)
        .frame(height: CGFloat(FinderChrome.titleBarHeightPoints))
        .background(Tokens.color(.toolbarBackground))
    }

    private func trafficLight(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
    }

    /// Small rendition of the volume's icon — what Finder draws before
    /// the volume name on Tahoe. Falls back to a generic disk glyph when
    /// the app bundle URL is unknown or can't be rasterised (missing
    /// AppIcon, broken path, etc.). The icon is loaded via NSWorkspace
    /// each body re-evaluation; the workspace caches internally so this
    /// is cheap, and SwiftUI only re-runs the body when the path or
    /// title actually changes.
    @ViewBuilder
    private func volumeIcon(sizePoints: CGFloat) -> some View {
        // Source priority matches Finder + `ReleasePipeline.resolveVolumeIcon`:
        // a custom `assets/VolumeIcon.icns` first, the .app's AppIcon
        // second. The volume icon — when provided — is a simple glyph
        // designed for small-context use and has no envelope or shadow.
        // The .app icon goes through NSWorkspace's standard styling which
        // wraps every icon in the macOS Big Sur+ rounded-square envelope
        // with a baked drop shadow; we suppress that shadow downstream
        // with contrast, but a real VolumeIcon avoids it entirely.
        if let cg = loadVolumeIconCG(sizePoints: sizePoints) {
            Image(cg, scale: 1.0, label: Text("Volume icon"))
                .resizable()
                .frame(width: sizePoints, height: sizePoints)
                // Flatten the soft drop shadow that NSWorkspace bakes
                // into AppIcon renders at small sizes. Light gray pixels
                // (~RGB 220-245) get pushed toward white and disappear
                // against the white chrome; dark icon content stays dark.
                .contrast(1.4)
        } else {
            // No icon resolvable — Finder itself falls back to a generic
            // disk glyph here. We use SF Symbols' `internaldrive.fill`
            // which reads as a stylised disk at small sizes.
            Image(systemName: "internaldrive.fill")
                .font(.system(size: sizePoints * 0.85))
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(width: sizePoints, height: sizePoints)
        }
    }

    /// Loads the small volume-icon CGImage, preferring `volumeIconURL`
    /// over `appBundleURL`. Returns nil when neither resolves to a
    /// rasterisable icon.
    private func loadVolumeIconCG(sizePoints: CGFloat) -> CGImage? {
        let target = Int(sizePoints)
        if let url = volumeIconURL,
           let cg = AppIconLoader.appBundleIcon(at: url, sizePoints: target) {
            return cg
        }
        if let url = appBundleURL,
           let cg = AppIconLoader.appBundleIcon(at: url, sizePoints: target) {
            return cg
        }
        return nil
    }

    /// macOS 26 Tahoe always-on volume strip — a slim band at the bottom
    /// of the window with the volume name left-aligned next to the same
    /// icon that appears in the title bar (rendered smaller).
    private var volumeStrip: some View {
        HStack(spacing: 6) {
            volumeIcon(sizePoints: 11)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.color(.textSecondary))
            Spacer()
        }
        .padding(.leading, 12)
        .frame(height: CGFloat(FinderChrome.bottomChromeHeightPoints))
        .background(Tokens.color(.toolbarBackground))
    }
}
