import SwiftUI
import LutinDocument

/// A flat icon button + chevron-down hint that opens a Menu with the three
/// Add items. Anchored to the top-trailing corner of the canvas.
public struct CanvasAddMenu: View {
    @Bindable var document: LutinProjectDocument

    public init(document: LutinProjectDocument) {
        self.document = document
    }

    public var body: some View {
        Menu {
            Button("Add App…") { addLibrary(.app) } // allow-menu-button
            Button("Add Applications folder") { addLibrary(.applications) } // allow-menu-button
            Button("Add Image…") { addLibrary(.image) } // allow-menu-button
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .frame(width: 36, height: 28)
            .background(SquareShape().fill(Tokens.color(.surfaceElevated)))
            .foregroundStyle(Tokens.color(.textPrimary))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func addLibrary(_ item: LibraryItem) {
        let cx = CGFloat(document.config.window?.width ?? 680)
        let cy = CGFloat(document.config.window?.height ?? 420)
        CanvasFileDropDelegate.addLibrary(item,
                                          at: CGPoint(x: cx / 2, y: cy / 2),
                                          document: document)
    }
}
