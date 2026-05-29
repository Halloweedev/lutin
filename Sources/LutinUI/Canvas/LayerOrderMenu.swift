import SwiftUI
import LutinConfig
import LutinDocument

/// Right-click "Bring to Front / Forward / Backward / Send to Back" actions
/// for a single canvas element. Z-order is array order — later in the
/// `items` / `decorations` array is drawn on top — so "front" maps to the
/// last index and "back" to index 0. Reordering stays within the element's
/// own array; an image and an icon live in separate render layers and can't
/// be interleaved.
struct LayerOrderMenu: View {
    @Bindable var document: LutinProjectDocument
    let id: CanvasSelectionID

    var body: some View {
        let (current, last) = bounds()
        Button("Bring to Front") { reorder(to: last) }   // allow-menu-button
        Button("Bring Forward") { reorder(to: min(last, current + 1)) }  // allow-menu-button
        Button("Send Backward") { reorder(to: max(0, current - 1)) }     // allow-menu-button
        Button("Send to Back") { reorder(to: 0) }         // allow-menu-button
    }

    /// (current index, last index) within the element's backing array.
    private func bounds() -> (Int, Int) {
        switch id {
        case .item(let itemID):
            let items = document.config.items ?? []
            let idx = items.firstIndex { $0.id == itemID } ?? 0
            return (idx, max(0, items.count - 1))
        case .image(let index):
            // The raw `decorations` array index IS the z-order coordinate
            // (drawn in array order), so count-1 is the frontmost slot. Only
            // image decorations exist today (ConfigValidator rejects other
            // types), so the image index space and the array index space
            // coincide; revisit if non-image decorations are ever added.
            let count = (document.config.decorations ?? []).count
            return (index, max(0, count - 1))
        }
    }

    private func reorder(to target: Int) {
        switch id {
        case .item(let itemID):
            try? document.apply(.reorderItem(id: itemID, toIndex: target))
        case .image(let index):
            try? document.apply(.reorderImageDecoration(fromIndex: index, toIndex: target))
        }
    }
}
