import XCTest
@testable import LutinUI

final class FixSuggestionsTests: XCTestCase {
    func testKnownCodesHaveSuggestions() {
        for code in ["signing_no_identity", "notary_profile_missing", "render_failed",
                     "app_packager_missing_binary", "app_packager_layout_invalid",
                     "document_save_failed", "config_load_failed"] {
            XCTAssertNotNil(FixSuggestions.suggestion(for: code), "Missing fix for \(code)")
        }
    }

    func testUnknownCodeHasNoSuggestion() {
        XCTAssertNil(FixSuggestions.suggestion(for: "totally-made-up-code"))
    }

    /// Spec §4.6: every store_* code maps to an actionable fix. The Connection
    /// section and the new sections all consult this table first.
    func testEveryStoreCodeHasASuggestion() {
        let codes = ["store_asc_missing", "store_asc_too_old", "store_unauthenticated",
                     "store_web_session_missing", "store_app_not_found",
                     "store_layout_mismatch", "store_metadata_schema",
                     "store_validation_failed", "store_metadata_missing",
                     "store_confirmation_required", "store_pull_would_overwrite",
                     "store_plan_failed", "store_apply_failed", "store_rate_limited",
                     "store_unsupported", "store_asc_failed",
                     "store_bundle_id_mismatch"]
        for code in codes {
            XCTAssertNotNil(FixSuggestions.suggestion(for: code), "missing fix for \(code)")
        }
    }
}
