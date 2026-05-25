import Foundation

/// Notarytool keychain-profile inspector.
///
/// **Important**: this is *not* a generic keychain probe. Apple's
/// notarytool writes its credentials with an ACL restricted to its own
/// signing team — third-party apps (and even `swift -e`) get
/// `errSecItemNotFound` for every `SecItemCopyMatching` query shape,
/// regardless of which keychain partition we look at. We can't
/// enumerate or verify notarytool profiles by querying the Keychain
/// directly. Confirmed via Apple's notarytool man page (no ACL flag
/// available) and a long detour through `SecItemCopyMatching` with
/// every combination of partition / class / access-group / sync flag.
///
/// So the design pivoted:
///
/// 1. Lutin tracks profile names it has successfully created
///    (`PreferencesStore.knownNotaryProfiles`). That's our positive
///    signal — fast, local, no false positives.
/// 2. For definitive verification of any profile (whether Lutin
///    created it or not), shell out to `xcrun notarytool history
///    --keychain-profile <name>`. notarytool is the only authorized
///    reader of its own credentials, so it's the only reliable source
///    of truth. Slow (~3s, network) but correct.
public enum NotaryProbe {
    /// Tests a profile by shelling out to `xcrun notarytool history
    /// --keychain-profile <name>`. Returns three possible outcomes:
    ///
    ///   - `.ok`       — profile resolved + credentials accepted by
    ///                   Apple's server. The credential works for
    ///                   real submissions.
    ///   - `.profileNotFound` — notarytool can't find a profile by
    ///                   that name in any of its known keychains.
    ///   - `.failed(reason)`  — profile resolved but the network /
    ///                   credentials call failed (auth rejected,
    ///                   network down, etc.). Reason carries the
    ///                   stderr text for display.
    ///
    /// Hits the network. Callers should run this off the UI thread
    /// and behind an explicit "Test" affordance, not on every
    /// keystroke. Roughly 2–5 seconds round-trip on a good link.
    public enum TestResult: Equatable, Sendable {
        case ok
        case profileNotFound
        case failed(reason: String)
    }

    public static func test(profileName: String) async -> TestResult {
        let trimmed = profileName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .profileNotFound }
        return await Task.detached(priority: .userInitiated) { () -> TestResult in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = [
                "notarytool", "history",
                "--keychain-profile", trimmed,
                "--output-format", "json",
            ]
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            do {
                try p.run()
                p.waitUntilExit()
                let out = String(
                    data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) ?? ""
                let err = String(
                    data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    return .ok
                }
                // notarytool's profile-missing message has stabilised
                // around "Could not find a profile…" / "no such profile".
                let combined = (out + "\n" + err).lowercased()
                if combined.contains("could not find")
                    || combined.contains("no such profile")
                    || combined.contains("profile not found") {
                    return .profileNotFound
                }
                let reason = err.isEmpty ? out : err
                return .failed(reason: reason
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                return .failed(reason: error.localizedDescription)
            }
        }.value
    }
}
