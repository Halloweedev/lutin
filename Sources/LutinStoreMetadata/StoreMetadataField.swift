import Foundation

/// Which half of the canonical metadata tree a field belongs to.
/// Raw values match asc's `--include` scope names and the directory names.
public enum StoreMetadataScope: String, Codable, CaseIterable, Sendable {
    case appInfo = "app-info"
    case version
}

/// A single canonical metadata field. The raw value is the JSON key, so it is
/// also the wire format — never rename a case without re-recording fixtures.
public enum StoreMetadataField: String, Codable, CaseIterable, Sendable {
    // app-info
    case name
    case subtitle
    case privacyPolicyUrl
    case privacyChoicesUrl
    case privacyPolicyText
    // version
    case description
    case keywords
    case marketingUrl
    case promotionalText
    case supportUrl
    case whatsNew

    public var scope: StoreMetadataScope {
        switch self {
        case .name, .subtitle, .privacyPolicyUrl, .privacyChoicesUrl, .privacyPolicyText:
            return .appInfo
        case .description, .keywords, .marketingUrl, .promotionalText, .supportUrl, .whatsNew:
            return .version
        }
    }

    /// Maximum character count asc enforces, or `nil` where asc enforces none.
    /// Verified against asc 5.3.0; the messages it emits name these exact numbers.
    public var limit: Int? {
        switch self {
        case .name, .subtitle: return 30
        case .keywords: return 100
        case .promotionalText: return 170
        case .description, .whatsNew: return 4000
        case .privacyPolicyUrl, .privacyChoicesUrl, .privacyPolicyText,
             .marketingUrl, .supportUrl: return nil
        }
    }

    /// Fields that must be present in an app-info localization before asc
    /// considers the file non-empty.
    public static var appInfoFields: [StoreMetadataField] { allCases.filter { $0.scope == .appInfo } }
    public static var versionFields: [StoreMetadataField] { allCases.filter { $0.scope == .version } }
}
