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
}
