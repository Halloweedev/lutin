import XCTest
@testable import LutinStoreMetadata
import LutinCore

final class StoreMetadataLocalizationTests: XCTestCase {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - Strict decoding

    /// asc rejects unknown keys with exit 2. Lutin must match, so a field
    /// typo cannot produce a silently-wrong push.
    func testUnknownKeyIsRejected() {
        let json = #"{"description":"D","bogusField":"x"}"#
        XCTAssertThrowsError(
            try StoreMetadataLocalization.decode(data(json), scope: .version, locale: "en-US")
        ) { error in
            let e = error as? LutinError
            XCTAssertEqual(e?.code, "store_metadata_schema")
            XCTAssertEqual(e?.details?["field"], "bogusField")
            XCTAssertEqual(e?.details?["locale"], "en-US")
        }
    }

    func testMalformedJSONIsRejected() {
        XCTAssertThrowsError(
            try StoreMetadataLocalization.decode(data("{not json"), scope: .version, locale: "en-US")
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_schema")
        }
    }

    /// A key belonging to the *other* scope is unknown here, and must be rejected.
    func testCrossScopeKeyIsRejected() {
        let json = #"{"name":"MyApp"}"#   // name is app-info, not version
        XCTAssertThrowsError(
            try StoreMetadataLocalization.decode(data(json), scope: .version, locale: "en-US")
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_metadata_schema")
        }
    }

    // MARK: - Empty is unset

    /// Verified against asc: `{"name":""}` reports "name is required".
    func testEmptyStringIsTreatedAsUnset() throws {
        let json = #"{"name":"","subtitle":"A subtitle"}"#
        let loc = try StoreMetadataLocalization.decode(data(json), scope: .appInfo, locale: "en-US")
        XCTAssertNil(loc.values[.name])
        XCTAssertEqual(loc.values[.subtitle], "A subtitle")
    }

    // MARK: - Round-trip stability

    func testRoundTripIsByteStable() throws {
        let json = #"{"description":"A description.","keywords":"alpha,beta"}"#
        let loc = try StoreMetadataLocalization.decode(data(json), scope: .version, locale: "en-US")
        let once = try loc.encode()
        let twice = try StoreMetadataLocalization.decode(once, scope: .version, locale: "en-US").encode()
        XCTAssertEqual(once, twice, "Encoding must be idempotent or parity tests cannot hold.")
    }

    func testEncodeEmitsSortedKeys() throws {
        let json = #"{"whatsNew":"N","description":"D","keywords":"k"}"#
        let loc = try StoreMetadataLocalization.decode(data(json), scope: .version, locale: "en-US")
        let out = String(decoding: try loc.encode(), as: UTF8.self)
        XCTAssertEqual(out, #"{"description":"D","keywords":"k","whatsNew":"N"}"#)
    }

    func testUnsetFieldsAreOmittedNotWrittenAsNull() throws {
        let json = #"{"description":"D"}"#
        let loc = try StoreMetadataLocalization.decode(data(json), scope: .version, locale: "en-US")
        let out = String(decoding: try loc.encode(), as: UTF8.self)
        XCTAssertFalse(out.contains("null"))
        XCTAssertEqual(out, #"{"description":"D"}"#)
    }

    // MARK: - Field metadata

    func testFieldScopesAndLimits() {
        XCTAssertEqual(StoreMetadataField.name.scope, .appInfo)
        XCTAssertEqual(StoreMetadataField.name.limit, 30)
        XCTAssertEqual(StoreMetadataField.subtitle.limit, 30)
        XCTAssertEqual(StoreMetadataField.privacyPolicyUrl.limit, nil)
        XCTAssertEqual(StoreMetadataField.description.scope, .version)
        XCTAssertEqual(StoreMetadataField.description.limit, 4000)
        XCTAssertEqual(StoreMetadataField.keywords.limit, 100)
        XCTAssertEqual(StoreMetadataField.promotionalText.limit, 170)
        XCTAssertEqual(StoreMetadataField.whatsNew.limit, 4000)
        XCTAssertEqual(StoreMetadataField.marketingUrl.limit, nil)
        XCTAssertEqual(StoreMetadataField.supportUrl.limit, nil)
    }

    /// Every field must belong to exactly one scope, and the two scopes
    /// together must cover every case.
    func testEveryFieldBelongsToExactlyOneScope() {
        let byScope = Dictionary(grouping: StoreMetadataField.allCases, by: \.scope)
        XCTAssertEqual(byScope[.appInfo]?.count, 5)
        XCTAssertEqual(byScope[.version]?.count, 6)
        XCTAssertEqual(byScope.values.reduce(0) { $0 + $1.count }, StoreMetadataField.allCases.count)
    }
}
