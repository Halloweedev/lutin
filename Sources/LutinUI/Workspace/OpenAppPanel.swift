import AppKit
import UniformTypeIdentifiers

/// Presents the standard macOS Open panel pre-filtered to `.app`
/// bundles. Used by `WelcomeDropHero` when the user clicks the drop
/// tile. The completion fires with `nil` if the user cancels.
enum OpenAppPanel {
    static func present(_ completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to package"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            completion(url)
        }
    }
}
