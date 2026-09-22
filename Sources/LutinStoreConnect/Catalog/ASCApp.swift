import Foundation

/// The resolved app record, decoded from `asc apps view --id` (a single
/// JSON:API resource). Decoding is lenient about unknown attributes: Apple
/// adds fields, and a new one must not break the App section.
public struct ASCApp: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String?
    public let bundleID: String?
    public let sku: String?
    public let primaryLocale: String?

    private enum CodingKeys: String, CodingKey {
        case id, attributes
    }
    private enum Attributes: String, CodingKey {
        case name, bundleId, sku, primaryLocale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: Attributes.self,
                                                       forKey: .attributes)
        name = try attributes.decodeIfPresent(String.self, forKey: .name)
        bundleID = try attributes.decodeIfPresent(String.self, forKey: .bundleId)
        sku = try attributes.decodeIfPresent(String.self, forKey: .sku)
        primaryLocale = try attributes.decodeIfPresent(String.self, forKey: .primaryLocale)
    }

    public init(id: String, name: String? = nil, bundleID: String? = nil,
                sku: String? = nil, primaryLocale: String? = nil) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.sku = sku
        self.primaryLocale = primaryLocale
    }
}
