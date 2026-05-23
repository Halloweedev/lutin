import SwiftUI
import AppKit
import LutinDocument
import LutinConfig

public struct ImageDecorationLayer: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    let guideState: CanvasGuideState

    public init(document: LutinProjectDocument,
                selectionModel: CanvasSelectionModel,
                guideState: CanvasGuideState) {
        self.document = document
        self.selectionModel = selectionModel
        self.guideState = guideState
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array((document.config.decorations ?? []).enumerated()), id: \.offset) { i, deco in
                if deco.type == "image", let path = deco.path {
                    imageView(at: i, path: path, deco: deco)
                }
            }
        }
    }

    private func imageView(at index: Int, path: String, deco: LutinConfig.Decoration) -> some View {
        let url = URL(fileURLWithPath: path, relativeTo: document.projectDirectory).standardizedFileURL
        let isSelected = selectionModel.selection.contains(.image(index: index))
        let hidden = deco.hidden ?? false
        let w = CGFloat(deco.width ?? 100)
        // Match the renderer's drawImage(): width is window-points; height
        // is derived from the source image's aspect ratio. (x, y) is the
        // top-left corner of the draw rect, not the center — Decoration
        // Compositor.swift:154–157.
        let nsImage = NSImage(contentsOf: url)
        let aspect: CGFloat = {
            guard let ns = nsImage, ns.size.width > 0 else { return 1.0 }
            return ns.size.height / ns.size.width
        }()
        let h = w * aspect
        return Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: w, height: h)
                    .opacity(hidden ? 0.25 : 1.0)
            } else {
                SquareShape().stroke(Tokens.color(.logError), lineWidth: Tokens.Size.hairline)
                    .frame(width: w, height: h)
                    .overlay(Text("?").foregroundStyle(Tokens.color(.logError)))
            }
        }
        // Position the view's CENTER such that its TOP-LEFT lands at
        // (deco.x, deco.y) — matches the renderer's coordinate contract.
        .position(x: CGFloat(deco.x ?? 0) + w / 2,
                  y: CGFloat(deco.y ?? 0) + h / 2)
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                selectionModel.toggle(.image(index: index))
            } else {
                selectionModel.select(.image(index: index))
            }
        }
        .overlay {
            if isSelected {
                // Selection ring positioned at the same top-left convention.
                SquareShape()
                    .stroke(Tokens.color(.itemSelected), lineWidth: 1)
                    .frame(width: w, height: h)
                    .position(x: CGFloat(deco.x ?? 0) + w / 2,
                              y: CGFloat(deco.y ?? 0) + h / 2)
                ResizeHandles(document: document, index: index, deco: deco)
            }
        }
        .draggableItem(document: document,
                       selectionModel: selectionModel,
                       id: .image(index: index),
                       snapGrid: 0,
                       guideState: guideState)
    }
}
