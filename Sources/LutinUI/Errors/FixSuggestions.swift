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
        // Store (Spec 1a §4.6) — unprefixed, matching the codebase.
        case "store_asc_missing":
            return "Install it with `brew install asc`."
        case "store_asc_too_old":
            return "Run `brew upgrade asc` — Lutin needs 5.3.0 or newer."
        case "store_unauthenticated":
            return "Run `asc auth login`."
        case "store_web_session_missing":
            return "Run `asc web auth login --apple-id`."
        case "store_app_not_found":
            return "Set `store.appID` in lutin.yml (or ASC_APP_ID) and retry."
        case "store_layout_mismatch":
            return "Check store.metadataDir: it must be a directory holding app-info/ and version/<v>/, with no stray versions/."
        case "store_metadata_schema":
            return "Fix the named file and field — asc rejects unknown keys."
        case "store_validation_failed":
            return "Review the findings in the Validation section."
        case "store_metadata_missing":
            return "Run `lutin store pull` to fetch the listing first."
        case "store_confirmation_required":
            return "Review the plan, then apply again and confirm."
        case "store_pull_would_overwrite":
            return "Re-run with `--force`, or run `lutin store plan` first."
        case "store_plan_failed", "store_apply_failed":
            return "Inspect asc's stderr for the failing change."
        case "store_rate_limited":
            return "Wait and retry — App Store Connect allows 3,600 requests per hour per team."
        case "store_unsupported":
            return "asc reports this is not available over a public API; use App Store Connect."
        case "store_asc_failed":
            return "Inspect asc's stderr for the cause."
        case "store_bundle_id_mismatch":
            return "Fix `store.bundleID` (or clear it) so it matches the resolved app."
        default: return nil
        }
    }
}
