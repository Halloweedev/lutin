import Foundation

public enum IdentityProbe {
    public struct Identity: Equatable, Identifiable, Sendable {
        public var id: String { hash }
        public let hash: String
        public let name: String
    }

    public static func run() -> [Identity] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-identity", "-v", "-p", "codesigning"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parse(securityOutput: String(data: data, encoding: .utf8) ?? "")
        } catch { return [] }
    }

    public static func parse(securityOutput: String) -> [Identity] {
        var result: [Identity] = []
        let lines = securityOutput.split(whereSeparator: \.isNewline)
        let pattern = #"^\s*\d+\)\s+([A-Fa-f0-9]+)\s+"([^"]+)""#
        let regex = try? NSRegularExpression(pattern: pattern)
        for line in lines {
            let s = String(line)
            guard let m = regex?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let hashR = Range(m.range(at: 1), in: s),
                  let nameR = Range(m.range(at: 2), in: s) else { continue }
            result.append(Identity(hash: String(s[hashR]), name: String(s[nameR])))
        }
        return result
    }
}
