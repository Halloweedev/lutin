import SwiftUI
import LutinRelease
import LutinDocument

/// Horizontal cluster of action buttons (Preview / Build / Release / Doctor)
/// anchored to the bottom-leading corner of the canvas, adjacent to the zoom
/// controls row.
///
/// Order is iteration-frequency, not pipeline-chronology: Preview is the
/// most-used action while a user is laying out a DMG, so it sits leftmost.
/// Build (artifact-only, no Finder mount) sits next to it because the two
/// share 99% of the pipeline; Release (signed + notarized) and Doctor
/// (read-only environment checks) follow.
///
/// Build uses `hammer.fill` — `play.fill` here was misleading since "play"
/// reads as "run / preview", which is literally what the Preview button does.
///
/// Note: LutinIconButton does not currently propagate the visual disabled state
/// when wrapped with SwiftUI's `.disabled(_:)` modifier — follow-up needed in
/// LutinIconButton to fade the icon when the view is disabled.
public struct CanvasActionsBar: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var runner: PipelineRunner
    @Binding var showingDoctor: Bool

    public init(document: LutinProjectDocument,
                runner: PipelineRunner,
                showingDoctor: Binding<Bool>) {
        self.document = document
        self.runner = runner
        self._showingDoctor = showingDoctor
    }

    public var body: some View {
        HStack(spacing: Tokens.spacing(.xs)) {
            LutinIconButton(systemName: "eye.fill",
                            accessibilityLabel: "Preview",
                            action: { Task { await runner.run(mode: .preview,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory) } })
                .disabled(isRunning)
            LutinIconButton(systemName: "hammer.fill",
                            accessibilityLabel: "Build",
                            action: { Task { await runner.run(mode: .build,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory) } })
                .disabled(isRunning)
            LutinIconButton(systemName: "shippingbox.fill",
                            accessibilityLabel: "Release",
                            action: { Task { await runner.run(mode: .release,
                                                              config: document.config,
                                                              projectDirectory: document.projectDirectory) } })
                .disabled(isRunning)
            LutinIconButton(systemName: "stethoscope",
                            accessibilityLabel: "Doctor",
                            action: { showingDoctor = true })
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
