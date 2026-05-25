import Foundation
import Observation
import LutinCore

public struct LutinPreferences: Codable, Equatable {
    public var defaultOutputDirectory: String?
    public var snapGridSize: Int
    public var showAlignmentGuides: Bool
    public var theme: Theme
    /// Notarytool profile names Lutin has successfully created (via the
    /// in-app New profile sheet) on this user account. Used as a
    /// positive-only signal for the UI — `notarytool` stores its
    /// credentials in a keychain partition whose access group is
    /// restricted to its own signed binary, so third-party apps
    /// (including Lutin) literally can't enumerate or verify these
    /// items via `SecItemCopyMatching` or `/usr/bin/security`. The
    /// only readers of that partition are notarytool itself and the
    /// Keychain Access app. So Lutin tracks creations it observed
    /// firsthand and stays silent about everything else.
    public var knownNotaryProfiles: [String]

    public enum Theme: String, Codable, Equatable { case system, light, dark }

    public init(defaultOutputDirectory: String? = nil,
                snapGridSize: Int = 4,
                showAlignmentGuides: Bool = true,
                theme: Theme = .system,
                knownNotaryProfiles: [String] = []) {
        self.defaultOutputDirectory = defaultOutputDirectory
        self.snapGridSize = snapGridSize
        self.showAlignmentGuides = showAlignmentGuides
        self.theme = theme
        self.knownNotaryProfiles = knownNotaryProfiles
    }
}

@Observable
public final class PreferencesStore {
    public private(set) var preferences: LutinPreferences = LutinPreferences()

    @ObservationIgnored
    public let storeURL: URL

    public init(storeURL: URL = PreferencesStore.defaultStoreURL()) {
        self.storeURL = storeURL
    }

    public static func defaultStoreURL() -> URL {
        let support = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = support.appendingPathComponent("Lutin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }

    public func reload() throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            preferences = LutinPreferences()
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)
            preferences = try JSONDecoder().decode(LutinPreferences.self, from: data)
        } catch {
            throw LutinError(code: "preferences_corrupt",
                             message: "Could not read preferences at \(storeURL.path): \(error.localizedDescription)")
        }
    }

    public func update(_ mutate: (inout LutinPreferences) -> Void) throws {
        var copy = preferences
        mutate(&copy)
        try write(copy)
        preferences = copy
    }

    /// Records a notarytool profile name Lutin just created. Idempotent
    /// (no duplicates). See `LutinPreferences.knownNotaryProfiles` for
    /// the reasoning — we can't enumerate notarytool's keychain entries
    /// (ACL-restricted to its signing team), so the only profiles we
    /// can confidently mark as "exists" are the ones we observed
    /// firsthand at creation time.
    public func rememberNotaryProfile(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try update { prefs in
            if !prefs.knownNotaryProfiles.contains(trimmed) {
                prefs.knownNotaryProfiles.append(trimmed)
            }
        }
    }

    /// Drops a name from the remembered list — used if a verify-test
    /// reveals the profile is gone from the Keychain.
    public func forgetNotaryProfile(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try update { prefs in
            prefs.knownNotaryProfiles.removeAll { $0 == trimmed }
        }
    }

    private func write(_ prefs: LutinPreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let tmp = storeURL.appendingPathExtension("tmp")
        try encoder.encode(prefs).write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(storeURL, withItemAt: tmp)
    }
}
