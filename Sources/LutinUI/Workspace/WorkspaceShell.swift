import SwiftUI
import LutinCore
import LutinConfig
import LutinRegistry
import LutinDocument

public struct WorkspaceShell: View {
    @State private var registryStore = RegistryStore()
    @State private var preferencesStore = PreferencesStore()
    @State private var editorStateStore = EditorStateStore()
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
            AppHeaderBar(title: "Lutin",
                         projectName: currentProjectName,
                         sidePanelHidden: $sidePanelHidden,
                         onTitleTap: { showSwitcher = true })
            Group {
                if let document {
                    ProjectWorkspace(document: document,
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
        .background {
            // Hidden button to wire ⌘N globally without claiming a visible
            // toolbar slot — same pattern other commands use.
            LutinButton("New project", role: .primary) { showCreateNew = true }
                .keyboardShortcut("n", modifiers: .command)
                .opacity(0)
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

    private var currentProjectName: String {
        selectedEntryName ?? "No project"
    }

    private func loadDocument(named name: String?) {
        guard let name,
              let entry = registryStore.entries.first(where: { $0.entry.name == name })?.entry else {
            document = nil; loadError = nil; return
        }
        let url = URL(fileURLWithPath: entry.configPath)
        do {
            document = try LutinProjectDocument(configURL: url)
            document?.autosaveEnabled = preferencesStore.preferences.autosave
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
    @Bindable var editorState: EditorState
    @Binding var showingDoctor: Bool
    @Binding var sidePanelHidden: Bool
    @State private var selectionModel = CanvasSelectionModel()
    @State private var pipelineRunner = PipelineRunner()

    var body: some View {
        HStack(spacing: 0) {
            EditorRail(selectedTab: $editorState.selectedTab,
                       onOpenSwitcher: {
                           NotificationCenter.default.post(name: .lutinOpenSwitcher, object: nil)
                       })
            if !sidePanelHidden {
                SidePanel(width: $editorState.sidePanelWidth) {
                    VStack(spacing: 0) {
                        PanelHeader(editorState.selectedTab.title)
                        TabPanelHost(document: document,
                                     editorState: editorState,
                                     selectionModel: selectionModel)
                    }
                }
            }
            CanvasView(document: document,
                       selectionModel: selectionModel,
                       editorState: editorState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.color(.canvasBackground))
        }
        .animation(.easeInOut(duration: 0.18), value: sidePanelHidden)
        .toolbar {
            ToolbarActions(document: document, runner: pipelineRunner, showingDoctor: $showingDoctor)
        }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pipelineRunner.state != .idle {
                PipelineDrawer(runner: pipelineRunner)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: pipelineRunner.state)
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
