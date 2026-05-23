import SwiftUI

public struct EditorRail: View {
    @Binding var selectedTab: EditorTab
    let onOpenSwitcher: () -> Void

    public init(selectedTab: Binding<EditorTab>, onOpenSwitcher: @escaping () -> Void) {
        self._selectedTab = selectedTab
        self.onOpenSwitcher = onOpenSwitcher
    }

    public var body: some View {
        VStack(spacing: 0) {
            brandEmblem
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
                .padding(.horizontal, 8)
            VStack(spacing: 4) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    railButton(systemImage: tab.iconName,
                               isSelected: tab == selectedTab,
                               tooltip: tab.title,
                               action: { selectedTab = tab })
                }
            }
            .padding(.vertical, Tokens.spacing(.sm))
            Spacer(minLength: 0)
            // Settings cog pinned to the bottom of the rail.
            railButton(systemImage: "gearshape",
                       isSelected: false,
                       tooltip: "Preferences (⌘,)",
                       action: openPreferences)
                .padding(.bottom, Tokens.spacing(.sm))
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

    /// Brand mark — clickable, opens the Project Switcher just like
    /// clicking the title in the header does.
    private var brandEmblem: some View {
        Button(action: onOpenSwitcher) {
            ZStack {
                SquareShape()
                    .fill(Tokens.color(.brandAccent))
                    .frame(width: 28, height: 28)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, Tokens.spacing(.sm))
            .frame(width: Tokens.Size.railWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Projects… (⌘O)")
    }

    private func railButton(systemImage: String,
                            isSelected: Bool,
                            tooltip: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    SquareShape()
                        .fill(Tokens.color(.brandAccentMuted))
                        .frame(width: 32, height: 32)
                }
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected
                                     ? Tokens.color(.brandAccent)
                                     : Tokens.color(.textSecondary))
            }
            .frame(width: Tokens.Size.railWidth, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    /// Opens the macOS Preferences scene via the standard menu action.
    /// macOS handles routing this to the `Settings { }` declared in
    /// LutinApp.main.
    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
