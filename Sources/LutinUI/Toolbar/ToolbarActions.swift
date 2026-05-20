import SwiftUI
import LutinRelease
import LutinDocument

public struct ToolbarActions: ToolbarContent {
    @Bindable var document: LutinProjectDocument
    @Bindable var runner: PipelineRunner
    @Binding var showingDoctor: Bool

    public init(document: LutinProjectDocument, runner: PipelineRunner, showingDoctor: Binding<Bool>) {
        self.document = document
        self.runner = runner
        self._showingDoctor = showingDoctor
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button {
                Task { await runner.run(mode: .build,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            } label: { Label("Build", systemImage: "play.fill") }
                .disabled(isRunning)

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

    private var isRunning: Bool {
        if case .running = runner.state { return true }
        return false
    }
}
