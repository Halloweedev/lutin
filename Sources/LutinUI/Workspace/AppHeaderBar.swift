import SwiftUI
import LutinDocument

/// Custom header bar drawn at the top of the workspace. Replaces the
/// macOS title bar (hidden in main.swift via `.windowStyle(.hiddenTitleBar)`).
/// Shows the current section title plus a trailing collapse arrow that
/// hides the side panel — a "Background"-style header, like the
/// reference image.
///
/// The leading inset reserves room for the macOS traffic lights so they
/// don't overlap the title.
public struct AppHeaderBar: View {
    let title: String
    let projectName: String
    @Binding var sidePanelHidden: Bool
    let onTitleTap: () -> Void

    public init(title: String,
                projectName: String,
                sidePanelHidden: Binding<Bool>,
                onTitleTap: @escaping () -> Void) {
        self.title = title
        self.projectName = projectName
        self._sidePanelHidden = sidePanelHidden
        self.onTitleTap = onTitleTap
    }

    public var body: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            // Reserve room for traffic lights (macOS positions them in
            // the window's top-left corner; ~72 pt accommodates the three
            // lights + their margin).
            Spacer().frame(width: 72)

            Button(action: onTitleTap) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text("•")
                        .foregroundStyle(Tokens.color(.textTertiary))
                    Text(projectName)
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.color(.textSecondary))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Tokens.color(.textTertiary))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)

            Spacer()

            Button(action: { sidePanelHidden.toggle() }) {
                Image(systemName: sidePanelHidden
                      ? "sidebar.left"
                      : "chevron.left.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(sidePanelHidden ? "Show side panel" : "Hide side panel")
        }
        .padding(.horizontal, Tokens.spacing(.md))
        .frame(height: 48)
        .background(Tokens.color(.toolbarBackground))
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
