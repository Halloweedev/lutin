import SwiftUI
import LutinRelease
import LutinDocument

public struct ToolbarActions: ToolbarContent {
    @Bindable var document: LutinProjectDocument
    @Bindable var runner: PipelineRunner
    @Binding var showingDoctor: Bool
    @State private var successPulse: Bool = false

    public init(document: LutinProjectDocument, runner: PipelineRunner, showingDoctor: Binding<Bool>) {
        self.document = document
        self.runner = runner
        self._showingDoctor = showingDoctor
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add App…") { addLibrary(.app) }
                Button("Add Applications folder") { addLibrary(.applications) }
                Button("Add Image…") { addLibrary(.image) }
            } label: {
                Image(systemName: "plus")
            }
            .help("Add to canvas")
        }
        ToolbarItemGroup(placement: .principal) {
            Button {
                Task { await runner.run(mode: .build,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            } label: { Label("Build", systemImage: "play.fill") }
                .disabled(isRunning)
                .tint(successPulse ? Tokens.color(.logSuccess) : nil)
                .onChange(of: runner.state) { _, newValue in
                    if case .succeeded = newValue {
                        successPulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { successPulse = false }
                    }
                }

            Button {
                Task { await runner.run(mode: .preview,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            } label: { Label("Preview", systemImage: "eye.fill") }
                .disabled(isRunning)

            Button {
                Task { await runner.run(mode: .release,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            } label: { Label("Release", systemImage: "shippingbox.fill") }
                .disabled(isRunning)

            Button { showingDoctor = true } label: { Label("Doctor", systemImage: "stethoscope") }
        }
    }

    private func addLibrary(_ item: LibraryItem) {
        let cx = CGFloat(document.config.window?.width ?? 680)
        let cy = CGFloat(document.config.window?.height ?? 420)
        CanvasFileDropDelegate.addLibrary(item,
                                          at: CGPoint(x: cx / 2, y: cy / 2),
                                          document: document)
    }

    private var isRunning: Bool {
        if case .running = runner.state { return true }
        return false
    }
}
