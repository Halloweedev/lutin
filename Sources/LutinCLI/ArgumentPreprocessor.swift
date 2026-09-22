import Foundation

/// Rewrites the `lutin <ProjectName> <verb>` form into `lutin <verb> --name <ProjectName>`,
/// so ArgumentParser (which matches subcommands by exact name) handles it normally.
public enum ArgumentPreprocessor {
    /// Subcommands that accept a `--name` project argument.
    static let projectVerbs: Set<String> = [
        "build", "release", "doctor", "validate", "preview", "open",
    ]

    /// All known top-level subcommand names. Must stay in sync with the
    /// `subcommands` list on `Lutin`; a name missing here gets mistaken for a
    /// project name and hijacked by `rewrite`.
    static let subcommands: Set<String> = projectVerbs.union([
        "init", "projects", "add", "remove",
        "store", "app-store", "notary", "apply-intents",
    ])

    public static func rewrite(_ args: [String]) -> [String] {
        guard let first = args.first else { return args }
        // Already a known subcommand → leave untouched.
        if subcommands.contains(first) { return args }
        // `<Name> <verb> ...` where verb accepts --name.
        if args.count >= 2, projectVerbs.contains(args[1]) {
            let name = args[0]
            let verb = args[1]
            let rest = Array(args.dropFirst(2))
            return [verb] + rest + ["--name", name]
        }
        return args
    }
}
