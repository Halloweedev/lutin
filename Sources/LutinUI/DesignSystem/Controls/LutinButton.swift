import SwiftUI
import AppKit

/// Square-corner text button. Two role variants:
/// - `.primary` — accent fill at rest, the single confirm action in a region.
/// - `.secondary` — surface fill at rest, everything else (cancels, destructives).
///
/// Two initializers: a string-title convenience and a generic-label form for
/// rich custom layouts (HStack with icon + multi-line text, etc).
public struct LutinButton<Label: View>: View {
    public enum Role: String { case primary, secondary }

    let role: Role
    let action: () -> Void
    let label: () -> Label

    @State private var fill: NSColor

    public init(role: Role = .secondary,
                action: @escaping () -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.action = action
        self.label = label
        let base = Tokens.nsColor(role == .primary ? .brandAccent : .surface,
                                  appearance: NSApp?.effectiveAppearance ?? .currentDrawing())
        self._fill = State(initialValue: base)
    }

    public var body: some View {
        let baseFill = Tokens.nsColor(restFillKey,
                                      appearance: NSApp?.effectiveAppearance ?? .currentDrawing())
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinButton
            label()
                .font(Typography.controlLabel)
                .foregroundStyle(Tokens.color(role == .primary ? .textOnAccent : .textPrimary))
                .padding(.horizontal, Tokens.spacing(.md))
                .padding(.vertical, Tokens.spacing(.sm))
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .modifier(ControlInteractionState(onChange: { state in
            fill = state.resolvedFill(base: baseFill)
        }))
    }

    var restFillKey: Tokens.Key { role == .primary ? .brandAccent : .surface }
    func invokeForTest() { action() }
}

extension LutinButton where Label == Text {
    public init(_ title: String, role: Role = .secondary, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}
