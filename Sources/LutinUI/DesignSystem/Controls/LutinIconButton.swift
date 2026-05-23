import SwiftUI
import AppKit

/// Square icon button. Bare glyph at rest (no container). On hover/press/focus
/// a filled square appears behind the glyph using the `surfaceElevated` token.
public struct LutinIconButton: View {
    let symbol: Image
    let accessibilityLabel: String
    let action: () -> Void

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

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
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let fill = resolvedFill(appearance: appearance)
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinIconButton
            symbol
                .renderingMode(.template)
                .foregroundStyle(Tokens.color(.textPrimary))
                .frame(width: 28, height: 28)
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
        .focusEffectDisabled()
    }

    /// Resolves the current icon fill from interaction state and system appearance.
    /// Extracted from body so that if/else logic doesn't sit in a @ViewBuilder context.
    private func resolvedFill(appearance: NSAppearance) -> NSColor {
        let interactionFill = Tokens.nsColor(interactionFillKey, appearance: appearance)
        if interaction.isPressed {
            return Tokens.darken(interactionFill, by: ControlInteractionState.pressDarken)
        } else if interaction.isInteracting {
            return interactionFill
        } else {
            return .clear
        }
    }

    var restFillKey: Tokens.Key? { nil }
    var interactionFillKey: Tokens.Key { .surfaceElevated }
    func invokeForTest() { action() }
}
