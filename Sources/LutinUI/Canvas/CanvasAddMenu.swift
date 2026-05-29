import SwiftUI
import AppKit
import LutinConfig
import LutinDocument

/// A flat icon button + chevron-down hint that opens a Menu with the Add
/// items. Anchored to the top-trailing corner of the canvas.
///
/// "Add Arrow…" prompts for an image file — the project supplies its own
/// arrow art (built-in arrow templates ship later). Drawn arrows were
/// removed: getting a Core Graphics arrow + SwiftUI preview to agree on
/// head/inset math turned out brittle, and an image gives the user
/// pixel-perfect control over the look.
public struct CanvasAddMenu: View {
    @Bindable var document: LutinProjectDocument

    public init(document: LutinProjectDocument) {
        self.document = document
    }

    public var body: some View {
        Menu {
            Button("Add App…") { addLibrary(.app) } // allow-menu-button
            Button("Add Applications folder") { addLibrary(.applications) } // allow-menu-button
            Button("Add Image…") { addLibrary(.image) } // allow-menu-button
            Divider()
            Button("Add Arrow…", action: addArrowImage) // allow-menu-button
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .frame(width: 36, height: 28)
            .background(SquareShape().fill(Tokens.color(.surfaceElevated)))
            .foregroundStyle(Tokens.color(.textPrimary))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    /// Asks the user for an arrow image and places it as an image
    /// decoration. When the project has exactly two visible items, the
    /// arrow spans the gap between their centers — otherwise it lands
    /// at the canvas center.
    private func addArrowImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let placement = arrowPlacement(for: url)
        try? document.apply(.addImageDecoration(
            path: url.path,
            x: placement.x,
            y: placement.y,
            width: placement.width,
            height: nil))
    }

    private struct Placement { let x: Int; let y: Int; let width: Int }

    /// Computes (x, y, width) for the new arrow image. `x`/`y` are the
    /// image's top-left corner in window points (matches the renderer's
    /// `DecorationCompositor.drawImage` contract). When two visible items
    /// exist we span the gap between their centers and vertically align
    /// the image's center with the icon row; otherwise we drop a 160-pt
    /// image at the canvas center.
    private func arrowPlacement(for imageURL: URL) -> Placement {
        let configW = document.config.window?.width ?? 680
        let configH = document.config.window?.height ?? 420
        let iconSize = document.config.window?.iconSize ?? 96
        let visible = (document.config.items ?? []).filter { !($0.hidden ?? false) }
        // Source aspect ratio so the y we pick really centers the image
        // on the icon row. NSImage is best-effort: if the file refuses to
        // decode we fall back to a 1:3 estimate (typical arrow art).
        let aspect: Double = {
            guard let ns = NSImage(contentsOf: imageURL), ns.size.width > 0 else {
                return 1.0 / 3.0
            }
            return Double(ns.size.height / ns.size.width)
        }()

        if visible.count == 2 {
            let a = visible[0], b = visible[1]
            let left  = a.x <  b.x ? a : b
            let right = a.x <  b.x ? b : a
            // Leave half the icon plus a breath on each side so the
            // image doesn't kiss the icons.
            let padding = iconSize / 2 + 12
            let width = max(40, (right.x - left.x) - padding * 2)
            let height = Int((Double(width) * aspect).rounded())
            let centerY = (a.y + b.y) / 2
            return Placement(x: left.x + padding,
                             y: centerY - height / 2,
                             width: width)
        }
        let width = 160
        let height = Int((Double(width) * aspect).rounded())
        return Placement(x: (configW - width) / 2,
                         y: (configH - height) / 2,
                         width: width)
    }

    private func addLibrary(_ item: LibraryItem) {
        let cx = CGFloat(document.config.window?.width ?? 680)
        let cy = CGFloat(document.config.window?.height ?? 420)
        CanvasFileDropDelegate.addLibrary(item,
                                          at: CGPoint(x: cx / 2, y: cy / 2),
                                          document: document)
    }
}
