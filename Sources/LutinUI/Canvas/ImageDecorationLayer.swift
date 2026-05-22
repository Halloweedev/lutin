import SwiftUI
import AppKit
import LutinDocument
import LutinConfig

public struct ImageDecorationLayer: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
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
        return Group {
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: w, height: w)
                    .opacity(hidden ? 0.25 : 1.0)
            } else {
                SquareShape().stroke(Tokens.color(.logError), lineWidth: Tokens.Size.hairline)
                    .frame(width: w, height: w)
                    .overlay(Text("?").foregroundStyle(Tokens.color(.logError)))
            }
        }
        .position(x: CGFloat(deco.x ?? 0), y: CGFloat(deco.y ?? 0))
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                selectionModel.toggle(.image(index: index))
            } else {
                selectionModel.select(.image(index: index))
            }
        }
        .overlay {
            if isSelected {
                ResizeHandles(document: document, index: index, deco: deco)
            }
        }
    }
}
