import Foundation
import LutinCore

/// One locale's worth of canonical metadata for one scope.
///
/// Decoding is **strict**: unknown keys are an error, not a dropped value.
/// This mirrors asc, which fails fast with exit 2 and the message
/// `json: unknown field "<name>"`. The consequence Lutin relies on: a typo in
/// a locale file surfaces immediately instead of silently pushing a listing
/// with a field missing.
public struct StoreMetadataLocalization: Codable, Equatable, Sendable {

    /// Only non-empty values are stored — see `decode`. Ordering is
    /// irrelevant because `encode` sorts keys.
    public var values: [StoreMetadataField: String]

    public init(values: [StoreMetadataField: String]) {
        self.values = values.filter { !$0.value.isEmpty }
    }

    /// Decodes one locale file.
    ///
    /// - Throws: `LutinError(code: "store_metadata_schema")` for malformed
    ///   JSON or any key outside the field set for `scope`. `details` carries
    ///   `locale`, `scope`, and — where the key is known — `field`.
    public static func decode(_ data: Data,
                              scope: StoreMetadataScope,
                              locale: String) throws -> StoreMetadataLocalization {
        let raw: [String: String]
        do {
            raw = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw LutinError(
                code: "store_metadata_schema",
                message: "Metadata for '\(locale)' is not a valid JSON object of strings: \(error)",
                details: ["locale": locale, "scope": scope.rawValue])
        }

        var values: [StoreMetadataField: String] = [:]
        for (key, value) in raw {
            guard let field = StoreMetadataField(rawValue: key), field.scope == scope else {
                throw LutinError(
                    code: "store_metadata_schema",
                    message: "Unknown \(scope.rawValue) field '\(key)' in '\(locale)'. "
                           + "asc rejects unknown keys, so this would fail on push.",
                    details: ["locale": locale, "scope": scope.rawValue, "field": key])
            }
            // Empty string is unset, matching asc: `{"name":""}` reports
            // "name is required" rather than writing an empty name.
            if !value.isEmpty { values[field] = value }
        }
        return StoreMetadataLocalization(values: values)
    }

    /// Encodes with sorted keys and no trailing newline, so repeated writes are
    /// byte-identical. `verify-editor-parity.sh` depends on that.
    public func encode() throws -> Data {
        let raw = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(raw)
    }
}
