import SwiftUI
import UniformTypeIdentifiers
import LutinRegistry
import LutinDocument

/// Empty-state welcome card. Two CTAs (Create / Open) and a Recent
/// projects list sourced from the live `RegistryStore`. Replaces the
/// plain placeholder shown when no project is loaded.
public struct WelcomeView: View {
    @Environment(RegistryStore.self) private var registryStore
    @Environment(CredentialsStore.self) private var credentialsStore
    let onCreateNew: () -> Void
    let onOpenExisting: () -> Void
    let onSelectRecent: (String) -> Void
    let onDropApp: (URL) -> Void
    @State private var isDropTargeted = false

    public init(onCreateNew: @escaping () -> Void,
                onOpenExisting: @escaping () -> Void,
                onSelectRecent: @escaping (String) -> Void,
                onDropApp: @escaping (URL) -> Void) {
        self.onCreateNew = onCreateNew
        self.onOpenExisting = onOpenExisting
        self.onSelectRecent = onSelectRecent
        self.onDropApp = onDropApp
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Tokens.spacing(.xl)) {
                header
                ctaCard
                credentialsBanner
                recents
            }
            .frame(maxWidth: 520)
            .padding(.top, Tokens.spacing(.xl) * 2)
            .padding(.bottom, Tokens.spacing(.xl))
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.color(.canvasBackground).ignoresSafeArea())
        .overlay {
            // Drop-target highlight: covers the whole pane in brand accent
            // when the user is hovering a .app over the window.
            if isDropTargeted {
                Rectangle()
                    .strokeBorder(Tokens.color(.brandAccent), lineWidth: 3)
                    .background(Tokens.color(.brandAccentMuted))
                    .overlay {
                        VStack(spacing: Tokens.spacing(.xs)) {
                            Image(systemName: "arrow.down.app")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(Tokens.color(.brandAccent))
                            Text("Drop to create project")
                                .font(Typography.chrome)
                                .foregroundStyle(Tokens.color(.brandAccent))
                        }
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "app" else { return }
                DispatchQueue.main.async { onDropApp(url) }
            }
            return true
        }
    }

    private var header: some View {
        VStack(spacing: Tokens.spacing(.xs)) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Tokens.color(.brandAccent))
            Text("Lutin")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Tokens.color(.textPrimary))
            Text("Visual editor for macOS DMG layouts")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
    }

    private var ctaCard: some View {
        VStack(spacing: 0) {
            ctaRow(icon: "plus.square",
                   title: "Create new project",
                   subtitle: "Start with a fresh lutin.yml under ~/Lutin/<name>/",
                   shortcut: "⌘N",
                   action: onCreateNew)
            Rectangle()
                .fill(Tokens.color(.divider))
                .frame(height: Tokens.Size.hairline)
            ctaRow(icon: "folder",
                   title: "Open existing project…",
                   subtitle: "Pick a lutin.yml or use the project switcher",
                   shortcut: "⌘O",
                   action: onOpenExisting)
        }
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider),
                                      lineWidth: Tokens.Size.hairline))
    }

    private func ctaRow(icon: String, title: String, subtitle: String,
                        shortcut: String, action: @escaping () -> Void) -> some View {
        LutinButton(role: .secondary, action: action) {
            HStack(spacing: Tokens.spacing(.md)) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Tokens.color(.brandAccent))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.chrome)
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text(subtitle).font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                }
                Spacer()
                Text(shortcut).font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
            .padding(.horizontal, Tokens.spacing(.lg))
            .padding(.vertical, Tokens.spacing(.md))
            .contentShape(Rectangle())
        }
    }

    /// Subtle banner shown when the user has no Developer ID Application
    /// certificate in their Keychain. Hidden once at least one is
    /// present. Notary-profile presence isn't checked here — Lutin
    /// can't enumerate notarytool's keychain entries (ACL-restricted to
    /// its signing team), so we'd have to either guess or harass. The
    /// notary side is surfaced inside the Release tab where the user
    /// can either type a name + press Test, or create one with the
    /// in-app sheet.
    @ViewBuilder
    private var credentialsBanner: some View {
        if credentialsStore.hasNoDeveloperIDIdentity {
            HStack(alignment: .top, spacing: Tokens.spacing(.sm)) {
                // Status glyph + color sourced from the shared
                // `StatusKind.warn` token — same icon/color the Doctor
                // sheet draws for an equivalent warning.
                Image(systemName: StatusKind.warn.systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(StatusKind.warn.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Developer ID Application certificate found")
                        .font(Typography.chromeSmall.weight(.medium))
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text("You can still Build unsigned DMGs. Release-mode builds (signed + notarized) require a Developer ID Application certificate from developer.apple.com — import it via Keychain Access, then come back here.")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Tokens.spacing(.md))
            .overlay(SquareShape().stroke(Tokens.color(.logProgress).opacity(0.4),
                                          lineWidth: Tokens.Size.hairline))
        }
    }

    @ViewBuilder
    private var recents: some View {
        let entries = Array(
            registryStore.entries
                .map(\.entry)
                .sorted { $0.lastOpenedDate > $1.lastOpenedDate }
                .prefix(5))
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent")
                    .font(Typography.chromeSmall.weight(.medium))
                    .foregroundStyle(Tokens.color(.textSecondary))
                    .padding(.horizontal, Tokens.spacing(.md))
                    .padding(.bottom, Tokens.spacing(.xs))
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.name) { idx, entry in
                        recentRow(entry: entry)
                        if idx < entries.count - 1 {
                            Rectangle()
                                .fill(Tokens.color(.divider))
                                .frame(height: Tokens.Size.hairline)
                        }
                    }
                }
                .background(Tokens.color(.panelBackground))
                .overlay(SquareShape().stroke(Tokens.color(.divider),
                                              lineWidth: Tokens.Size.hairline))
            }
        }
    }

    private func recentRow(entry: RegistryEntry) -> some View {
        LutinButton(role: .secondary, action: { onSelectRecent(entry.name) }) {
            HStack(spacing: Tokens.spacing(.sm)) {
                ZStack {
                    SquareShape()
                        .stroke(Tokens.color(.divider),
                                lineWidth: Tokens.Size.hairline)
                        .frame(width: 24, height: 24)
                    Text(String(entry.name.prefix(1)).uppercased())
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textSecondary))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textPrimary))
                    Text(entry.configPath).font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.textTertiary))
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(entry.lastOpenedDate, format: .relative(presentation: .named))
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
            .padding(.horizontal, Tokens.spacing(.md))
            .padding(.vertical, Tokens.spacing(.sm))
            .contentShape(Rectangle())
        }
    }
}
