import SwiftUI
import LutinCore
import LutinConfig
import LutinRegistry
import LutinDocument

public struct WorkspaceShell: View {
    @State private var registryStore = RegistryStore()
    @State private var preferencesStore = PreferencesStore()
    @State private var editorStateStore = EditorStateStore()
    @State private var credentialsStore = CredentialsStore()
    @State private var selectedEntryName: String?
    @State private var document: LutinProjectDocument?
    @State private var loadError: String?
    @State private var showSwitcher = false
    @State private var showCreateNew = false
    @State private var preselectedDropURL: URL?
    @State private var showingDoctor = false
    @State private var sidePanelHidden = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 14pt traffic-light strip — paired with the
            // `TrafficLightPositioner` below to nudge the standard
            // window buttons up by ~6pt so the 12pt glyphs fit inside
            // the strip and clear its bottom hairline. The strip
            // preserves the title-zone separation; halving from 22pt
            // → 14pt saves 8pt of top chrome without losing the
            // visual break.
            AppHeaderBar()
            Group {
                if let document {
                    ProjectWorkspace(document: document,
                                     projectName: currentProjectName,
                                     editorState: editorStateStore.state(forConfigPath: document.configURL.path),
                                     showingDoctor: $showingDoctor,
                                     sidePanelHidden: $sidePanelHidden)
                } else if let loadError {
                    EmptyState(title: "Could not load project", message: loadError, icon: "EmptySelection")
                } else {
                    WelcomeView(
                        onCreateNew: { showCreateNew = true },
                        onOpenExisting: { showSwitcher = true },
                        onSelectRecent: { name in selectedEntryName = name },
                        onDropApp: { url in
                            preselectedDropURL = url
                            showCreateNew = true
                        })
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .tint(Tokens.color(.brandAccent))
        .background {
            // Hidden button to wire ⌘N globally without claiming a visible
            // toolbar slot — same pattern other commands use.
            LutinButton("New project", role: .primary) { showCreateNew = true }
                .keyboardShortcut("n", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            // Shift the macOS standard window buttons up by ~6pt so
            // they fit inside the 14pt AppHeaderBar (default position
            // assumes a 22pt title bar). See `TrafficLightPositioner`
            // — re-applies on every window state change.
            TrafficLightPositioner(buttonOriginY: 9)
                .frame(width: 0, height: 0)
        }
        .sheet(isPresented: $showSwitcher) {
            ProjectSwitcherModal(
                selectedEntryName: $selectedEntryName,
                onAddNewProject: {
                    // SwiftUI dismisses the switcher first; defer the
                    // Create sheet by a runloop so the second sheet
                    // doesn't fight the first sheet's dismiss animation.
                    DispatchQueue.main.async { showCreateNew = true }
                })
                .environment(registryStore)
        }
        .sheet(isPresented: $showCreateNew, onDismiss: { preselectedDropURL = nil }) {
            CreateProjectSheet(preselectedAppURL: preselectedDropURL) { url, entryName in
                try? registryStore.add(configURL: url)
                selectedEntryName = entryName
            }
        }
        .environment(registryStore)
        .environment(preferencesStore)
        .environment(editorStateStore)
        .environment(credentialsStore)
        .task {
            try? registryStore.reload()
            try? preferencesStore.reload()
        }
        .onChange(of: selectedEntryName) { _, name in
            loadDocument(named: name)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinSave)) { _ in
            try? document?.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinUndo)) { _ in document?.undo() }
        .onReceive(NotificationCenter.default.publisher(for: .lutinRedo)) { _ in document?.redo() }
        .onReceive(NotificationCenter.default.publisher(for: .lutinOpenSwitcher)) { _ in
            showSwitcher = true
        }
    }

    /// Display name for the side-panel project switcher.
    ///
    /// Prefers the loaded document's `config.project.name` so that edits
    /// made in the Project tab (or anywhere else that calls
    /// `.setProjectName` / `.setProjectMetadata`) update the visible label
    /// immediately. Falls back to the registry entry name when no document
    /// is loaded yet (welcome screen, mid-switch). Falls back to the
    /// placeholder when neither is known.
    ///
    /// The registry entry's own `name` field is the lookup key used by
    /// `loadDocument(named:)` to find the YAML on disk — it is *not*
    /// re-synced from `config.project.name` here. Renaming via the
    /// Inspector or Project tab updates the visible label and the YAML
    /// contents; bringing the registry/filesystem along is a separate
    /// "rename project" affordance (not yet wired).
    private var currentProjectName: String {
        if let document, !document.config.project.name.isEmpty {
            return document.config.project.name
        }
        return selectedEntryName ?? "No project"
    }

    private func loadDocument(named name: String?) {
        guard let name,
              let entry = registryStore.entries.first(where: { $0.entry.name == name })?.entry else {
            document = nil; loadError = nil; return
        }
        let url = URL(fileURLWithPath: entry.configPath)
        do {
            document = try LutinProjectDocument(configURL: url)
            loadError = nil
        } catch let error as LutinError {
            document = nil; loadError = error.message
        } catch {
            document = nil; loadError = error.localizedDescription
        }
    }
}

