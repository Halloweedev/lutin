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
        let fill = resolvedFill(appearance: appearance)
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinButton
            label()
                .font(Typography.controlLabel)
                .foregroundStyle(Tokens.color(role == .primary ? .textOnAccent : .textPrimary))
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
        .lutinHitTarget()
    }

    /// Per-role fill resolver. Primary stays on the darken-on-interact
    /// path (`brandAccent` is saturated; darken behaves well). Secondary
    /// swaps to `controlHoverFill` on hover/press — same pattern as
    /// `LutinIconButton` so the two buttons land on identical grey for
    /// interaction. Previously secondary used `darken(surface, …)`,
    /// which coincidentally matched `controlHoverFill` in light mode
    /// (white − 0.08 = 0.92) but produced a near-invisible 0.03 grey on
    /// the 0.11 surface in dark mode, where the icon-button approach
    /// reads cleanly. Now both buttons feel identical across modes.
    private func resolvedFill(appearance: NSAppearance) -> NSColor {
        switch role {
        case .primary:
            let base = Tokens.nsColor(.brandAccent, appearance: appearance)
            return interaction.resolvedFill(base: base)
        case .secondary:
            let hoverFill = Tokens.nsColor(.controlHoverFill, appearance: appearance)
            if interaction.isPressed {
                return Tokens.darken(hoverFill, by: ControlInteractionState.pressDarken)
            }
            if interaction.isInteracting {
                return hoverFill
            }
            return Tokens.nsColor(.surface, appearance: appearance)
        }
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
            // Button titles must never wrap. Without these two, a
            // button title in a narrow column (e.g. a 240pt side
            // panel) breaks character-by-character into a vertical
            // strip of letters. `lineLimit(1)` caps the height to one
            // line, `fixedSize(horizontal: true)` lets the button
            // demand its natural width so the parent HStack can lay it
            // out — or wrap to a second row — but never crush it.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
