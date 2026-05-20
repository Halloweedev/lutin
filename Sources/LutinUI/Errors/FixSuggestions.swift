import Foundation
import LutinCore

/// Maps error codes to actionable user-facing fixes. Returns nil when there is
/// no canned suggestion.
public enum FixSuggestions {
    public static func suggestion(for code: String) -> String? {
        switch code {
        case "signing_no_identity":
            return "Open Keychain Access and confirm a Developer ID Application certificate is installed."
        case "notary_profile_missing":
            return "Run `xcrun notarytool store-credentials <profile>` in Terminal and paste the result into Settings."
        case "render_failed", "gui_renderer_failed":
            return "Check the background section of lutin.yml; templates must be one of the curated names."
        case "app_packager_missing_binary":
            return "Run `swift build -c release --product LutinApp` before invoking the packager."
        case "app_packager_layout_invalid":
            return "The assembled .app failed verification. Re-run the packager; report the log if it persists."
        case "document_save_failed":
            return "Check disk space and folder permissions for the project directory."
        case "config_load_failed":
            return "Open lutin.yml in a text editor and verify YAML syntax."
        default: return nil
        }
    }
}
