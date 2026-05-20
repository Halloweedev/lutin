import SwiftUI
import LutinConfig
import LutinDocument

public struct ItemLayer: View {
    @Bindable var document: LutinProjectDocument
    @Binding var selection: CanvasSelection
    @Environment(PreferencesStore.self) private var preferences
    @State private var hoveredID: String?
    @State private var connectorDrag: ConnectorDragState = .idle
    @State private var editingID: String?

    public init(document: LutinProjectDocument, selection: Binding<CanvasSelection>) {
        self.document = document
        self._selection = selection
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(document.config.items ?? [], id: \.id) { item in
                itemView(for: item)
                    .position(x: CGFloat(item.x), y: CGFloat(item.y))
                    .onTapGesture { selection = .item(id: item.id) }
                    .onHover { hovering in
                        hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                    }
                    .overlay {
                        if hoveredID == item.id {
                            ConnectorHandles(document: document, item: item,
                                             dragState: $connectorDrag)
                        }
                    }
                    .draggableItem(document: document, id: item.id,
                                   snapGrid: preferences.preferences.snapGridSize)
            }
        }
        .onChange(of: connectorDrag) { _, newValue in
            if case .ended(let src, let pt) = newValue {
                let items = document.config.items ?? []
                let iconSize = document.config.window?.iconSize ?? 96
                if let target = ConnectorResolver.itemAt(point: pt, items: items, iconSize: iconSize),
                   target.id != src {
                    try? document.apply(.addArrow(from: src, to: target.id, label: nil))
                }
                connectorDrag = .idle
            }
        }
    }

    private func itemView(for item: LutinConfig.Item) -> some View {
        let isSelected: Bool = (selection == .item(id: item.id))
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            Image(systemName: item.type == "applications" ? "folder.fill" : "shippingbox.fill")
                .font(.system(size: 24))
                .foregroundStyle(Tokens.color(.brandAccent))
            if editingID == item.id {
                InlineLabelEditor(document: document, itemID: item.id,
                                  isEditing: Binding(get: { editingID == item.id },
                                                     set: { if !$0 { editingID = nil } }))
                    .frame(width: 80)
                    .offset(y: 36)
            } else if let label = item.label, !label.isEmpty {
                Text(label)
                    .font(Typography.canvasLabel)
                    .offset(y: 36)
                    .onTapGesture(count: 2) { editingID = item.id }
            } else {
                // Allow double-clicking the empty label area to enter edit mode for unlabelled items.
                Color.clear
                    .frame(width: 64, height: 14)
                    .offset(y: 36)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editingID = item.id }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Tokens.color(.itemSelected), lineWidth: isSelected ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

public enum CanvasSelection: Equatable {
    case none
    case item(id: String)
    case arrow(from: String, to: String)
}
