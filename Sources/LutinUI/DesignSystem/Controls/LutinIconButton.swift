import SwiftUI
import AppKit

/// Square icon button. Bare glyph at rest (no container). On hover/press/focus
/// a filled square appears behind the glyph using the `controlHoverFill` token
/// (a clearly-grey tile against the pure-white chrome).
public struct LutinIconButton: View {
    private enum Glyph {
        /// SF Symbol; sized by the SwiftUI font context (matches `.body`).
        case symbol(Image)
        /// Asset-catalog image; explicit point size so the glyph fits the
        /// 28×28 hit frame the same way an SF Symbol naturally does.
        case asset(Image)
    }

    private let glyph: Glyph
    let accessibilityLabel: String
    let action: () -> Void

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    public init(asset: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.glyph = .asset(Image(asset, bundle: LutinAssets.bundle)
            .renderingMode(.template))
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public init(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.glyph = .symbol(Image(systemName: systemName).renderingMode(.template))
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let fill = resolvedFill(appearance: appearance)
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind LutinIconButton
            renderedGlyph
                .foregroundStyle(Tokens.color(.textPrimary))
                .frame(width: 28, height: 28)
                .background(SquareShape().fill(Color(nsColor: fill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
        // 28×28 frame already meets `Tokens.Size.controlHeight`; this is
        // mainly here for the rectangular `contentShape` — clicks at the
        // exact corner of the square otherwise miss the SF Symbol path.
        .lutinHitTarget()
    }

    @ViewBuilder
    private var renderedGlyph: some View {
        switch glyph {
        case .symbol(let img):
            img
        case .asset(let img):
            // Phosphor-style SVGs ship with a 32×32 viewBox and render at
            // that natural size unless we constrain them. Match an SF
            // Symbol's optical weight inside a 28×28 hit area.
            img.resizable().scaledToFit().frame(width: 16, height: 16)
        }
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
    var interactionFillKey: Tokens.Key { .controlHoverFill }
    func invokeForTest() { action() }
}