private struct ProjectWorkspace: View {
    let document: LutinProjectDocument
    let projectName: String
    @Bindable var editorState: EditorState
    @Binding var showingDoctor: Bool
    @Binding var sidePanelHidden: Bool
    @State private var selectionModel = CanvasSelectionModel()
    @State private var pipelineRunner = PipelineRunner()
    /// Brief "Reloaded from disk" badge surfaced after an external
    /// rewrite of the project's `lutin.yml` (typically an agent or
    /// CLI). Without it the canvas would silently update and the user
    /// would wonder if anything changed — see `ConfigFileWatcher`.
    @State private var showReloadBadge = false
    @State private var reloadBadgeTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            EditorRail(selectedTab: $editorState.selectedTab)
            if !sidePanelHidden {
                SidePanel(width: $editorState.sidePanelWidth) {
                    VStack(spacing: 0) {
                        // Project switcher + collapse control. Sits
                        // immediately below the AppHeaderBar (14pt
                        // traffic-light strip). Height matches the
                        // EditorRail's `LogoSlot` (= `railWidth`)
                        // so the logo cell on the left and the
                        // project switcher cell on the right share
                        // the same baseline — one continuous 44pt
                        // top-toolbar row across rail + side panel.
                        // Horizontal padding is `md` (14pt) to align
                        // with `TabBody`, so the project name's left
                        // edge sits flush under each tab title.
                        HStack(spacing: Tokens.spacing(.sm)) {
                            LutinButton(role: .secondary, action: {
                                NotificationCenter.default.post(name: .lutinOpenSwitcher, object: nil)
                            }) {
                                HStack(spacing: 6) {
                                    Text(projectName)
                                        .font(Typography.controlLabel)
                                        .foregroundStyle(Tokens.color(.textPrimary))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(Tokens.color(.textTertiary))
                                }
                                .padding(.horizontal, Tokens.spacing(.sm))
                                .padding(.vertical, Tokens.spacing(.xs))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            LutinIconButton(systemName: "chevron.left.2",
                                            accessibilityLabel: "Hide sidebar",
                                            action: { sidePanelHidden = true })
                        }
                        .padding(.horizontal, Tokens.spacing(.md))
                        .frame(height: Tokens.Size.railWidth)
                        .background(Tokens.color(.panelBackground))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Tokens.color(.divider))
                                .frame(height: Tokens.Size.hairline)
                        }

                        PanelHeader(editorState.selectedTab.title)
                        TabPanelHost(document: document,
                                     editorState: editorState,
                                     selectionModel: selectionModel)
                    }
                }
            }
            CanvasView(document: document,
                       selectionModel: selectionModel,
                       editorState: editorState,
                       runner: pipelineRunner,
                       showingDoctor: $showingDoctor,
                       sidePanelHidden: $sidePanelHidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.color(.canvasBackground))
        }
        .animation(.easeInOut(duration: 0.18), value: sidePanelHidden)
        .sheet(isPresented: $showingDoctor) { DoctorSheet(document: document) }
        .onReceive(NotificationCenter.default.publisher(for: .lutinDelete)) { _ in
            try? selectionModel.delete(in: document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinDuplicate)) { _ in
            try? selectionModel.duplicate(in: document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinSelectAll)) { _ in
            let all = LayersOrdering.rows(from: document.config).map(\.id)
            selectionModel.replace(with: all)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinClearSelection)) { _ in
            selectionModel.clear()
        }
        // Hot-reload signal — only react if the notification's source
        // document is *this* one (an open multi-document setup would
        // otherwise see every project's reload).
        .onReceive(NotificationCenter.default.publisher(
            for: .lutinDocumentReloadedFromDisk)
        ) { note in
            guard (note.object as AnyObject?) === document else { return }
            flashReloadBadge()
        }
        .overlay(alignment: .bottomTrailing) {
            if showReloadBadge {
                Text("Reloaded from disk")
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textPrimary))
                    .padding(.horizontal, Tokens.spacing(.md))
                    .padding(.vertical, Tokens.spacing(.xs))
                    .background(SquareShape().fill(Tokens.color(.surfaceElevated)))
                    .overlay(SquareShape().stroke(Tokens.color(.divider),
                                                  lineWidth: Tokens.Size.hairline))
                    .padding(Tokens.spacing(.lg))
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pipelineRunner.state != .idle {
                PipelineDrawer(runner: pipelineRunner)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: pipelineRunner.state)
    }

    /// Shows the "Reloaded from disk" badge and schedules it to fade
    /// out. Cancels any in-flight hide so back-to-back external writes
    /// (an agent making a flurry of edits) don't expire the badge
    /// early — each reload re-extends the visible window.
    private func flashReloadBadge() {
        reloadBadgeTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            showReloadBadge = true
        }
        reloadBadgeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                showReloadBadge = false
            }
        }
    }
}

/// Per-tab body. Phase 2 ships placeholders so the shell compiles and tabs
/// visibly switch — real content arrives in later phases.
private struct TabPanelHost: View {
    let document: LutinProjectDocument
    @Bindable var editorState: EditorState
    let selectionModel: CanvasSelectionModel

    var body: some View {
        switch editorState.selectedTab {
        case .design:
            DesignTab(document: document, selectionModel: selectionModel)
        case .window:  WindowTab(document: document)
        case .project: ProjectTab(document: document)
        case .release: ReleaseTab(document: document)
        }
    }
}

extension Notification.Name {
    static let lutinOpenSwitcher = Notification.Name("lutinOpenSwitcher")
}

struct EmptyState: View {
    let title: String
    let message: String
    let icon: String
    var body: some View {
        VStack(spacing: Tokens.spacing(.md)) {
            Image(icon, bundle: .module)
                .resizable().scaledToFit().frame(width: 64, height: 64)
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message).font(Typography.chromeSmall).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(Tokens.spacing(.xl))
    }
}
