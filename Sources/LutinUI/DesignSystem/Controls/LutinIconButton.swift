import SwiftUI
import AppKit

/// Square icon button. Bare glyph at rest (no container). On hover/press/focus
/// a filled square appears behind the glyph using the `surfaceElevated` token.
public struct LutinIconButton: View {
    let symbol: Image
    let accessibilityLabel: String
    let action: () -> Void

    @State private var fill: NSColor = .clear

    public init(asset: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.symbol = Image(asset, bundle: .module)
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public init(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.symbol = Image(systemName: systemName)
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        let interactionFill = Tokens.nsColor(interactionFillKey,
                                             appearance: NSApp?.effectiveAppearance ?? .currentDrawing())
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinIconButton
            symbol
                .renderingMode(.template)
                .foregroundStyle(Tokens.color(.textPrimary))
                .frame(width: 28, height: 28)
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(ControlInteractionState(onChange: { state in
            if state.isPressed {
                fill = Tokens.darken(interactionFill, by: ControlInteractionState.pressDarken)
            } else if state.isInteracting {
                fill = interactionFill
            } else {
                fill = .clear
            }
        }))
    }

    var restFillKey: Tokens.Key? { nil }
    var interactionFillKey: Tokens.Key { .surfaceElevated }
    func invokeForTest() { action() }
}
