import Foundation

/// Substitutes `${...}` tokens in config string fields.
public enum TokenResolver {
    public struct Context {
        public let version: String
        public let name: String
        public let build: String
        public init(version: String, name: String, build: String = "") {
            self.version = version
            self.name = name
            self.build = build
        }
    }

    public static func resolve(_ input: String, _ context: Context) -> String {
        input
            .replacingOccurrences(of: "${version}", with: context.version)
            .replacingOccurrences(of: "${name}", with: context.name)
            .replacingOccurrences(of: "${build}", with: context.build)
    }
}
