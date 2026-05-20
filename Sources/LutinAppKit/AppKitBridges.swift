import AppKit
import Foundation
import UniformTypeIdentifiers

/// AppKit-only shims used by views that can't get clean APIs from SwiftUI.
public enum AppKitBridges {
    /// Synchronous app-modal "Open" panel. Returns nil if the user cancels.
    public static func chooseAppBundle() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a .app bundle"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Synchronous "Choose a `lutin.yml`" panel.
    public static func chooseLutinConfig() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open lutin.yml"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Reveals a URL in Finder. No-ops if the path no longer exists.
    public static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens a URL with the system default app — for `.dmg` this mounts and
    /// reveals the disk image in Finder, for `.app` it launches the bundle.
    /// No-ops silently if the URL can't be opened.
    ///
    /// For `.dmg` files we route through `hdiutil attach -autoopen` instead of
    /// `NSWorkspace.open`. The `-autoopen` flag tells Finder to read the
    /// freshly mounted volume's `.DS_Store` and show its layout, which
    /// `NSWorkspace.open` does NOT do reliably on re-mounts of the same
    /// volume name (Finder otherwise serves cached chrome that ignores the
    /// background image and icon positions baked into the DMG).
    public static func open(_ url: URL) {
        if url.pathExtension.lowercased() == "dmg" {
            // Detach any prior mount of the same path, then attach with
            // -autoopen. Both calls are best-effort; if hdiutil isn't
            // available for any reason, fall through to NSWorkspace.open.
            let task = Process()
            task.launchPath = "/usr/bin/hdiutil"
            task.arguments = ["attach", url.path, "-autoopen"]
            do {
                try task.run()
                return
            } catch {
                // Fall through to NSWorkspace.open on failure.
            }
        }
        NSWorkspace.shared.open(url)
    }
}
