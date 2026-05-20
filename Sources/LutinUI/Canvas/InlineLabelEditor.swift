import SwiftUI
import LutinDocument

public struct InlineLabelEditor: View {
    @Bindable var document: LutinProjectDocument
    let itemID: String
    @Binding var isEditing: Bool
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    public init(document: LutinProjectDocument, itemID: String, isEditing: Binding<Bool>) {
        self.document = document
        self.itemID = itemID
        self._isEditing = isEditing
    }

    public var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(Typography.canvasLabel)
            .focused($focused)
            .onAppear {
                draft = document.config.items?.first { $0.id == itemID }?.label ?? ""
                focused = true
            }
            .onSubmit { commit() }
            .onKeyPress(.escape) { isEditing = false; return .handled }
    }

    private func commit() {
        try? document.apply(.renameItemLabel(id: itemID, label: draft.isEmpty ? nil : draft))
        isEditing = false
    }
}
