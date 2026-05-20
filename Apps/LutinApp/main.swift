import SwiftUI
import LutinUI

@main
struct LutinApp: App {
    var body: some Scene {
        WindowGroup("Lutin") {
            WorkspaceShell()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
    }
}
