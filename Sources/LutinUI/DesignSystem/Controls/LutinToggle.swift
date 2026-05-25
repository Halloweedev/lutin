import SwiftUI
import AppKit

/// Square checkbox-style toggle. A 14×14 outer square holds an inner 8×8
/// filled square (brand accent) when `isOn`; empty when off. The outer
/// square is bare at rest and gains a `controlHoverFill` fill on interaction
/// (same rule as `LutinIconButton`).
public struct LutinToggle: View {
    let title: String
    let isOn: Binding<Bool>

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self.isOn = isOn
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let interactionFill = Tokens.nsColor(.controlHoverFill, appearance: appearance)
        let boxFill = resolvedBoxFill(interactionFill: interactionFill)
        SwiftUI.Button {  // allow-menu-button: hidden behind LutinToggle
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: Tokens.spacing(.sm)) {
                ZStack {
                    // Interaction fill (hover/press tint). Sits behind
                    // the border so the box stays visibly bounded even
                    // when the fill is `.clear` at rest.
                    SquareShape()
                        .fill(Color(nsColor: boxFill))
                        .frame(width: 14, height: 14)
                    // Always-on hairline border — without it the toggle
                    // is invisible at rest (#screenshot 12:44:39). Uses
                    // the divider token to match other chrome edges.
                    SquareShape()
                        .stroke(Tokens.color(.divider),
                                lineWidth: Tokens.Size.hairline)
                        .frame(width: 14, height: 14)
                    SquareShape()
                        .fill(Tokens.color(.brandAccent))
                        .frame(width: 8, height: 8)
                        .opacity(isOn.wrappedValue ? 1 : 0)
                }
                Text(title)
                    .font(Typography.controlLabel)
                    .foregroundStyle(Tokens.color(.textPrimary))
            }
        }
        .buttonStyle(.plain)
        // Focus-ring suppression is owned by `ControlInteractionState`
        // (after its `.focusable()`); applying it here would land in the
        // wrong subtree — see ControlStates.swift.
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
        // The 14pt checkbox + text row is only ~17pt tall on its own,
        // well below the 28pt hit-target floor. `lutinHitTarget()` grows
        // the click area to 28pt with the visible chrome centered.
        .lutinHitTarget()
    }

    private func resolvedBoxFill(interactionFill: NSColor) -> NSColor {
        if interaction.isPressed {
            return Tokens.darken(interactionFill, by: ControlInteractionState.pressDarken)
        } else if interaction.isInteracting {
            return interactionFill
        } else {
            return .clear
        }
    }

    func toggleForTest() { isOn.wrappedValue.toggle() }
}
