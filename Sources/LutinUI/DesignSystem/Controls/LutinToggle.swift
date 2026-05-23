import SwiftUI
import AppKit

/// Square checkbox-style toggle. A 14×14 outer square holds an inner 8×8
/// filled square (brand accent) when `isOn`; empty when off. The outer
/// square is bare at rest and gains a `surfaceElevated` fill on interaction
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
        let interactionFill = Tokens.nsColor(.surfaceElevated, appearance: appearance)
        let boxFill = resolvedBoxFill(interactionFill: interactionFill)
        SwiftUI.Button {  // allow-menu-button: hidden behind LutinToggle
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: Tokens.spacing(.sm)) {
                ZStack {
                    SquareShape()
                        .fill(Color(nsColor: boxFill))
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
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
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
