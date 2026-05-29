import SwiftUI
import AppKit
import LutinDocument
import LutinConfig

public struct ImageDecorationLayer: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    let guideState: CanvasGuideState
    let configW: CGFloat
    let configH: CGFloat

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
        // Explicit height → free stretch. Absent → aspect-locked to source.
        let h = deco.height.map(CGFloat.init) ?? w * aspect
        // All three layers (image, selection ring, resize handles) live
        // inside a single `.frame(w, h)` + `.position(...)` container so
        // they move together. The previous shape (image positioned,
        // selection ring + handles inside an .overlay) had a subtle bug:
        // `.position` makes its target view fill the parent for layout,
        // so the .overlay's bounds matched the WHOLE CANVAS, and the
        // un-positioned ResizeHandles ZStack centered itself in canvas
        // coordinates instead of around the image.
        return ZStack {
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
            if isSelected {
                SquareShape()
                    .stroke(Tokens.color(.itemSelected), lineWidth: 1)
                    .frame(width: w, height: h)
                ResizeHandles(document: document,
                              index: index,
                              deco: deco,
                              widthPoints: w,
                              heightPoints: h)
            }
        }
        .frame(width: w, height: h)
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
        // Per-view `.onHover` removed 2026-05-25 — hover is now
        // canvas-level via `.onContinuousHover` in `CanvasView`,
        // hit-testing against the same bounding boxes used for
        // measurements (see ItemLayer for the longer history).
        .draggableItem(document: document,
                       selectionModel: selectionModel,
                       id: .image(index: index),
                       snapGrid: 0,
                       guideState: guideState,
                       configW: configW,
                       configH: configH)
    }
}
