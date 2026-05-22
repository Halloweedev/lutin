import SwiftUI
import LutinDocument

public struct ItemInspector: View {
    @Bindable var document: LutinProjectDocument
    let itemID: String
    public init(document: LutinProjectDocument, itemID: String) {
        self.document = document; self.itemID = itemID
    }
    public var body: some View {
        Text("Item inspector (Task 3.8) — \(itemID)").font(Typography.chromeSmall)
            .foregroundStyle(Tokens.color(.textTertiary))
    }
}
