import SwiftUI
import LutinDocument

public struct DesignTab: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    LibrarySection()
                    Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
                    LayersSection(document: document, selectionModel: selectionModel)
                    Divider().frame(height: Tokens.Size.hairline).background(Tokens.color(.divider))
                    InspectorSection(document: document, selectionModel: selectionModel)
                    Spacer(minLength: 0)
                }
            }
            OffCanvasStatusStrip(document: document, selectionModel: selectionModel)
        }
    }
}
