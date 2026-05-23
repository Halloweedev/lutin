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
            railButton(systemImage: "tray.full",
                       isSelected: false,
                       tooltip: "Projects… (⌘O)",
                       action: onOpenSwitcher)
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
                .padding(.horizontal, Tokens.spacing(.sm))
            ForEach(EditorTab.allCases, id: \.self) { tab in
                railButton(systemImage: tab.iconName,
                           isSelected: tab == selectedTab,
                           tooltip: tab.title,
                           action: { selectedTab = tab })
            }
            Spacer(minLength: 0)
        }
        .frame(width: Tokens.Size.railWidth)
        // Rail shares the panel's surface color so the two read as one
        // continuous left column. The trailing hairline marks where
        // the tab content actually begins.
        .background(Tokens.color(.panelBackground))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(width: Tokens.Size.hairline)
        }
    }

    private func railButton(systemImage: String,
                            isSelected: Bool,
                            tooltip: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSelected
                                 ? Tokens.color(.brandAccent)
                                 : Tokens.color(.textSecondary))
                .frame(width: Tokens.Size.railWidth, height: 40)
                .background(isSelected
                            ? Tokens.color(.brandAccentMuted)
                            : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
