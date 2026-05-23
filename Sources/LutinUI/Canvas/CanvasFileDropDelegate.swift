import SwiftUI
import UniformTypeIdentifiers
import AppKit
import LutinDocument
import LutinConfig

public struct CanvasFileDropDelegate: DropDelegate {
    let document: LutinProjectDocument
    let dropPointInWindowPoints: (CGPoint) -> CGPoint

    public init(document: LutinProjectDocument,
                dropPointInWindowPoints: @escaping (CGPoint) -> CGPoint) {
        self.document = document
        self.dropPointInWindowPoints = dropPointInWindowPoints
    }

    public func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [LibraryItem.dragType, .fileURL])
    }

    public func performDrop(info: DropInfo) -> Bool {
        let raw = dropPointInWindowPoints(info.location)
        let dropX = Int(raw.x), dropY = Int(raw.y)
        if let provider = info.itemProviders(for: [LibraryItem.dragType]).first {
            provider.loadObject(ofClass: NSString.self) { rawValue, _ in
                guard let rawValue = rawValue as? String,
                      let item = LibraryItem(rawValue: rawValue) else { return }
                DispatchQueue.main.async {
                    Self.handleLibraryDrop(item, x: dropX, y: dropY, document: document)
                }
            }
            return true
        }
        if let provider = info.itemProviders(for: [.fileURL]).first {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    Self.handleFileDrop(url, x: dropX, y: dropY, document: document)
                }
            }
            return true
        }
        return false
    }

    /// Public entry point used by the + toolbar menu (Task 3.3) and the
    /// right-click context menu (Task 3.4) so all four add paths share one
    /// implementation. Operates on the main actor.
    @MainActor
    public static func addLibrary(_ item: LibraryItem, at point: CGPoint, document: LutinProjectDocument) {
        handleLibraryDrop(item, x: Int(point.x), y: Int(point.y), document: document)
    }

    @MainActor
    static func handleLibraryDrop(_ item: LibraryItem, x: Int, y: Int, document: LutinProjectDocument) {
        switch item {
        case .app:
            // If app.path is unset, ask for a .app and ingest its metadata.
            if document.config.app.path.isEmpty {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.applicationBundle]
                panel.allowsMultipleSelection = false
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                guard panel.runModal() == .OK, let url = panel.url else { return }
                ingestAppBundle(at: url, document: document)
            }
            let label = labelForAppItem(document: document)
            addItem(type: "app", x: x, y: y, label: label, document: document)
        case .applications:
            addItem(type: "applications", x: x, y: y, label: "Applications", document: document)
        case .image:
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.png, .jpeg]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? document.apply(.addImageDecoration(path: url.path, x: x, y: y, width: 120))
        }
    }

    @MainActor
    static func handleFileDrop(_ url: URL, x: Int, y: Int, document: LutinProjectDocument) {
        let ext = url.pathExtension.lowercased()
        if ext == "app" {
            ingestAppBundle(at: url, document: document)
            let label = labelForAppItem(document: document)
            addItem(type: "app", x: x, y: y, label: label, document: document)
        } else if ["png", "jpg", "jpeg"].contains(ext) {
            try? document.apply(.addImageDecoration(path: url.path, x: x, y: y, width: 120))
        }
    }

    /// Sets `app.path` to the new bundle. If the bundle's Info.plist is
    /// readable, the project's display name preference is honored — the
    /// item label uses `CFBundleDisplayName`. We do NOT overwrite the
    /// project's bundleId or name automatically: the user picked those
    /// when they created the project and may package a renamed binary.
    @MainActor
    private static func ingestAppBundle(at url: URL, document: LutinProjectDocument) {
        try? document.apply(.setApp(path: url.path))
    }

    /// Returns the best label for a new `type: app` item: the bundle's
    /// display name (read from Info.plist) when available, falling back
    /// to the project name, then the bundle's filename.
    @MainActor
    private static func labelForAppItem(document: LutinProjectDocument) -> String {
        let path = document.config.app.path
        guard !path.isEmpty else { return document.config.project.name }
        let url = URL(fileURLWithPath: path)
        if let meta = try? AppBundleInfo.read(url) {
            return meta.displayName
        }
        let fallback = url.deletingPathExtension().lastPathComponent
        return fallback.isEmpty ? document.config.project.name : fallback
    }

    @MainActor
    static func addItem(type: String, x: Int, y: Int, label: String, document: LutinProjectDocument) {
        let base = slugify(label)
        let existing = Set((document.config.items ?? []).map(\.id))
        let id = uniqueID(base, existing: existing)
        let item = LutinConfig.Item(type: type, id: id, x: x, y: y, label: label, hidden: nil)
        try? document.apply(.addItem(item))
    }

    // MARK: - Pure helpers
    public static func slugify(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let lower = raw.lowercased()
        var out = ""
        for scalar in lower.unicodeScalars {
            if allowed.contains(scalar) { out.append(Character(scalar)) }
            else { out.append("-") }
        }
        while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return out.isEmpty ? "item" : out
    }

    public static func uniqueID(_ base: String, existing: Set<String>) -> String {
        guard existing.contains(base) else { return base }
        var n = 2
        while existing.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}
