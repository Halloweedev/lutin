import AppKit
import SwiftUI
import UniformTypeIdentifiers
import LutinRegistry
import LutinDocument

/// Welcome page: brand mark, a clean drop area, quiet Create/Open
/// text links, a compact doctor strip, and a grid of recent projects
/// led by a `+ New project` card.
public struct WelcomeView: View {
    @Environment(RegistryStore.self) private var registryStore
    @Environment(CredentialsStore.self) private var credentialsStore

    let onCreateNew: () -> Void
    let onOpenExisting: () -> Void
    let onSelectRecent: (String) -> Void
    let onDropApp: (URL) -> Void
    let onPickApp: (URL) -> Void
    let onOpenDoctor: () -> Void

    @State private var isDropTargeted = false

    public init(onCreateNew: @escaping () -> Void,
                onOpenExisting: @escaping () -> Void,
                onSelectRecent: @escaping (String) -> Void,
                onDropApp: @escaping (URL) -> Void,
                onPickApp: @escaping (URL) -> Void,
                onOpenDoctor: @escaping () -> Void) {
        self.onCreateNew = onCreateNew
        self.onOpenExisting = onOpenExisting
        self.onSelectRecent = onSelectRecent
        self.onDropApp = onDropApp
        self.onPickApp = onPickApp
        self.onOpenDoctor = onOpenDoctor
    }

    private var recentEntries: [RegistryEntryStatus] {
        Array(registryStore.entries
            .sorted { $0.entry.lastOpenedDate > $1.entry.lastOpenedDate }
            .prefix(10))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Tokens.spacing(.xl)) {
                hero
                if !recentEntries.isEmpty {
                    WelcomeRecentsGrid(
                        entries: recentEntries,
                        onCreateNew: onCreateNew,
                        onSelect: onSelectRecent,
                        onReveal: revealInFinder,
                        onRemove: { name in try? registryStore.remove(name: name) })
                        .frame(maxWidth: 720)
                }
            }
            .padding(.top, Tokens.spacing(.xl) * 2)
            .padding(.bottom, Tokens.spacing(.xl))
            .padding(.horizontal, Tokens.spacing(.xl))
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.color(.canvasBackground).ignoresSafeArea())
        .overlay {
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

    private var hero: some View {
        VStack(spacing: Tokens.spacing(.lg)) {
            brandMark
            WelcomeDropHero(onPickApp: onPickApp)
            quietActions
            WelcomeDoctorStrip(
                hasCodesign: credentialsStore.hasCodesign,
                hasDeveloperIDIdentity: !credentialsStore.hasNoDeveloperIDIdentity,
                onOpenDoctor: onOpenDoctor)
        }
        .frame(maxWidth: 460)
    }

    private var brandMark: some View {
        VStack(spacing: Tokens.spacing(.xs)) {
            appGlyph
            Text("Lutin")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Tokens.color(.textPrimary))
            Text("Visual editor for macOS DMG layouts")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
        }
    }

    private var appGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(
                    colors: [Tokens.color(.brandAccent),
                             Tokens.color(.brandAccent).opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .shadow(color: Tokens.color(.brandAccent).opacity(0.25),
                        radius: 8, y: 3)
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
        }
    }

    private var quietActions: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            quietLink(icon: "plus",
                      title: "Create new",
                      shortcut: "⌘N",
                      action: onCreateNew)
            Text("·")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
            quietLink(icon: "folder",
                      title: "Open existing…",
                      shortcut: "⌘O",
                      action: onOpenExisting)
        }
    }

    private func quietLink(icon: String, title: String, shortcut: String,
                           action: @escaping () -> Void) -> some View {
        LutinButton(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(Typography.chromeSmall)
                Text(shortcut)
                    .font(Typography.chromeSmall.monospaced())
                    .foregroundStyle(Tokens.color(.textTertiary))
            }
            .foregroundStyle(Tokens.color(.brandAccent))
            .contentShape(Rectangle())
        }
    }

    private func revealInFinder(_ entry: RegistryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting(
            [URL(fileURLWithPath: entry.configPath)])
    }
}
