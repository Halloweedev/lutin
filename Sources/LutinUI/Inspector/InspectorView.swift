import SwiftUI
import LutinConfig
import LutinDocument

public struct InspectorView: View {
    @Bindable var document: LutinProjectDocument
    let selection: CanvasSelection

    public init(document: LutinProjectDocument, selection: CanvasSelection) {
        self.document = document
        self.selection = selection
    }

    public var body: some View {
        Form {
            switch selection {
            case .none: projectSection
            case .item(let id): itemSection(id: id)
            case .arrow(let from, let to): arrowSection(from: from, to: to)
            }
        }
        .formStyle(.grouped)
        .frame(width: 280)
        .background(.regularMaterial)
    }

    private var projectSection: some View {
        Section("Project") {
            TextField("Name", text: Binding(
                get: { document.config.project.name },
                set: { try? document.apply(.setProjectName($0)) }))
            TextField("Output directory", text: Binding(
                get: { document.config.output.directory },
                set: { try? document.apply(.setOutputDirectory($0)) }))
            TextField("Background template", text: Binding(
                get: { document.config.background?.template ?? "" },
                set: { try? document.apply(.setBackgroundTemplate($0)) }))
            Stepper("Icon size: \(document.config.window?.iconSize ?? 96) pt",
                value: Binding(
                    get: { document.config.window?.iconSize ?? 96 },
                    set: { try? document.apply(.setIconSize($0)) }),
                in: 32...256, step: 8)
        }
    }

    private func itemSection(id: String) -> some View {
        Section("Item · \(id)") {
            if let item = document.config.items?.first(where: { $0.id == id }) {
                LabeledContent("Type", value: item.type)
                Stepper("x: \(item.x)", value: Binding(
                    get: { item.x },
                    set: { try? document.apply(.moveItem(id: id, x: $0, y: item.y)) }),
                    in: 0...4096)
                Stepper("y: \(item.y)", value: Binding(
                    get: { item.y },
                    set: { try? document.apply(.moveItem(id: id, x: item.x, y: $0)) }),
                    in: 0...4096)
                TextField("Label", text: Binding(
                    get: { item.label ?? "" },
                    set: { try? document.apply(.renameItemLabel(id: id, label: $0.isEmpty ? nil : $0)) }))
            } else {
                Text("Item not found").foregroundStyle(.secondary)
            }
        }
    }

    private func arrowSection(from: String, to: String) -> some View {
        Section("Arrow") {
            LabeledContent("From", value: from)
            LabeledContent("To", value: to)
            if let arrow = document.config.decorations?.first(where: {
                $0.type == "arrow" && $0.from == from && $0.to == to }) {
                TextField("Label", text: Binding(
                    get: { arrow.label ?? "" },
                    set: { try? document.apply(.renameArrowLabel(from: from, to: to, label: $0.isEmpty ? nil : $0)) }))
            }
        }
    }
}
