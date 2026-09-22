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
        /// Which binary this answer came from. See `fingerprint(of:)`.
        let fingerprint: String?
        let version: String
        let cachedAt: Date
        let capabilities: ASCCapabilities?
    }

    private struct Store: Codable { var entries: [String: Entry] }

    /// `~/Library/Application Support/Lutin/asc-capabilities.json`, built the
    /// way `Registry` and `PreferencesStore` build theirs.
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Lutin")
            .appendingPathComponent("asc-capabilities.json")
    }

    /// `LUTIN_ASC_CACHE=0` turns the cache off. The gating direction is the
    /// one worth an escape hatch: a stale entry that reports a capability as
    /// `not-public-api` blocks a command that in fact works, and without this
    /// the only recovery is knowing which file to delete.
    static var isEnabledByEnvironment: Bool {
        ProcessInfo.processInfo.environment["LUTIN_ASC_CACHE"] != "0"
    }

    private let url: URL
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private let isEnabled: Bool
    private let lock = NSLock()
    /// `nil` until the file has been read once. A missing or malformed file
    /// loads as an empty map — the cache is an optimisation, never a
    /// correctness dependency.
    private var entries: [String: Entry]?

    public init(url: URL = ASCCapabilitiesCache.defaultURL,
                ttl: TimeInterval = 24 * 3600,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.url = url
        self.ttl = ttl
        self.now = now
        self.isEnabled = Self.isEnabledByEnvironment
    }

    /// The version recorded for this path, when the record is fresh and was
    /// recorded against the binary that is there now.
    func version(for ascPath: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return fresh(ascPath)?.version
    }

    /// Capabilities recorded for this path, only when they were recorded for
    /// `version` — that is the upgrade invalidation.
    func capabilities(for ascPath: String, version: String) -> ASCCapabilities? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = fresh(ascPath), entry.version == version else { return nil }
        return entry.capabilities
    }

    func store(version: String, capabilities: ASCCapabilities?, for ascPath: String) {
        guard isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        var map = loaded()
        map[ascPath] = Entry(ascPath: ascPath, fingerprint: Self.fingerprint(of: ascPath),
                             version: version, cachedAt: now(), capabilities: capabilities)
        entries = map
        persist(map)
    }

    // MARK: - Storage

    /// The entry for a path when it has not aged out **and** was recorded
    /// against the binary that is there now.
    ///
    /// The binary check is what makes it safe for `ASCProbe` to skip
    /// `ASCToolVersion.assertSupported` on a hit: the pin is a pure function
    /// of the version string, and a version is only ever recorded after it
    /// passed. An unchanged binary reports the version it reported before, so
    /// re-asserting it could not reach a different answer. A changed binary is
    /// a miss, and gets the full probe.
    private func fresh(_ ascPath: String) -> Entry? {
        guard isEnabled, let entry = loaded()[ascPath] else { return nil }
        // A `cachedAt` in the future is a clock that moved, not a fresh record.
        guard (0..<ttl).contains(now().timeIntervalSince(entry.cachedAt)) else { return nil }
        guard let fingerprint = Self.fingerprint(of: ascPath),
              entry.fingerprint == fingerprint else { return nil }
        return entry
    }

    /// Identity of the binary behind a path: the resolved path, its size and
    /// its modification date. `brew upgrade` lands a different file in the
    /// Cellar and repoints the symlink, so both an upgrade and a downgrade
    /// change this. Unreadable is `nil`, which never matches — the cache then
    /// degrades to probing every time, which is the safe direction.
    private static func fingerprint(of ascPath: String) -> String? {
        let resolved = URL(fileURLWithPath: ascPath).resolvingSymlinksInPath().path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolved),
              let size = attributes[.size] as? Int,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return "\(resolved):\(size):\(modified.timeIntervalSince1970)"
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

    /// The recorded version when it belongs to the binary that is there now;
    /// otherwise `asc --version`, checked against the pin before anything is
    /// recorded. A version is never stored unasserted, and a record never
    /// outlives the binary it describes, so no asc reaches a command without
    /// having passed the pin.
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

        // A miss means the previous record was expired, absent, or another
        // binary's — there are no capabilities worth carrying into this one.
        cache?.store(version: version, capabilities: nil, for: ascPath)
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
