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
        Text("Arrow inspector (Task 3.9) — \(from)→\(to)").font(Typography.chromeSmall)
            .foregroundStyle(Tokens.color(.textTertiary))
    }
}
