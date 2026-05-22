import Foundation

public enum NotaryProbe {
    public static func run() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["notarytool", "list-keychain-profiles"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parse(notarytoolOutput: String(data: data, encoding: .utf8) ?? "")
        } catch { return [] }
    }

    public static func parse(notarytoolOutput: String) -> [String] {
        var result: [String] = []
        let lines = notarytoolOutput.split(whereSeparator: \.isNewline)
        for line in lines {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s.isEmpty || s.contains(":") { continue }
            result.append(String(s))
        }
        return result
    }
}
