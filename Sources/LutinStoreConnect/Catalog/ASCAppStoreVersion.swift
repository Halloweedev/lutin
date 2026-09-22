import Foundation

/// One App Store version, decoded from `asc versions list`. Decoding is lenient
/// about unknown attributes: Apple adds fields, and a new one must not break
/// the Versions section.
public struct ASCAppStoreVersion: Decodable, Equatable, Sendable, Identifiable {
    public let id: String
    public let versionString: String
    public let platform: String?
    public let appStoreState: String?
    public let appVersionState: String?
    public let createdDate: String?
    public let releaseType: String?
    public let isDownloadable: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, attributes
    }
    private enum Attributes: String, CodingKey {
        case versionString, platform, appStoreState, appVersionState
        case createdDate, releaseType, downloadable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: Attributes.self,
                                                       forKey: .attributes)
        versionString = try attributes.decode(String.self, forKey: .versionString)
        platform = try attributes.decodeIfPresent(String.self, forKey: .platform)
        appStoreState = try attributes.decodeIfPresent(String.self, forKey: .appStoreState)
        appVersionState = try attributes.decodeIfPresent(String.self, forKey: .appVersionState)
        createdDate = try attributes.decodeIfPresent(String.self, forKey: .createdDate)
        releaseType = try attributes.decodeIfPresent(String.self, forKey: .releaseType)
        isDownloadable = try attributes.decodeIfPresent(Bool.self, forKey: .downloadable)
    }

    public init(id: String, versionString: String, platform: String?,
                appStoreState: String?, appVersionState: String?,
                createdDate: String?, releaseType: String?,
                isDownloadable: Bool?) {
        self.id = id
        self.versionString = versionString
        self.platform = platform
        self.appStoreState = appStoreState
        self.appVersionState = appVersionState
        self.createdDate = createdDate
        self.releaseType = releaseType
        self.isDownloadable = isDownloadable
    }

    /// asc's own table prefers `appStoreState` and falls back to
    /// `appVersionState`; a row must never render a blank state.
    public var state: String? {
        let primary = appStoreState?.trimmingCharacters(in: .whitespaces) ?? ""
        if !primary.isEmpty { return primary }
        let fallback = appVersionState?.trimmingCharacters(in: .whitespaces) ?? ""
        return fallback.isEmpty ? nil : fallback
    }

    public static func decodeList(_ data: Data) throws -> [ASCAppStoreVersion] {
        struct Envelope: Decodable { let data: [ASCAppStoreVersion] }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    /// Newest first (spec §7.3). Versions with no `createdDate` keep asc's
    /// order after the dated ones — a stable sort, never a guess.
    public static func newestFirst(_ versions: [ASCAppStoreVersion]) -> [ASCAppStoreVersion] {
        versions.enumerated().sorted { a, b in
            switch (a.element.createdDate, b.element.createdDate) {
            case let (l?, r?): return l > r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.offset < b.offset
            }
        }.map(\.element)
    }
}

/// `asc versions list --output json` wraps JSON:API resources in a `data`
/// envelope (`Response[AppStoreVersionAttributes]` in asc's own source).
/// Internal: the engine decodes through it, tests decode it directly.
struct ASCAppStoreVersionList: Decodable {
    let data: [ASCAppStoreVersion]
}
