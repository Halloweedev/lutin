import SwiftUI
import AppKit

/// Square-corner numeric input. Same visual as `LutinTextField` but bound to
/// a parseable numeric value with a format. Used for inspector coordinate
/// fields (item x/y, image w/h) where free-text isn't appropriate.
public struct LutinNumericField<Value, F>: View
    where F: ParseableFormatStyle, F.FormatInput == Value, F.FormatOutput == String {

    let prompt: String
    let value: Binding<Value>
    let format: F

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(_ prompt: String, value: Binding<Value>, format: F) {
        self.prompt = prompt
        self.value = value
        self.format = format
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let baseFill = Tokens.nsColor(.surfaceElevated, appearance: appearance)
        let fill = interaction.resolvedFill(base: baseFill)
        SwiftUI.TextField(prompt, value: value, format: format)  // allow-menu-button: hidden behind LutinNumericField
            .textFieldStyle(.plain)
            .font(Typography.controlLabel)
            .foregroundStyle(Tokens.color(.textPrimary))
            .padding(.horizontal, Tokens.spacing(.sm))
            .padding(.vertical, Tokens.spacing(.xs))
            .background(SquareShape().fill(Color(nsColor: fill)))
            .modifier(ControlInteractionState(onChange: { state in interaction = state }))
    }

    var restFillKey: Tokens.Key { .surfaceElevated }
}
