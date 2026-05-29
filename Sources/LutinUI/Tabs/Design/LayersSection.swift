import SwiftUI
import LutinDocument
import AppKit

public struct LayersSection: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    @State private var isExpanded: Bool = true
    @State private var dropTargetIndex: Int?

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document
        self.selectionModel = selectionModel
    }

    public var body: some View {
        let rows = LayersOrdering.rows(from: document.config)
        // App icons always render on top of every decoration (CanvasView
        // draws ImageDecorationLayer below ItemLayer), so they're pinned to
        // the top of the list and aren't draggable. Image decorations sit
        // below, listed front-to-back — the frontmost (last in the
        // `decorations` array, drawn last) appears first.
        let itemRows = rows.filter { $0.kind == .item }
        let imageRows = rows.filter { $0.kind == .image }.reversed()
        return LutinCollapsibleSection(isExpanded: $isExpanded) {
            // No horizontal padding here — `LutinCollapsibleSection` already
            // pads its header HStack at `md`, matching the side panel's
            // baseline x. Adding `md` again pushed the text to 28pt while
            // every other label sat at 14pt.
            Text("Layers").font(Typography.chromeSmall.weight(.medium))
                .foregroundStyle(Tokens.color(.textSecondary))
                .padding(.top, Tokens.spacing(.sm))
        } content: {
            VStack(spacing: 0) {
                ForEach(itemRows, id: \.id) { row in
                    layerRow(row, draggable: false)
                }
                ForEach(Array(imageRows), id: \.id) { row in
                    imageLayerRow(row)
                }
            }
            .padding(.vertical, Tokens.spacing(.xs))
        }
    }

    /// An image row that can be dragged to reorder front/back. The drag
    /// payload is the decoration's array index; dropping it on another image
    /// row reorders to that row's index via `reorderImageDecoration`.
    @ViewBuilder
    private func imageLayerRow(_ row: LayersOrdering.Row) -> some View {
        if case .image(let arrayIndex) = row.id {
            layerRow(row, draggable: true)
                .overlay {
                    if dropTargetIndex == arrayIndex {
                        Tokens.color(.brandAccent).opacity(0.14)
                            .allowsHitTesting(false)
                    }
                }
                .draggable("\(Self.dragPrefix)\(arrayIndex)") { dragPreview(row) }
                .dropDestination(for: String.self) { payload, _ in
                    dropTargetIndex = nil
                    // The sentinel prefix means only an actual layer-row drag
                    // matches — arbitrary text dragged in from another app
                    // can't parse into a reorder.
                    guard let from = Self.layerIndex(from: payload.first), from != arrayIndex else { return false }
                    // No `withAnimation` here: reordering only changes draw
                    // order (front/back). Animating the apply makes every
                    // canvas view observing the config pulse/reposition.
                    try? document.apply(.reorderImageDecoration(fromIndex: from, toIndex: arrayIndex))
                    return true
                } isTargeted: { targeted in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        dropTargetIndex = targeted ? arrayIndex : nil
                    }
                }
        }
    }

    /// Compact lift preview shown under the cursor while dragging. Without an
    /// explicit preview the system snapshots the full-width row (including its
    /// background and eye button), which snaps and jitters as it lifts.
    private func dragPreview(_ row: LayersOrdering.Row) -> some View {
        HStack(spacing: Tokens.spacing(.sm)) {
            Image(systemName: "photo").font(.system(size: 12))
                .foregroundStyle(Tokens.color(.textSecondary))
            Text(row.displayName).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textPrimary)).lineLimit(1)
        }
        .padding(.horizontal, Tokens.spacing(.sm))
        .padding(.vertical, Tokens.spacing(.xs))
        .background(SquareShape().fill(Tokens.color(.surfaceElevated)))
    }

    private func layerRow(_ row: LayersOrdering.Row, draggable: Bool) -> some View {
        let isSelected = selectionModel.selection.contains(row.id)
        return HStack(spacing: Tokens.spacing(.sm)) {
            Image(systemName: draggable ? "line.3.horizontal" : glyph(for: row.kind))
                .font(.system(size: 12))
                .foregroundStyle(Tokens.color(.textTertiary))
                .frame(width: 16)
            Text(row.displayName)
                .font(Typography.chromeSmall)
                .foregroundStyle(row.hidden ? Tokens.color(.textTertiary) : Tokens.color(.textPrimary))
                .strikethrough(row.hidden, color: Tokens.color(.textTertiary))
                .lineLimit(1)
            Spacer()
            LutinIconButton(systemName: row.hidden ? "eye.slash" : "eye",
                            accessibilityLabel: "Toggle layer visibility") { toggleHidden(row) }
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, Tokens.spacing(.xs))
        .background(isSelected ? Tokens.color(.brandAccentMuted) : Color.clear)
        .lutinHitTarget()
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                selectionModel.toggle(row.id)
            } else {
                selectionModel.select(row.id)
            }
        }
    }

    private func glyph(for kind: LayersOrdering.Kind) -> String {
        switch kind { case .item: "app"; case .image: "photo" }
    }

    private func toggleHidden(_ row: LayersOrdering.Row) {
        do {
            switch row.id {
            case .item(let id):
                try document.apply(.setItemHidden(id: id, hidden: !row.hidden))
            case .image(let i):
                try document.apply(.setImageHidden(index: i, hidden: !row.hidden))
            }
        } catch { /* surfaced upstream */ }
    }

    /// Sentinel that tags a layer-row drag payload so a generic String drag
    /// from another app can't be mistaken for a reorder.
    private static let dragPrefix = "lutin-layer:"

    /// Parses a layer-row array index out of a drag payload, or nil if the
    /// payload didn't originate from a layer row.
    private static func layerIndex(from payload: String?) -> Int? {
        guard let s = payload, s.hasPrefix(dragPrefix) else { return nil }
        return Int(s.dropFirst(dragPrefix.count))
    }
}
