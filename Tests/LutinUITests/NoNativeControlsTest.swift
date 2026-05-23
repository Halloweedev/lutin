import XCTest

/// Fails the build if any banned SwiftUI primitive control name appears in
/// `Sources/LutinUI` or `Apps/LutinApp`. The banlist grows as each
/// Lutin*Control replacement lands; once all 6 primitives are migrated,
/// no native control can sneak back without explicit waiver.
///
/// Test bundles are exempt — fixtures may still construct primitives for
/// behavioral assertions that don't go through the design-system layer.
final class NoNativeControlsTest: XCTestCase {

    /// Add a primitive here the moment its migration task completes.
    /// Order matches plan task order so PR history is auditable.
    ///
    /// To exempt a single line (e.g., a menu/command Button inside CommandGroup
    /// or Menu { ... }), append `// allow-menu-button` to it. An optional
    /// descriptive suffix is allowed: `// allow-menu-button: reason here`.
    private static let bannedPrimitives: [String] = [
        "Button",
        "TextField",
        "Toggle",
        // "Stepper", "Picker", "Slider"
        // Filled in as each migration task lands.
    ]

    func testNoBannedPrimitivesInProductionSources() throws {
        guard !Self.bannedPrimitives.isEmpty else {
            // Empty banlist: nothing to enforce yet. Pass trivially.
            return
        }

        let repoRoot = try Self.repoRoot()
        let searchPaths = [
            repoRoot.appendingPathComponent("Sources/LutinUI"),
            repoRoot.appendingPathComponent("Apps/LutinApp"),
        ]

        // Exclude the design-system Controls folder itself — that's where the
        // wrapped primitives live.
        let excludeFragment = "Sources/LutinUI/DesignSystem/Controls"

        var violations: [String] = []
        let pattern = "\\b(" + Self.bannedPrimitives
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|") + ")\\("
        let regex = try NSRegularExpression(pattern: pattern)

        for root in searchPaths {
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                guard url.pathExtension == "swift" else { continue }
                guard !url.path.contains(excludeFragment) else { continue }
                let contents = try String(contentsOf: url, encoding: .utf8)
                let lines = contents.components(separatedBy: "\n")
                for (idx, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // Marker may be bare (`// allow-menu-button`) or with a trailing
                    // description (`// allow-menu-button: hidden behind LutinButton`).
                    // Match either form.
                    if trimmed.contains("// allow-menu-button") { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        violations.append("\(url.path):\(idx + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Native SwiftUI controls leaked into LutinUI/LutinApp.\n" +
            "Use the Lutin* equivalent from DesignSystem/Controls.\n\n" +
            violations.joined(separator: "\n")
        )
    }

    private static func repoRoot() throws -> URL {
        // Walk up from the test bundle until we find Package.swift.
        let start = Bundle(for: Self.self).bundleURL
        var url = start
        for _ in 0..<15 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path
            ) {
                return url
            }
        }
        throw NSError(domain: "NoNativeControlsTest", code: 1, userInfo: [
            NSLocalizedDescriptionKey:
                "Couldn't locate Package.swift walking up from \(start.path)"
        ])
    }
}
