import SwiftUI
import LutinUI

@main
struct LutinApp: App {
    var body: some Scene {
        WindowGroup("Lutin") {
            WorkspaceShell()
                .frame(minWidth: 900, minHeight: 600)
        }
        // Drop the macOS title bar — Lutin draws its own header at the
        // top of the workspace. Traffic lights are kept (macOS positions
        // them in the top-left of the window's bounds even with a hidden
        // title bar) so the user can still close/min/zoom the window.
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands { LutinCommands() }

        Settings {
            PreferencesContainer()
        }
    }
}
