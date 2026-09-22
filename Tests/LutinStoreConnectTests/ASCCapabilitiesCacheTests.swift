import XCTest
@testable import LutinStoreConnect
import LutinCore
import TestSupport

/// Spec §4.3's capability cache. Every test injects its own file URL, so the
/// suite can never read or write the real `~/Library` cache, and its own
/// `FakeCommandRunner`, so it can never reach a real asc.
final class ASCCapabilitiesCacheTests: XCTestCase {

    private static let capabilitiesJSON = #"""
    {"capabilities":[{"area":"metadata","capability":"Metadata and localization sync",
      "status":"cli-supported","commands":["asc metadata plan"]}]}
    """#

    private func capabilities() throws -> ASCCapabilities {
        try ASCCapabilities.parse(Data(Self.capabilitiesJSON.utf8))
    }

    /// A movable clock. The cache's `now` is `@Sendable`, so the test cannot
    /// close over a `var`.
    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-asc-cache-\(UUID().uuidString).json")
    }

    /// A real file standing in for the asc binary. The cache records which
    /// binary an answer came from, so the path has to exist to be identified —
    /// and a real asc path always does.
    private func makeAscBinary(_ body: String = "asc") throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-fake-asc-\(UUID().uuidString)")
        try Data(body.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url.path
    }

    /// Rewrites the binary in place, as an upgrade would.
    private func replace(_ ascPath: String, with body: String) throws {
        try Data(body.utf8).write(to: URL(fileURLWithPath: ascPath))
        // Some filesystems record whole seconds; move the clock explicitly so
        // the test cannot pass or fail on mtime granularity.
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000_000)],
            ofItemAtPath: ascPath)
    }

    private func fakeAsc(_ ascPath: String, version: String = "5.3.0") -> FakeCommandRunner {
        let fake = FakeCommandRunner()
        fake.stub(executable: ascPath, argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0, stdout: "\(version)\n", stderr: ""))
        fake.stub(executable: ascPath, argumentsContaining: "capabilities",
                  result: ShellResult(exitCode: 0, stdout: Self.capabilitiesJSON, stderr: ""))
        return fake
    }

    func testASecondProbeForTheSameVersionDoesNotInvokeAscAgain() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        let fake = fakeAsc(asc)

        _ = try ASCProbe.capabilities(ascPath: asc, runner: fake, cache: cache)
        _ = try ASCProbe.capabilities(ascPath: asc, runner: fake, cache: cache)

        XCTAssertEqual(fake.invocations.count, 2, "one version probe, one capabilities probe")
    }

    /// A cached entry recorded for 5.2.0 must not answer for 5.3.0 (§4.3).
    func testAnUpgradeInvalidatesTheCapabilities() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        cache.store(version: "5.2.0", capabilities: try capabilities(), for: asc)

        XCTAssertNil(cache.capabilities(for: asc, version: "5.3.0"))
        XCTAssertNotNil(cache.capabilities(for: asc, version: "5.2.0"))
    }

    func testAnExpiredEntryIsAMiss() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let clock = Clock(Date(timeIntervalSince1970: 1_000_000))
        let cache = ASCCapabilitiesCache(url: url, ttl: 60, now: { clock.now })
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: asc)
        XCTAssertNotNil(cache.capabilities(for: asc, version: "5.3.0"))

        clock.now = clock.now.addingTimeInterval(61)

        XCTAssertNil(cache.capabilities(for: asc, version: "5.3.0"))
        XCTAssertNil(cache.version(for: asc), "an expired record answers nothing")
    }

    func testAPersistedEntrySurvivesANewCacheInstance() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        ASCCapabilitiesCache(url: url, ttl: 3600)
            .store(version: "5.3.0", capabilities: try capabilities(), for: asc)

        XCTAssertEqual(ASCCapabilitiesCache(url: url, ttl: 3600)
            .capabilities(for: asc, version: "5.3.0"), try capabilities())
    }

    /// The cache is an optimisation, never a correctness dependency: a file
    /// someone edited by hand is a miss, not a crash.
    func testAMalformedCacheFileIsIgnoredNotFatal() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)

        XCTAssertNil(cache.capabilities(for: asc, version: "5.3.0"))
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: asc)
        XCTAssertEqual(cache.capabilities(for: asc, version: "5.3.0"),
                       try capabilities())
    }

    /// An unsupported asc is rejected on every probe — the cache must not turn
    /// a version check into something that happens once and is then assumed.
    func testTooOldAnAscIsRejectedAndNotCached() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        let fake = fakeAsc(asc, version: "5.2.0")

        XCTAssertThrowsError(try ASCProbe.version(ascPath: asc, runner: fake,
                                                  cache: cache)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_too_old")
        }
        XCTAssertNil(cache.version(for: asc), "a rejected version is not recorded")
    }

    /// The binary behind a path can be replaced without the path changing —
    /// that is what `brew upgrade` does. A recorded answer belongs to the
    /// binary it was recorded against, not to the path.
    func testAReplacedBinaryIsAMissEvenInsideTheTTL() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: asc)
        XCTAssertEqual(cache.version(for: asc), "5.3.0")

        try replace(asc, with: "a different asc")

        XCTAssertNil(cache.version(for: asc), "a new binary is a new answer")
        XCTAssertNil(cache.capabilities(for: asc, version: "5.3.0"))
    }

    /// The recovery path when a persisted entry is wrong: a stale capability
    /// reported as `not-public-api` blocks a command that works, and deleting
    /// a file is not something anyone should have to guess at.
    func testTheEnvironmentCanTurnTheCacheOff() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        setenv("LUTIN_ASC_CACHE", "0", 1)
        defer { unsetenv("LUTIN_ASC_CACHE") }

        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: asc)

        XCTAssertNil(cache.version(for: asc))
        XCTAssertNil(cache.capabilities(for: asc, version: "5.3.0"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "a disabled cache writes nothing")

        let fake = fakeAsc(asc)
        _ = try ASCProbe.capabilities(ascPath: asc, runner: fake, cache: cache)
        _ = try ASCProbe.capabilities(ascPath: asc, runner: fake, cache: cache)
        XCTAssertEqual(fake.invocations.filter { $0.arguments.contains("capabilities") }.count, 2,
                       "every call probes when the cache is off")
    }

    /// The version pin is not something the cache may retire. Downgrading asc
    /// under a cached entry must still be rejected — a cached version that
    /// skipped `assertSupported` would gate `metadata apply` against a
    /// capability table the installed binary never reported.
    func testADowngradedAscIsRejectedRatherThanAnsweredFromTheCache() throws {
        let asc = try makeAscBinary()
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        _ = try ASCProbe.version(ascPath: asc, runner: fakeAsc(asc), cache: cache)
        XCTAssertEqual(cache.version(for: asc), "5.3.0")

        try replace(asc, with: "an older asc")

        XCTAssertThrowsError(try ASCProbe.version(ascPath: asc,
                                                  runner: fakeAsc(asc, version: "4.0.0"),
                                                  cache: cache)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_too_old")
        }
    }
}
