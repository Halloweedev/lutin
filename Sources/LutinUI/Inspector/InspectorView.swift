import SwiftUI
import LutinConfig
import LutinDocument

public struct InspectorView: View {
    @Bindable var document: LutinProjectDocument
    let selection: CanvasSelectionID?

    public init(document: LutinProjectDocument, selection: CanvasSelectionID?) {
        self.document = document
        self.selection = selection
    }

    public var body: some View {
        Form {
            switch selection {
            case .none: projectSection
            case .some(.item(let id)): itemSection(id: id)
            case .some(.image): Text("Image overlay selected")
            }
        }
        .formStyle(.grouped)
        .frame(width: 280)
        .background(Tokens.color(.panelBackground))
    }

    private var projectSection: some View {
        Section("Project") {
            LutinTextField("Name", text: Binding(
                get: { document.config.project.name },
                set: { try? document.apply(.setProjectName($0)) }))
            LutinTextField("Output directory", text: Binding(
                get: { document.config.output.directory },
                set: { try? document.apply(.setOutputDirectory($0)) }))
            LutinTextField("Background template", text: Binding(
                get: { document.config.background?.template ?? "" },
                set: { try? document.apply(.setBackgroundTemplate($0)) }))
            LabeledContent("Icon size") {
                HStack(spacing: Tokens.spacing(.sm)) {
                    Text("\(document.config.window?.iconSize ?? 96) pt").font(Typography.chromeSmall)
                    LutinStepper(
                        value: Binding(
                            get: { document.config.window?.iconSize ?? 96 },
                            set: { try? document.apply(.setIconSize($0)) }),
                        in: 32...256, step: 8)
                }
            }
        }
    }

    private func itemSection(id: String) -> some View {
        Section("Item · \(id)") {
            if let item = document.config.items?.first(where: { $0.id == id }) {
                LabeledContent("Type", value: item.type)
                LabeledContent("x") {
                    HStack(spacing: Tokens.spacing(.sm)) {
                        Text("\(item.x)").font(Typography.chromeSmall)
                        LutinStepper(
                            value: Binding(
                                get: { item.x },
                                set: { try? document.apply(.moveItem(id: id, x: $0, y: item.y)) }),
                            in: 0...4096)
                    }
                }
                LabeledContent("y") {
                    HStack(spacing: Tokens.spacing(.sm)) {
                        Text("\(item.y)").font(Typography.chromeSmall)
                        LutinStepper(
                            value: Binding(
                                get: { item.y },
                                set: { try? document.apply(.moveItem(id: id, x: item.x, y: $0)) }),
                            in: 0...4096)
                    }
                }
                LutinTextField("Label", text: Binding(
                    get: { item.label ?? "" },
                    set: { try? document.apply(.renameItemLabel(id: id, label: $0.isEmpty ? nil : $0)) }))
            } else {
                Text("Item not found").foregroundStyle(.secondary)
            }
        }
    }

}
