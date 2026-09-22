import Foundation

/// One validation finding. The shape is asc's own (`scope`, `file`, `locale`,
/// `version`, `field`, `severity`, `message`, `length`, `limit`), decoded
/// leniently so an added asc field cannot break Lutin.
///
/// It lives in the pure module because both halves of validation produce it:
/// the asc bridge decodes it, and the in-process (offline) subset constructs
/// it. Spec §4.1 puts "asc's issue model + the in-process subset" here.
public struct StoreMetadataIssue: Codable, Equatable, Sendable {
    public let scope: String?
    public let file: String?
    public let locale: String?
    public let version: String?
    public let field: String?
    public let severity: String
    public let message: String
    public let length: Int?
    public let limit: Int?

    public init(scope: String? = nil, file: String? = nil, locale: String? = nil,
                version: String? = nil, field: String? = nil,
                severity: String, message: String,
                length: Int? = nil, limit: Int? = nil) {
        self.scope = scope; self.file = file; self.locale = locale
        self.version = version; self.field = field
        self.severity = severity; self.message = message
        self.length = length; self.limit = limit
    }

    public var isError: Bool { severity == "error" }

    /// A path asc would silently ignore (§3.2). An error, never a warning:
    /// the whole hazard is that nothing would be pushed and nothing would say so.
    public static func strayPath(_ path: String) -> StoreMetadataIssue {
        StoreMetadataIssue(file: path, severity: "error",
                           message: "asc ignores unrecognised paths silently, so nothing "
                                  + "here would be pushed. Remove or relocate this path.")
    }

    /// An empty metadata tree is an error (spec §3.4), not a clean bill of health.
    public static func emptyTree(_ path: String) -> StoreMetadataIssue {
        StoreMetadataIssue(file: path, severity: "error",
                           message: "The metadata directory holds no metadata files. Run "
                                  + "`lutin store pull` to fetch the listing first.")
    }
}
