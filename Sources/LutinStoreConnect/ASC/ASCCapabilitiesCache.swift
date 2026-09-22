import Foundation
import LutinCore

/// Spec §4.3's capability cache: held in memory per process, persisted with a
/// TTL, keyed by the asc binary path **and version**, so an upgrade invalidates
/// it. The URL is injectable — without that, the "zero network, zero asc" tests
/// would touch the real filesystem.
///
/// Concurrency: the package is `swiftLanguageModes: [.v5]`, so there is no
/// compiler backstop (§4.1). The mutable dictionary is confined by an explicit
/// lock, and the type says so with `@unchecked Sendable`.
public final class ASCCapabilitiesCache: @unchecked Sendable {

    struct Entry: Codable, Equatable {
        let ascPath: String
        let version: String
        let cachedAt: Date
        let capabilities: ASCCapabilities?
    }

    private struct Store: Codable { var entries: [String: Entry] }

    public static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Lutin/asc-capabilities.json")
    }

    private let url: URL
    private let ttl: TimeInterval
    private let now: () -> Date
    private let lock = NSLock()
    /// `nil` until the file has been read once. A missing or malformed file
    /// loads as an empty map — the cache is an optimisation, never a
    /// correctness dependency.
    private var entries: [String: Entry]?

    public init(url: URL = ASCCapabilitiesCache.defaultURL,
                ttl: TimeInterval = 24 * 3600,
                now: @escaping () -> Date = Date.init) {
        self.url = url
        self.ttl = ttl
        self.now = now
    }

    /// The version recorded for this path, when the record is fresh.
    public func version(for ascPath: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return fresh(ascPath)?.version
    }

    /// Capabilities recorded for this path, only when they were recorded for
    /// `version` — that is the upgrade invalidation.
    public func capabilities(for ascPath: String, version: String) -> ASCCapabilities? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = fresh(ascPath), entry.version == version else { return nil }
        return entry.capabilities
    }

    public func store(version: String, capabilities: ASCCapabilities?, for ascPath: String) {
        lock.lock(); defer { lock.unlock() }
        var map = loaded()
        map[ascPath] = Entry(ascPath: ascPath, version: version,
                             cachedAt: now(), capabilities: capabilities)
        entries = map
        persist(map)
    }

    // MARK: - Storage

    /// The entry for a path when it has not aged out.
    private func fresh(_ ascPath: String) -> Entry? {
        guard let entry = loaded()[ascPath] else { return nil }
        guard now().timeIntervalSince(entry.cachedAt) < ttl else { return nil }
        return entry
    }

    private func loaded() -> [String: Entry] {
        if let entries { return entries }
        let map = (try? Data(contentsOf: url))
            .flatMap { try? JSONDecoder().decode(Store.self, from: $0) }?
            .entries ?? [:]
        entries = map
        return map
    }

    /// A write failure is ignored on purpose: a cache that cannot be written
    /// costs a probe, and nothing else.
    private func persist(_ map: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(Store(entries: map)) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

/// Fronts asc's two probes with the cache in front of them. `nil` cache means
/// always probe — the CLI's one-shot commands keep today's behaviour.
enum ASCProbe {

    /// The cached version when fresh; otherwise `asc --version`, checked
    /// against the pin before anything is recorded — an unsupported asc is
    /// rejected on every call, never cached into an assumption.
    static func version(ascPath: String, runner: CommandRunning,
                        cache: ASCCapabilitiesCache?) throws -> String {
        if let cached = cache?.version(for: ascPath) { return cached }

        let result = try runner.runAllowingFailure(ascPath, ["--version"])
        guard result.exitCode == 0 else {
            throw ASCErrorMapping.map(result: result, command: ["--version"],
                                      fallbackCode: "store_asc_failed")
        }
        try ASCToolVersion.assertSupported(result.stdout)
        let version = ASCToolVersion(result.stdout)?.description
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        // The capabilities recorded against a different version are not this
        // version's capabilities — an upgrade drops them.
        let carried = cache?.capabilities(for: ascPath, version: version)
        cache?.store(version: version, capabilities: carried, for: ascPath)
        return version
    }

    /// Capabilities are keyed by version, so a cache means a version probe
    /// first. Without a cache there is nothing to key, and asking asc for its
    /// version would be a round-trip bought for nobody — so the uncached path
    /// loads exactly what `gate` loaded before the cache existed.
    static func capabilities(ascPath: String, runner: CommandRunning,
                             cache: ASCCapabilitiesCache?) throws -> ASCCapabilities {
        guard let cache else {
            return try ASCCapabilities.load(ascPath: ascPath, runner: runner)
        }
        let version = try version(ascPath: ascPath, runner: runner, cache: cache)
        if let cached = cache.capabilities(for: ascPath, version: version) { return cached }

        let loaded = try ASCCapabilities.load(ascPath: ascPath, runner: runner)
        cache.store(version: version, capabilities: loaded, for: ascPath)
        return loaded
    }
}
