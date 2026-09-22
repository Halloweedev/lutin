import Foundation
import XCTest

/// Loads committed asc fixtures. Tests never invoke asc.
enum Fixtures {
    static func url(_ name: String, file: StaticString = #filePath) throws -> URL {
        let here = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        let candidate = here.appendingPathComponent("Fixtures").appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Missing fixture \(name). Run scripts/record-asc-fixtures.sh.")
        }
        return candidate
    }

    static func text(_ name: String, file: StaticString = #filePath) throws -> String {
        try String(contentsOf: try url(name, file: file), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func data(_ name: String, file: StaticString = #filePath) throws -> Data {
        try Data(contentsOf: try url(name, file: file))
    }
}
