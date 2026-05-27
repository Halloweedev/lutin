import SwiftUI
import LutinRelease
import LutinDocument

/// Horizontal cluster of action buttons (Preview / Build / Release)
/// anchored to the bottom-leading corner of the canvas, adjacent to the zoom
/// controls row.
///
/// Order is iteration-frequency, not pipeline-chronology: Preview is the
/// most-used action while a user is laying out a DMG, so it sits leftmost.
/// Build (artifact-only, no Finder mount) sits next to it because the two
/// share 99% of the pipeline; Release (signed + notarized) follows.
///
/// The Doctor button is accessible from the workspace bottom bar; it is
/// intentionally absent here to keep the action bar focused on pipeline
/// operations.
///
/// Note: LutinIconButton does not currently propagate the visual disabled state
/// when wrapped with SwiftUI's `.disabled(_:)` modifier — follow-up needed in
/// LutinIconButton to fade the icon when the view is disabled.
public struct CanvasActionsBar: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var runner: PipelineRunner
    let projectName: String?
    let registryStore: RegistryStore?

    public init(document: LutinProjectDocument,
                runner: PipelineRunner,
                projectName: String? = nil,
                registryStore: RegistryStore? = nil) {
        self.document = document
        self.runner = runner
        self.projectName = projectName
        self.registryStore = registryStore
    }

    public var body: some View {
        HStack(spacing: Tokens.spacing(.xs)) {
            LutinIconButton(asset: "eye",
                            accessibilityLabel: "Preview",
                            action: { Task { await runner.run(mode: .preview,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory,
                                                              projectName: projectName,
                                                              registryStore: registryStore) } })
                .disabled(isRunning)
            LutinIconButton(asset: "hammer",
                            accessibilityLabel: "Build",
                            action: { Task { await runner.run(mode: .build,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory,
                                                              projectName: projectName,
                                                              registryStore: registryStore) } })
                .disabled(isRunning)
            LutinIconButton(asset: "rocket-launch",
                            accessibilityLabel: "Release",
                            action: { Task { await runner.run(mode: .release,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory,
                                                              projectName: projectName,
                                                              registryStore: registryStore) } })
                .disabled(isRunning)
        }
        .padding(Tokens.spacing(.sm))
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
    }

    private var isRunning: Bool {
        if case .running = runner.state { return true }
        return false
    }
}
