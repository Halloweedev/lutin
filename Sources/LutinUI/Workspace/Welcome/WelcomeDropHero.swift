import SwiftUI

/// Clean drop affordance on the welcome page. A plain dashed rectangle
/// that says "Drop a .app to import it." Clicking opens an
/// `NSOpenPanel` filtered to `.app`. The window-level drop overlay
/// (rendered by `WelcomeView`) still handles the actual drag.
struct WelcomeDropHero: View {
    let onPickApp: (URL) -> Void

    @State private var isHovering = false

    var body: some View {
        SwiftUI.Button(action: openPanel) {
            VStack(spacing: Tokens.spacing(.xs)) {
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Tokens.color(.brandAccent))
                Text("Drop a .app to import it")
                    .font(Typography.chrome.weight(.medium))
                    .foregroundStyle(Tokens.color(.textPrimary))
                Text("We'll scaffold a new project around it.")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textSecondary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.spacing(.xl))
            .padding(.horizontal, Tokens.spacing(.lg))
            .background(isHovering
                        ? Tokens.color(.brandAccentMuted).opacity(0.5)
                        : Tokens.color(.panelBackground))
            .overlay(
                SquareShape()
                    .stroke(isHovering
                            ? Tokens.color(.brandAccent)
                            : Tokens.color(.divider),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private func openPanel() {
        OpenAppPanel.present { url in
            guard let url else { return }
            onPickApp(url)
        }
    }
}
