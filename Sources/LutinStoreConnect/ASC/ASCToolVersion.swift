import LutinCore

/// The `asc` release Lutin is built and tested against.
///
/// The pin is derived from a **binary that was actually probed** — 5.3.0 on the
/// development machine — never from published documentation. The project
/// website advertised 2.0.0 while 5.3.0 was installed, and asc ships major
/// releases with documented breaking migrations.
public struct ASCToolVersion: Equatable, Comparable, CustomStringConvertible, Sendable {

    public static let minimum = ASCToolVersion(major: 5, minor: 3, patch: 0)!

    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?(major: Int, minor: Int, patch: Int) {
        guard major >= 0, minor >= 0, patch >= 0 else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }

    /// Parses the first whitespace-delimited token of `asc --version`, whose
    /// real output is `5.3.0 (commit: unknown, date: unknown)`.
    public init?(_ string: String) {
        let token = string.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        guard !token.isEmpty else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let n = Int(part), n >= 0 else { return nil }
            numbers.append(n)
        }
        while numbers.count < 3 { numbers.append(0) }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: ASCToolVersion, rhs: ASCToolVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    /// - Throws: `LutinError(code: "store_asc_too_old")` when `raw` is
    ///   unparseable or below `minimum`.
    public static func assertSupported(_ raw: String) throws {
        let parsed = ASCToolVersion(raw)
        guard let found = parsed, found >= minimum else {
            throw LutinError(
                code: "store_asc_too_old",
                message: "Lutin needs asc \(minimum) or newer; found "
                       + (parsed?.description ?? "\"\(raw)\"")
                       + ". Run `brew upgrade asc`.",
                details: ["required": minimum.description,
                          "found": parsed?.description ?? raw])
        }
    }
}
