import SwiftUI
import LutinDocument

public struct ImageDecorationLayer: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document; self.selectionModel = selectionModel
    }
    public var body: some View { EmptyView() }
}
