import SwiftUI
import LutinUI

@main
struct LutinApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("Lutin") {
            WorkspaceShell()
                .frame(minWidth: 900, minHeight: 600)
                .task { await LicensingHooks.checkOnLaunch() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await LicensingHooks.refreshIfNeeded() }
                    }
                }
        }
        // Drop the macOS title bar — Lutin draws its own header at the
        // top of the workspace. Traffic lights are kept (macOS positions
        // them in the top-left of the window's bounds even with a hidden
        // title bar) so the user can still close/min/zoom the window.
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        // Open ~20% larger than the 900×600 content minimum so the
        // welcome page and editor breathe on first launch. The min on
        // the content view is unchanged — users can still shrink the
        // window back down.
        .defaultSize(width: 1080, height: 720)
        .commands { LutinCommands() }

        Settings {
            PreferencesContainer()
        }
    }
}
