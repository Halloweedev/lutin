import SwiftUI
import AppKit

/// Square dropdown picker. Displays the selected label with a trailing
/// chevron-down icon. Tapping opens a Menu of options. No system chevron
/// adornment — we draw our own.
public struct LutinPicker<ID: Hashable>: View {
    public struct Option: Identifiable {
        public let id: ID
        public let label: String
        public init(id: ID, label: String) { self.id = id; self.label = label }
    }

    let selection: Binding<ID>
    let options: [Option]

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(selection: Binding<ID>, options: [Option]) {
        self.selection = selection
        self.options = options
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let baseFill = Tokens.nsColor(.surfaceElevated, appearance: appearance)
        let fill = interaction.resolvedFill(base: baseFill)
        Menu {
            ForEach(options) { opt in
                SwiftUI.Button(opt.label) {  // allow-menu-button: Menu pop-up item
                    selection.wrappedValue = opt.id
                }
            }
        } label: {
            HStack {
                Text(currentLabel)
                    .font(Typography.controlLabel)
                    .foregroundStyle(Tokens.color(.textPrimary))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .padding(.horizontal, Tokens.spacing(.sm))
            .padding(.vertical, Tokens.spacing(.xs))
            .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
    }

    private var currentLabel: String {
        options.first(where: { $0.id == selection.wrappedValue })?.label ?? ""
    }

    func selectForTest(_ id: ID) { selection.wrappedValue = id }
}
