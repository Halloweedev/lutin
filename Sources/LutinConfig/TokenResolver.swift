import Foundation

/// Substitutes `${...}` tokens in config string fields.
public enum TokenResolver {
    public struct Context {
        public let version: String
        public let name: String
        public init(version: String, name: String) {
            self.version = version
            self.name = name
        }
    }

    public static func resolve(_ input: String, _ context: Context) -> String {
        input
            .replacingOccurrences(of: "${version}", with: context.version)
            .replacingOccurrences(of: "${name}", with: context.name)
    }
}
