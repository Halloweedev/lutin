import SwiftUI
import LutinDocument
import LutinCore

public struct ItemInspector: View {
    @Bindable var document: LutinProjectDocument
    let itemID: String
    @State private var idDraft: String = ""
    @State private var idError: String?

    public init(document: LutinProjectDocument, itemID: String) {
        self.document = document; self.itemID = itemID
    }

    public var body: some View {
        let item = document.config.items?.first(where: { $0.id == itemID })
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            if let item {
                LabeledField(label: "Type") {
                    Text(item.type).font(Typography.chromeSmall)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Tokens.color(.brandAccentMuted))
                }
                LabeledField(label: "ID") {
                    TextField("", text: $idDraft, onCommit: commitID)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(SquareShape().stroke(idError == nil
                                                         ? Tokens.color(.divider)
                                                         : Tokens.color(.logError),
                                                         lineWidth: Tokens.Size.hairline))
                        .onAppear { idDraft = item.id }
                        .onChange(of: itemID) { _, new in idDraft = new; idError = nil }
                    if let idError {
                        Text(idError).font(Typography.chromeSmall)
                            .foregroundStyle(Tokens.color(.logError))
                    }
                }
                HStack(spacing: Tokens.spacing(.sm)) {
                    LabeledField(label: "x") {
                        TextField("", value: Binding(
                            get: { item.x },
                            set: { try? document.apply(.moveItem(id: itemID, x: $0, y: item.y)) }),
                            format: .number).textFieldStyle(.plain).padding(6)
                            .background(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
                    }
                    LabeledField(label: "y") {
                        TextField("", value: Binding(
                            get: { item.y },
                            set: { try? document.apply(.moveItem(id: itemID, x: item.x, y: $0)) }),
                            format: .number).textFieldStyle(.plain).padding(6)
                            .background(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
                    }
                }
                LabeledField(label: "Label") {
                    TextField("", text: Binding(
                        get: { item.label ?? "" },
                        set: { try? document.apply(.renameItemLabel(id: itemID, label: $0.isEmpty ? nil : $0)) }))
                        .textFieldStyle(.plain).padding(6)
                        .background(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
                }
                Toggle("Hidden", isOn: Binding(
                    get: { item.hidden ?? false },
                    set: { try? document.apply(.setItemHidden(id: itemID, hidden: $0)) }))
            } else {
                Text("Item not found").foregroundStyle(Tokens.color(.textTertiary))
            }
        }
    }

    private func commitID() {
        guard idDraft != itemID else { return }
        do {
            try document.apply(.setItemID(old: itemID, new: idDraft))
            idError = nil
        } catch let e as LutinError {
            idError = e.message
            idDraft = itemID
        } catch {
            idError = error.localizedDescription
            idDraft = itemID
        }
    }
}
