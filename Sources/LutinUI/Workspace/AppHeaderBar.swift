import SwiftUI

/// Thin bar at the very top of the workspace that reserves space for the
/// macOS traffic lights (close / minimise / zoom). The title bar is hidden
/// via `.windowStyle(.hiddenTitleBar)` in main.swift; macOS still draws the
/// three buttons in the window's top-left corner and needs ~72 pt of clear
/// horizontal space so they don't overlap workspace chrome.
///
/// All interactive content that used to live here (project switcher dropdown,
/// sidebar-collapse toggle) moved into the SidePanel's top row (Item L).
public struct AppHeaderBar: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Traffic-light reservation — macOS draws close/min/max here when
            // the title bar is transparent. Empty content; the chrome that
            // used to live here moved into the SidePanel.
            Spacer().frame(width: 72)
            Spacer()
        }
        .frame(height: 28)
        .background(Tokens.color(.panelBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
        }
    }
}

/// Smaller header drawn just above the side panel content. Names the
/// active tab so the panel always knows what it's showing.
public struct PanelHeader: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Tokens.color(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.spacing(.lg))
            .padding(.top, Tokens.spacing(.lg))
            .padding(.bottom, Tokens.spacing(.md))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.color(.divider))
                    .frame(height: Tokens.Size.hairline)
            }
    }
}
