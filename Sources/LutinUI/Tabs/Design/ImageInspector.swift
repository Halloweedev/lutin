import SwiftUI
import LutinDocument

public struct ImageInspector: View {
    @Bindable var document: LutinProjectDocument
    let index: Int
    public init(document: LutinProjectDocument, index: Int) {
        self.document = document; self.index = index
    }
    public var body: some View {
        Text("Image inspector (Task 3.10) — #\(index)").font(Typography.chromeSmall)
            .foregroundStyle(Tokens.color(.textTertiary))
    }
}
