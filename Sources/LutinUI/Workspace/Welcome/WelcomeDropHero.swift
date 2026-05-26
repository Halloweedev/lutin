import AppKit
import SwiftUI

/// Primary CTA on the welcome page. A heavy dashed rectangle whose title
/// is the largest interactive type on the page. Picks up the same window-
/// level `.app` drop overlay (rendered by `WelcomeView`) when the user
/// drags a bundle. The two demoted affordances ("browse for an app" and
/// "open existing project") live inline as tertiary text links — they
/// used to be a duplicate dashed tile in the recents grid.
struct WelcomeDropHero: View {
    let onPickApp: (URL) -> Void
    let onOpenExisting: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            LutinButton(action: openPanel) {
                VStack(spacing: Tokens.spacing(.xs)) {
                    Image(systemName: "arrow.down.app")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Tokens.color(.brandAccent))
                    Text("Drop a .app to start a project")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text("We'll scaffold the rest around it.")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
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
                                style: StrokeStyle(lineWidth: 1.5,
                                                   dash: [6, 4]))
                )
                .contentShape(Rectangle())
            }
            .onHover { isHovering = $0 }

            HStack(spacing: 4) {
                Text("or")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                Text("browse for an app")
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.brandAccent))
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                    .onTapGesture { openPanel() }
                Text("·")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
                Text("open existing project")
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.brandAccent))
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                    .onTapGesture { onOpenExisting() }
            }
            .padding(.top, Tokens.spacing(.sm))
        }
    }

    private func openPanel() {
        OpenAppPanel.present { url in
            guard let url else { return }
            onPickApp(url)
        }
    }
}
