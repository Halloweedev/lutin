import SwiftUI
import AppKit

/// Narrow left rail holding the four editor-tab buttons. The project
/// switcher lives in the SidePanel's top row as a name + chevron
/// dropdown — having a second opener here (a brand emblem at the top)
/// duplicated the affordance, so it was removed.
public struct EditorRail: View {
    @Binding var selectedTab: EditorTab

    public init(selectedTab: Binding<EditorTab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top-of-rail slot reserved for the Lutin brand logo.
            LogoSlot()
            // Tab buttons. Each row carries a top hairline so the rail
            // reads as a sequence of cleanly separated cells — same
            // pattern as the trailing rail divider and the section
            // dividers in tab content. No inter-row spacing; the
            // hairline does the visual separation work.
            ForEach(EditorTab.allCases, id: \.self) { tab in
                RailButton(asset: tab.iconName,
                           isSelected: tab == selectedTab,
                           tooltip: tab.title,
                           action: { selectedTab = tab })
                    .modifier(RailRowDivider())
            }
            Spacer(minLength: 0)
        }
        .frame(width: Tokens.Size.railWidth)
        // Rail shares the panel's surface color so the two read as one
        // continuous left column. The trailing hairline marks where the
        // tab content actually begins.
        .background(Tokens.color(.panelBackground))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(width: Tokens.Size.hairline)
        }
    }
}

/// Brand mark pinned at the top of the rail. Renders the Lutin logo
/// as a template image tinted with `brandAccent` so it stays black on
/// light surfaces and white in dark mode without per-appearance swaps.
/// Non-interactive — navigation lives in the tab buttons and project
/// switcher below.
///
/// The slot is `railWidth × railWidth` so it shares the rail's grid
/// with the tab buttons.
private struct LogoSlot: View {
    var body: some View {
        Image("LutinLogo", bundle: LutinAssets.bundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundStyle(Tokens.color(.brandAccent))
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Size.railWidth)
            .accessibilityLabel("Lutin")
    }
}

/// 1pt hairline at the top of each rail row, in the standard divider
/// color. Pulled into a `ViewModifier` so the call sites stay tidy and
/// every rail divider in the app reads as one design token rather than
/// multiple inline overlays with subtly different colors/heights.
private struct RailRowDivider: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }
}

/// A single rail row. Full-width (left edge → trailing divider) fill states:
///   • selected → `brandAccent` background, `textOnAccent` glyph
///   • hover    → `controlHoverFill` background, `textPrimary` glyph
///   • rest     → clear background, `textPrimary` glyph
///
/// No 3pt accent stripe — the entire row acts as the selection indicator.
/// Press darkens the active fill (selected → darker accent; hover → darker
/// grey) so users get the same press feedback in both states.
private struct RailButton: View {
    let asset: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void

    @State private var interaction = ControlInteractionState.State(
        isHovered: false, isPressed: false, isFocused: false)

    var body: some View {
        let appearance = NSApp?.effectiveAppearance ?? .currentDrawing()
        let bg = resolvedBackground(appearance: appearance)
        let fg = resolvedForeground()
        // Row height equals the rail width (`Tokens.Size.railWidth = 44`)
        // so the selected fill draws a true square from left edge to the
        // trailing divider. The visual indicator and the hit target are
        // the same surface — no inner padding to mistime hover/selection.
        SwiftUI.Button(action: action) {  // allow-menu-button: hidden behind RailButton
            Image(asset, bundle: LutinAssets.bundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.Size.railWidth)
                .background(bg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tooltip)
        .help(tooltip)
        .modifier(ControlInteractionState(onChange: { state in interaction = state }))
        .lutinHitTarget(minHeight: Tokens.Size.railWidth)
    }

    private func resolvedBackground(appearance: NSAppearance) -> Color {
        if isSelected {
            let base = Tokens.nsColor(.brandAccent, appearance: appearance)
            return Color(nsColor: interaction.resolvedFill(base: base))
        }
        if interaction.isPressed {
            let hover = Tokens.nsColor(.controlHoverFill, appearance: appearance)
            return Color(nsColor: Tokens.darken(hover, by: ControlInteractionState.pressDarken))
        }
        if interaction.isInteracting {
            return Tokens.color(.controlHoverFill)
        }
        return .clear
    }

    private func resolvedForeground() -> Color {
        isSelected ? Tokens.color(.textOnAccent) : Tokens.color(.textPrimary)
    }
}
