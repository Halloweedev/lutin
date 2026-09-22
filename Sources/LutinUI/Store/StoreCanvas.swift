import SwiftUI

/// The Store tab's canvas: the product page, at the size and proportions of the
/// chosen device.
///
/// Same relationship `CanvasView` has to the DMG window preview — the canvas
/// shows the artefact, the column holds the knobs.
public struct StoreCanvas: View {
    let state: StoreTabState

    public init(state: StoreTabState) {
        self.state = state
    }

    public var body: some View {
        // Vertical only: a horizontal ScrollView proposes unbounded width to its
        // content, which would let the page take its full 680 and get clipped by
        // the window instead of shrinking into it.
        ScrollView(.vertical) {
            ProductPagePreview(model: state.previewModel, assets: state.assets)
                .padding(28)
                .frame(maxWidth: .infinity)
        }
        .background(Tokens.color(.canvasBackground))
    }
}
