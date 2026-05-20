import SwiftUI
import LutinCore
import LutinConfig
import LutinRegistry
import LutinDocument

public struct WorkspaceShell: View {
    @State private var registryStore = RegistryStore()
    @State private var preferencesStore = PreferencesStore()
    @State private var selectedEntryName: String?
    @State private var document: LutinProjectDocument?
    @State private var loadError: String?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(registryStore: registryStore, selectedEntryName: $selectedEntryName)
        } detail: {
            Group {
                if let document {
                    ProjectWorkspace(document: document)
                } else if let loadError {
                    EmptyState(title: "Could not load project", message: loadError, icon: "EmptySelection")
                } else {
                    EmptyState(title: "Select a project", message: "Choose a project from the sidebar to begin.", icon: "EmptySelection")
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .environment(registryStore)
        .environment(preferencesStore)
        .onChange(of: preferencesStore.preferences.autosave) { _, newValue in
            document?.autosaveEnabled = newValue
        }
        .task {
            do {
                try registryStore.reload()
                try preferencesStore.reload()
            } catch { /* surfaced via lastError */ }
        }
        .onChange(of: selectedEntryName) { _, name in
            loadDocument(named: name)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinSave)) { _ in
            try? document?.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinUndo)) { _ in document?.undo() }
        .onReceive(NotificationCenter.default.publisher(for: .lutinRedo)) { _ in document?.redo() }
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
    @State private var selectionModel = CanvasSelectionModel()
    @State private var pipelineRunner = PipelineRunner()
    @State private var showingDoctor = false
    @State private var inspectorVisible: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            CanvasView(document: document, selectionModel: selectionModel)
            Spacer(minLength: 0)
        }
        .background(Tokens.color(.canvasBackground))
        .inspector(isPresented: $inspectorVisible) {
            InspectorView(document: document, selection: selectionModel.selection)
        }
        .toolbar { ToolbarActions(document: document, runner: pipelineRunner, showingDoctor: $showingDoctor) }
        .sheet(isPresented: $showingDoctor) { DoctorSheet(document: document) }
        .onReceive(NotificationCenter.default.publisher(for: .lutinDelete)) { _ in
            try? selectionModel.delete(in: document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lutinDuplicate)) { _ in
            try? selectionModel.duplicate(in: document)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pipelineRunner.state != .idle {
                PipelineDrawer(runner: pipelineRunner)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: pipelineRunner.state)
    }
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

// Stub — replaced by real DoctorSheet in Task 3.4.
struct DoctorSheet: View {
    let document: LutinProjectDocument
    var body: some View { Text("Doctor — stub").padding() }
}
