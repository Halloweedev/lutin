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
}
