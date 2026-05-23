import SwiftUI
import AppKit

/// Square-corner text button. Two role variants:
/// - `.primary` — accent fill at rest, the single confirm action in a region.
/// - `.secondary` — surface fill at rest, everything else (cancels, destructives).
///
/// Two initializers: a string-title convenience (with built-in padding so the
/// button feels button-sized) and a generic-label form for rich custom layouts
/// (callers add their own padding inside the @ViewBuilder closure).
public struct LutinButton<Label: View>: View {
    public enum Role: String { case primary, secondary }

    let role: Role
    let action: () -> Void
    let label: () -> Label

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(role: Role = .secondary,
                action: @escaping () -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.action = action
        self.label = label
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let baseFill = Tokens.nsColor(restFillKey, appearance: appearance)
        let fill = interaction.resolvedFill(base: baseFill)
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinButton
            label()
                .font(Typography.controlLabel)
                .foregroundStyle(Tokens.color(role == .primary ? .textOnAccent : .textPrimary))
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
    }

    var restFillKey: Tokens.Key { role == .primary ? .brandAccent : .surface }
    func invokeForTest() { action() }
}

/// Implementation-detail label used exclusively by `LutinButton(_ title:)`.
/// Public because Swift requires the where-constraint type to be at least as
/// accessible as the init. The underscore prefix signals "do not use directly".
public struct _LutinButtonTitle: View {
    let text: String
    public var body: some View {
        Text(text)
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.vertical, Tokens.spacing(.sm))
    }
}

extension LutinButton where Label == _LutinButtonTitle {
    /// Convenience init for simple string-title buttons. Wraps the text in the
    /// standard control padding so callers don't need to add their own.
    /// Pattern-D callers (generic `@ViewBuilder label:`) control their own padding.
    public init(_ title: String, role: Role = .secondary, action: @escaping () -> Void) {
        self.init(role: role, action: action) { _LutinButtonTitle(text: title) }
    }
}
