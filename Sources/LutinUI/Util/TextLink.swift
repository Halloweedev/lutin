import SwiftUI
import AppKit

extension View {
    /// Turns a text view (or any inline view) into a tappable text link:
    /// hairline tap target around the bounds, pointing-hand cursor on
    /// hover, fires `action` on tap. Use for tertiary inline links that
    /// should NOT carry the chrome of a `LutinButton`.
    func textLink(action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .onTapGesture(perform: action)
    }
}
