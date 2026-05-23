import SwiftUI
import LutinConfig
import LutinDocument

public struct InspectorSection: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    @State private var isExpanded: Bool = true

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document
        self.selectionModel = selectionModel
    }

    public var body: some View {
        LutinCollapsibleSection(isExpanded: $isExpanded) {
            Text("Inspector").font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .textCase(.uppercase)
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.top, Tokens.spacing(.sm))
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if selectionModel.selection.isEmpty {
            projectAndBackgroundForm
        } else if let single = selectionModel.single {
            singleSelectionForm(for: single)
        } else {
            multiSelectionForm
        }
    }

    private var projectAndBackgroundForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorCategory {
                LabeledField(label: "Project name") {
                    LutinTextField("", text: Binding(
                        get: { document.config.project.name },
                        set: { try? document.apply(.setProjectName($0)) }))
                }
            }
            InspectorCategory {
                BackgroundEditor(document: document)
            }
        }
    }

    @ViewBuilder
    private func singleSelectionForm(for id: CanvasSelectionID) -> some View {
        InspectorCategory {
            switch id {
            case .item(let itemID): ItemInspector(document: document, itemID: itemID)
            case .arrow(let from, let to):
                ArrowInspector(document: document, from: from, to: to)
            case .image(let i): ImageInspector(document: document, index: i)
            }
        }
    }

    private var multiSelectionForm: some View {
        InspectorCategory {
            VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
                Text("\(selectionModel.selection.count) selected")
                    .font(Typography.chrome)
                    .foregroundStyle(Tokens.color(.textPrimary))
                LutinButton("Hide all") { hideAll(true) }
                LutinButton("Show all") { hideAll(false) }
            }
        }
    }

    private func hideAll(_ hidden: Bool) {
        for id in selectionModel.selection {
            do {
                switch id {
                case .item(let i): try document.apply(.setItemHidden(id: i, hidden: hidden))
                case .arrow(let f, let t): try document.apply(.setArrowHidden(from: f, to: t, hidden: hidden))
                case .image(let i): try document.apply(.setImageHidden(index: i, hidden: hidden))
                }
            } catch { /* surfaced */ }
        }
    }
}

/// Wraps an inspector sub-group with a single bottom hairline divider.
/// Using only a bottom divider avoids doubling up between adjacent categories
/// while still providing clear horizontal band separation.
struct InspectorCategory<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.vertical, Tokens.spacing(.md))
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    let content: Content
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
            content
        }
    }
}
