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

    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lutin-asc-cache-\(UUID().uuidString).json")
    }

    private func fakeAsc() -> FakeCommandRunner {
        let fake = FakeCommandRunner()
        fake.stub(executable: "/fake/asc", argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0, stdout: "5.3.0\n", stderr: ""))
        fake.stub(executable: "/fake/asc", argumentsContaining: "capabilities",
                  result: ShellResult(exitCode: 0, stdout: Self.capabilitiesJSON, stderr: ""))
        return fake
    }

    func testASecondProbeForTheSameVersionDoesNotInvokeAscAgain() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        let fake = fakeAsc()

        _ = try ASCProbe.capabilities(ascPath: "/fake/asc", runner: fake, cache: cache)
        _ = try ASCProbe.capabilities(ascPath: "/fake/asc", runner: fake, cache: cache)

        XCTAssertEqual(fake.invocations.count, 2, "one version probe, one capabilities probe")
    }

    /// A cached entry recorded for 5.2.0 must not answer for 5.3.0 (§4.3).
    func testAnUpgradeInvalidatesTheCapabilities() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        cache.store(version: "5.2.0", capabilities: try capabilities(), for: "/fake/asc")

        XCTAssertNil(cache.capabilities(for: "/fake/asc", version: "5.3.0"))
        XCTAssertNotNil(cache.capabilities(for: "/fake/asc", version: "5.2.0"))
    }

    func testAnExpiredEntryIsAMiss() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var now = Date(timeIntervalSince1970: 1_000_000)
        let cache = ASCCapabilitiesCache(url: url, ttl: 60, now: { now })
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: "/fake/asc")
        XCTAssertNotNil(cache.capabilities(for: "/fake/asc", version: "5.3.0"))

        now = now.addingTimeInterval(61)

        XCTAssertNil(cache.capabilities(for: "/fake/asc", version: "5.3.0"))
        XCTAssertNil(cache.version(for: "/fake/asc"), "an expired record answers nothing")
    }

    func testAPersistedEntrySurvivesANewCacheInstance() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        ASCCapabilitiesCache(url: url, ttl: 3600)
            .store(version: "5.3.0", capabilities: try capabilities(), for: "/fake/asc")

        XCTAssertEqual(ASCCapabilitiesCache(url: url, ttl: 3600)
            .capabilities(for: "/fake/asc", version: "5.3.0"), try capabilities())
    }

    /// The cache is an optimisation, never a correctness dependency: a file
    /// someone edited by hand is a miss, not a crash.
    func testAMalformedCacheFileIsIgnoredNotFatal() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)

        XCTAssertNil(cache.capabilities(for: "/fake/asc", version: "5.3.0"))
        cache.store(version: "5.3.0", capabilities: try capabilities(), for: "/fake/asc")
        XCTAssertEqual(cache.capabilities(for: "/fake/asc", version: "5.3.0"),
                       try capabilities())
    }

    /// An unsupported asc is rejected on every probe — the cache must not turn
    /// a version check into something that happens once and is then assumed.
    func testTooOldAnAscIsRejectedAndNotCached() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ASCCapabilitiesCache(url: url, ttl: 3600)
        let fake = FakeCommandRunner()
        fake.stub(executable: "/fake/asc", argumentsContaining: "--version",
                  result: ShellResult(exitCode: 0, stdout: "5.2.0\n", stderr: ""))

        XCTAssertThrowsError(try ASCProbe.version(ascPath: "/fake/asc", runner: fake,
                                                  cache: cache)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_too_old")
        }
        XCTAssertNil(cache.version(for: "/fake/asc"), "a rejected version is not recorded")
    }
}
