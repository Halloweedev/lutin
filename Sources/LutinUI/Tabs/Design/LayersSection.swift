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
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(LayersOrdering.rows(from: document.config), id: \.id) { row in
                    layerRow(row)
                }
            }
            .padding(.vertical, Tokens.spacing(.xs))
        } label: {
            Text("Layers").font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .textCase(.uppercase)
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.top, Tokens.spacing(.sm))
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
            Button(action: { toggleHidden(row) }) {
                Image(systemName: row.hidden ? "eye.slash" : "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .padding(.vertical, 4)
        .background(isSelected ? Tokens.color(.brandAccentMuted) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                selectionModel.toggle(row.id)
            } else {
                selectionModel.select(row.id)
            }
        }
    }

    private func glyph(for kind: LayersOrdering.Kind) -> String {
        switch kind { case .item: "app"; case .image: "photo"; case .arrow: "arrow.right" }
    }

    private func toggleHidden(_ row: LayersOrdering.Row) {
        do {
            switch row.id {
            case .item(let id):
                try document.apply(.setItemHidden(id: id, hidden: !row.hidden))
            case .image(let i):
                try document.apply(.setImageHidden(index: i, hidden: !row.hidden))
            case .arrow(let from, let to):
                try document.apply(.setArrowHidden(from: from, to: to, hidden: !row.hidden))
            }
        } catch { /* surfaced upstream */ }
    }
}
