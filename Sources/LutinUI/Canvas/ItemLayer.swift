import SwiftUI
import AppKit
import LutinConfig
import LutinDocument
import LutinAppKit

public struct ItemLayer: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    let guideState: CanvasGuideState
    let configW: CGFloat
    let configH: CGFloat
    @Environment(PreferencesStore.self) private var preferences
    @State private var editingID: String?

    public init(document: LutinProjectDocument,
                selectionModel: CanvasSelectionModel,
                guideState: CanvasGuideState,
                configW: CGFloat,
                configH: CGFloat) {
        self.document = document
        self.selectionModel = selectionModel
        self.guideState = guideState
        self.configW = configW
        self.configH = configH
    }

    public var body: some View {
        let outsiders = OffCanvasDetection.outsiders(in: document.config)
        ZStack(alignment: .topLeading) {
            ForEach((document.config.items ?? []).filter { !($0.hidden ?? false) }, id: \.id) { item in
                let isOffCanvas = outsiders.contains(.item(id: item.id))
                itemView(for: item, isOffCanvas: isOffCanvas)
                    .position(x: CGFloat(item.x), y: CGFloat(item.y))
                    .onTapGesture {
                        if NSEvent.modifierFlags.contains(.command) {
                            selectionModel.toggle(.item(id: item.id))
                        } else {
                            selectionModel.select(.item(id: item.id))
                        }
                    }
                    .draggableItem(document: document,
                                   selectionModel: selectionModel,
                                   id: .item(id: item.id),
                                   snapGrid: preferences.preferences.snapGridSize,
                                   guideState: guideState,
                                   configW: configW,
                                   configH: configH)
            }
        }
    }

    private func itemView(for item: LutinConfig.Item, isOffCanvas: Bool) -> some View {
        let isSelected: Bool = selectionModel.selection.contains(.item(id: item.id))
        let iconSize = CGFloat(document.config.window?.iconSize ?? 96)
        return ZStack {
            // Hover detection moved out of the item view 2026-05-25.
            // Per-view `.onHover` couldn't see through the opaque
            // iconArtwork — Color.clear catchers behind the icon only
            // fired when the cursor was in the label band beneath
            // the glyph. Hover is now driven by `.onContinuousHover`
            // on the canvas in `CanvasView.body`, which hit-tests
            // against the same `boundingBox(for:iconSize:)` used for
            // measurements — so the hover region exactly matches the
            // measurement region by construction, with no view
            // hierarchy interference.
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
                let textSize = CGFloat(document.config.window?.textSize ?? 12)
                Text(label)
                    .font(.system(size: textSize))
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
        .opacity(isOffCanvas ? 0.5 : 1.0)
        .overlay {
            if isOffCanvas {
                SquareShape().stroke(Tokens.color(.offCanvasOutline), lineWidth: Tokens.Size.hairline)
                    .frame(width: iconSize, height: iconSize)
            }
        }
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
