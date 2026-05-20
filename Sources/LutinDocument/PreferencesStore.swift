import Foundation
import Observation
import LutinCore

public struct LutinPreferences: Codable, Equatable {
    public var autosave: Bool
    public var defaultOutputDirectory: String?
    public var snapGridSize: Int
    public var showAlignmentGuides: Bool
    public var theme: Theme

    public enum Theme: String, Codable, Equatable { case system, light, dark }

    public init(autosave: Bool = false,
                defaultOutputDirectory: String? = nil,
                snapGridSize: Int = 4,
                showAlignmentGuides: Bool = true,
                theme: Theme = .system) {
        self.autosave = autosave
        self.defaultOutputDirectory = defaultOutputDirectory
        self.snapGridSize = snapGridSize
        self.showAlignmentGuides = showAlignmentGuides
        self.theme = theme
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

    private func write(_ prefs: LutinPreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let tmp = storeURL.appendingPathExtension("tmp")
        try encoder.encode(prefs).write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(storeURL, withItemAt: tmp)
    }
}
