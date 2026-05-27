import SwiftUI

/// Fixed-width side panel. Users can hide the whole panel via the
/// workspace's hide-sidebar button, but the width itself isn't draggable
/// any more — the panel opens at `Tokens.Size.sidePanelDefault` and stays
/// there, which keeps long settings labels and inline token chips from
/// crowding when the user happens to have shrunk the panel in a prior
/// session.
public struct SidePanel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            content
                .frame(width: Tokens.Size.sidePanelDefault)
                .background(Tokens.color(.panelBackground))
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(width: Tokens.Size.hairline)
        }
    }
}
