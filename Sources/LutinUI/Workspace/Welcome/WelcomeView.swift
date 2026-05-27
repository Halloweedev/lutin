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

    let onOpenExisting: () -> Void
    let onSelectRecent: (String) -> Void
    let onDropApp: (URL) -> Void
    let onPickApp: (URL) -> Void

    @State private var isDropTargeted = false

    public init(onOpenExisting: @escaping () -> Void,
                onSelectRecent: @escaping (String) -> Void,
                onDropApp: @escaping (URL) -> Void,
                onPickApp: @escaping (URL) -> Void) {
        self.onOpenExisting = onOpenExisting
        self.onSelectRecent = onSelectRecent
        self.onDropApp = onDropApp
        self.onPickApp = onPickApp
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
                WelcomeRecentsGrid(
                    entries: recentEntries,
                    onSeeAll: onOpenExisting,
                    onSelect: onSelectRecent,
                    onReveal: revealInFinder,
                    onRemove: { name in try? registryStore.remove(name: name) })
                    .frame(maxWidth: 720)
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
            WelcomeDropHero(onPickApp: onPickApp,
                            onOpenExisting: onOpenExisting)
        }
        .frame(maxWidth: 460)
    }

    private var brandMark: some View {
        VStack(spacing: Tokens.spacing(.xs)) {
            appGlyph
            Text("WELCOME BACK")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Tokens.color(.textTertiary))
            Text("Lutin")
                .font(.system(size: 32, weight: .ultraLight))
                .tracking(-0.5)
                .foregroundStyle(Tokens.color(.textPrimary))
            Text("Visual editor for macOS DMG layouts")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textTertiary))
        }
    }

    private var appGlyph: some View {
        Image("LutinLogo", bundle: LutinAssets.bundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .foregroundStyle(Tokens.color(.brandAccent))
    }

    private func revealInFinder(_ entry: RegistryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting(
            [URL(fileURLWithPath: entry.configPath)])
    }
}
