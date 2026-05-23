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
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add App…") { addLibrary(.app) } // allow-menu-button
                Button("Add Applications folder") { addLibrary(.applications) } // allow-menu-button
                Button("Add Image…") { addLibrary(.image) } // allow-menu-button
            } label: {
                Image(systemName: "plus")
            }
            .help("Add to canvas")
        }
        ToolbarItemGroup(placement: .principal) {
            LutinIconButton(systemName: "play.fill", accessibilityLabel: "Build") {
                Task { await runner.run(mode: .build,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            }
            .disabled(isRunning)

            LutinIconButton(systemName: "eye.fill", accessibilityLabel: "Preview") {
                Task { await runner.run(mode: .preview,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            }
            .disabled(isRunning)

            LutinIconButton(systemName: "shippingbox.fill", accessibilityLabel: "Release") {
                Task { await runner.run(mode: .release,
                                         config: document.config,
                                         projectDirectory: document.projectDirectory) }
            }
            .disabled(isRunning)

            LutinIconButton(systemName: "stethoscope", accessibilityLabel: "Doctor") {
                showingDoctor = true
            }
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
