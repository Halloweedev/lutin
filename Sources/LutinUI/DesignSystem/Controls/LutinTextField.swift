import SwiftUI
import AppKit

/// Square-corner text input. Faint `surfaceElevated` fill at rest so the
/// field is locatable even without a border. Darkens on focus/hover via the
/// shared `ControlInteractionState`.
public struct LutinTextField: View {
    let prompt: String
    public let text: Binding<String>
    let font: Font

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(_ prompt: String, text: Binding<String>, font: Font = Typography.controlLabel) {
        self.prompt = prompt
        self.text = text
        self.font = font
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let baseFill = Tokens.nsColor(restFillKey, appearance: appearance)
        let fill = interaction.resolvedFill(base: baseFill)
        SwiftUI.TextField(prompt, text: text)  // allow-menu-button: hidden behind LutinTextField
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(Tokens.color(.textPrimary))
            .padding(.horizontal, Tokens.spacing(.sm))
            .padding(.vertical, Tokens.spacing(.xs))
            .background(SquareShape().fill(Color(nsColor: fill)))
            .modifier(ControlInteractionState(onChange: { state in interaction = state }))
    }

    public var restFillKey: Tokens.Key { .surfaceElevated }
}
