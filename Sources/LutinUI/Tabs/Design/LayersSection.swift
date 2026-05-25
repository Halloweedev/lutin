import SwiftUI
import LutinDocument
import AppKit

public struct LayersSection: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    @State private var isExpanded: Bool = true

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document
        self.selectionModel = selectionModel
    }

    public var body: some View {
        LutinCollapsibleSection(isExpanded: $isExpanded) {
            // No horizontal padding here — `LutinCollapsibleSection` already
            // pads its header HStack at `md`, matching the side panel's
            // baseline x. Adding `md` again pushed the text to 28pt while
            // every other label sat at 14pt.
            Text("Layers").font(Typography.chromeSmall.weight(.medium))
                .foregroundStyle(Tokens.color(.textSecondary))
                .padding(.top, Tokens.spacing(.sm))
        } content: {
            VStack(spacing: 0) {
                ForEach(LayersOrdering.rows(from: document.config), id: \.id) { row in
                    layerRow(row)
                }
            }
            .padding(.vertical, Tokens.spacing(.xs))
        }
    }

    private func layerRow(_ row: LayersOrdering.Row) -> some View {
        let isSelected = selectionModel.selection.contains(row.id)
        return HStack(spacing: Tokens.spacing(.sm)) {
            Image(systemName: glyph(for: row.kind))
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
}
