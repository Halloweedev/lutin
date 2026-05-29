import SwiftUI
import AppKit
import LutinConfig
import LutinDocument

public struct ImageInspector: View {
    @Bindable var document: LutinProjectDocument
    let index: Int

    public init(document: LutinProjectDocument, index: Int) {
        self.document = document; self.index = index
    }

    public var body: some View {
        let deco = document.config.decorations?[safe: index]
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            if let deco, deco.type == "image" {
                LabeledField(label: "Path") {
                    HStack {
                        Text(deco.path ?? "").font(Typography.chromeSmall)
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
                        LutinButton("Choose…", action: pickFile)
                    }
                }
                HStack(spacing: Tokens.spacing(.sm)) {
                    LabeledField(label: "x") {
                        LutinNumericField("", value: Binding(
                            get: { deco.x ?? 0 },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: $0,
                                                                            y: deco.y ?? 0,
                                                                            width: deco.width ?? 100,
                                                                            height: deco.height)) }),
                            format: .number)
                    }
                    LabeledField(label: "y") {
                        LutinNumericField("", value: Binding(
                            get: { deco.y ?? 0 },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: deco.x ?? 0,
                                                                            y: $0,
                                                                            width: deco.width ?? 100,
                                                                            height: deco.height)) }),
                            format: .number)
                    }
                    LabeledField(label: "w") {
                        LutinNumericField("", value: Binding(
                            get: { deco.width ?? 100 },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: deco.x ?? 0,
                                                                            y: deco.y ?? 0,
                                                                            width: $0,
                                                                            height: deco.height)) }),
                            format: .number)
                    }
                    LabeledField(label: "h") {
                        LutinNumericField("", value: Binding(
                            get: { displayedHeight(deco) },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: deco.x ?? 0,
                                                                            y: deco.y ?? 0,
                                                                            width: deco.width ?? 100,
                                                                            height: $0)) }),
                            format: .number)
                    }
                }
                LutinToggle("Hidden", isOn: Binding(
                    get: { deco.hidden ?? false },
                    set: { try? document.apply(.setImageHidden(index: index, hidden: $0)) }))
            } else {
                Text("Image overlay not found").foregroundStyle(Tokens.color(.textTertiary))
            }
        }
    }

    /// The height to show in the inspector: the explicit stretch height when
    /// set, otherwise the aspect-locked rendered height (width × source
    /// aspect) so the field matches what the canvas actually draws.
    private func displayedHeight(_ deco: LutinConfig.Decoration) -> Int {
        let w = deco.width ?? 100
        if let h = deco.height { return h }
        if let path = deco.path,
           let aspect = ImageSizeCache.aspect(ofPath: path, relativeTo: document.projectDirectory) {
            return Int((CGFloat(w) * aspect).rounded())
        }
        return w
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK, let url = panel.url,
              let deco = document.config.decorations?[safe: index] else { return }
        try? document.apply(.deleteImageDecoration(index: index))
        try? document.apply(.addImageDecoration(path: url.path,
                                                x: deco.x ?? 0, y: deco.y ?? 0,
                                                width: deco.width ?? 100,
                                                height: deco.height))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
