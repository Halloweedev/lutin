import SwiftUI
import LutinDocument

public struct BackgroundEditor: View {
    @Bindable var document: LutinProjectDocument
    public init(document: LutinProjectDocument) { self.document = document }
    public var body: some View {
        Text("Background editor (Task 5.5)").font(Typography.chromeSmall)
            .foregroundStyle(Tokens.color(.textTertiary))
    }
}
