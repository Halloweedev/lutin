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
        LutinIconButton(systemName: "shippingbox.fill",
                        accessibilityLabel: "Open project switcher",
                        action: onOpenSwitcher)
        .frame(height: 28)
        .help("Projects… (⌘O)")
    }

    private func railButton(systemImage: String,
                            isSelected: Bool,
                            tooltip: String,
                            action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? Tokens.color(.brandAccent) : Color.clear)
                .frame(width: 3, height: 28)
            LutinIconButton(systemName: systemImage,
                            accessibilityLabel: tooltip,
                            action: action)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 28)
        .help(tooltip)
    }

    /// Opens the macOS Preferences scene via the standard menu action.
    /// macOS handles routing this to the `Settings { }` declared in
    /// LutinApp.main.
    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
