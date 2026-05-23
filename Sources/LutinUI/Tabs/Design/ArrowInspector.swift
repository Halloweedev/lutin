import SwiftUI
import LutinDocument

public struct ArrowInspector: View {
    @Bindable var document: LutinProjectDocument
    let from: String
    let to: String

    public init(document: LutinProjectDocument, from: String, to: String) {
        self.document = document; self.from = from; self.to = to
    }

    public var body: some View {
        let arrow = document.config.decorations?.first(where: {
            $0.type == "arrow" && $0.from == from && $0.to == to
        })
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            HStack {
                LabeledField(label: "From") {
                    Text(from).font(Typography.chromeSmall)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Tokens.color(.brandAccentMuted))
                }
                LutinIconButton(systemName: "arrow.left.arrow.right",
                                accessibilityLabel: "Swap arrow direction",
                                action: swap)
                LabeledField(label: "To") {
                    Text(to).font(Typography.chromeSmall)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Tokens.color(.brandAccentMuted))
                }
            }
            LabeledField(label: "Label") {
                LutinTextField("", text: Binding(
                    get: { arrow?.label ?? "" },
                    set: { try? document.apply(.renameArrowLabel(from: from, to: to, label: $0.isEmpty ? nil : $0)) }))
            }
            Toggle("Hidden", isOn: Binding(
                get: { arrow?.hidden ?? false },
                set: { try? document.apply(.setArrowHidden(from: from, to: to, hidden: $0)) }))
        }
    }

    private func swap() {
        try? document.apply(.swapArrow(from: from, to: to))
    }
}
