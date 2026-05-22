import SwiftUI
import LutinConfig
import LutinDocument
import LutinAppKit

public struct ItemLayer: View {
    @Bindable var document: LutinProjectDocument
    @Binding var selection: Set<CanvasSelectionID>
    @Environment(PreferencesStore.self) private var preferences
    @State private var hoveredID: String?
    @State private var connectorDrag: ConnectorDragState = .idle
    @State private var editingID: String?

    public init(document: LutinProjectDocument, selection: Binding<Set<CanvasSelectionID>>) {
        self.document = document
        self._selection = selection
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(document.config.items ?? [], id: \.id) { item in
                itemView(for: item)
                    .position(x: CGFloat(item.x), y: CGFloat(item.y))
                    .onTapGesture { selection = [.item(id: item.id)] }
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
        let isSelected: Bool = selection.contains(.item(id: item.id))
        let iconSize = CGFloat(document.config.window?.iconSize ?? 96)
        return ZStack {
            iconArtwork(for: item, size: iconSize)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(isSelected ? 1.03 : 1.0)
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.12),
                        radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
            if editingID == item.id {
                InlineLabelEditor(document: document, itemID: item.id,
                                  isEditing: Binding(get: { editingID == item.id },
                                                     set: { if !$0 { editingID = nil } }))
                    .frame(width: 80)
                    .offset(y: 36)
            } else if let label = item.label, !label.isEmpty {
                Text(label)
                    .font(Typography.canvasLabel)
                    .offset(y: iconSize / 2 + 12)
                    .onTapGesture(count: 2) { editingID = item.id }
            } else {
                // Allow double-clicking the empty label area to enter edit mode for unlabelled items.
                Color.clear
                    .frame(width: iconSize, height: 14)
                    .offset(y: iconSize / 2 + 12)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editingID = item.id }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: iconSize * 0.18)
                .strokeBorder(Tokens.color(.itemSelected), lineWidth: isSelected ? 2 : 0)
                .frame(width: iconSize, height: iconSize)
        )
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    /// Real Finder icon for the item — `.app` bundle icon resolved against
    /// the project directory for `type: app`, the `/Applications` folder
    /// icon for `type: applications`. Falls back to an SF Symbol if the
    /// bundle is missing or the icon fails to rasterize.
    @ViewBuilder
    private func iconArtwork(for item: LutinConfig.Item, size: CGFloat) -> some View {
        if let cgImage = loadIcon(for: item, sizePoints: Int(size)) {
            Image(cgImage, scale: 1.0, label: Text(item.label ?? item.id))
                .resizable()
                .interpolation(.high)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(Color.white)
                Image(systemName: item.type == "applications" ? "folder.fill" : "shippingbox.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Tokens.color(.brandAccent))
            }
        }
    }

    private func loadIcon(for item: LutinConfig.Item, sizePoints: Int) -> CGImage? {
        switch item.type {
        case "applications":
            return AppIconLoader.applicationsFolderIcon(sizePoints: sizePoints)
        case "app":
            let appPath = document.config.app.path
            let url = URL(fileURLWithPath: appPath, relativeTo: document.projectDirectory)
                .standardizedFileURL
            return AppIconLoader.appBundleIcon(at: url, sizePoints: sizePoints)
        default:
            return nil
        }
    }
}
