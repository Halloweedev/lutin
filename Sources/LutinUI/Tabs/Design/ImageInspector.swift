import SwiftUI
import AppKit
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
                                                                            width: deco.width ?? 100)) }),
                            format: .number)
                    }
                    LabeledField(label: "y") {
                        LutinNumericField("", value: Binding(
                            get: { deco.y ?? 0 },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: deco.x ?? 0,
                                                                            y: $0,
                                                                            width: deco.width ?? 100)) }),
                            format: .number)
                    }
                    LabeledField(label: "w") {
                        LutinNumericField("", value: Binding(
                            get: { deco.width ?? 100 },
                            set: { try? document.apply(.moveImageDecoration(index: index,
                                                                            x: deco.x ?? 0,
                                                                            y: deco.y ?? 0,
                                                                            width: $0)) }),
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

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK, let url = panel.url,
              let deco = document.config.decorations?[safe: index] else { return }
        try? document.apply(.deleteImageDecoration(index: index))
        try? document.apply(.addImageDecoration(path: url.path,
                                                x: deco.x ?? 0, y: deco.y ?? 0,
                                                width: deco.width ?? 100))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
