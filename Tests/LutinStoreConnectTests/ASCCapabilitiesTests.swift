import XCTest
@testable import LutinStoreConnect
import LutinCore

final class ASCCapabilitiesTests: XCTestCase {

    private func recorded() throws -> ASCCapabilities {
        try ASCCapabilities.parse(try Fixtures.data("capabilities.json"))
    }

    func testParsesTheRecordedFixture() throws {
        let caps = try recorded()
        XCTAssertFalse(caps.capabilities.isEmpty)
        XCTAssertTrue(caps.capabilities.contains { $0.area == "metadata" })
    }

    /// The real status vocabulary — not the api/webSession/unsupported set the
    /// first draft of the spec assumed.
    func testParsesEveryStatusInTheRealVocabulary() throws {
        let statuses = Set(try recorded().capabilities.map(\.status))
        XCTAssertTrue(statuses.contains(.cliSupported))
        XCTAssertTrue(statuses.contains(.webSession))
        XCTAssertTrue(statuses.contains(.partial))
        XCTAssertTrue(statuses.contains(.notPublicAPI))
    }

    func testUnknownStatusDecodesAsUnknownRatherThanThrowing() throws {
        let json = #"{"capabilities":[{"area":"x","capability":"y","status":"brand-new-status","commands":[]}]}"#
        let caps = try ASCCapabilities.parse(Data(json.utf8))
        XCTAssertEqual(caps.capabilities.first?.status, .unknown)
    }

    /// Lookup is by command string, matched against the `commands` array.
    func testStatusForCommandMatchesMetadataValidate() throws {
        let caps = try recorded()
        XCTAssertEqual(caps.status(forCommand: "asc metadata validate"), .cliSupported)
    }

    /// The bridge queries unprefixed (`metadata validate`) while asc's own
    /// `commands` array is `asc `-prefixed — 110/110 in the recorded fixture.
    /// Both shapes must resolve to the same entry.
    func testCapabilityLookupAcceptsPrefixedAndUnprefixedQueries() throws {
        let caps = try recorded()
        let prefixed = caps.capability(forCommand: "asc metadata validate")
        let unprefixed = caps.capability(forCommand: "metadata validate")
        XCTAssertEqual(unprefixed, prefixed)
        XCTAssertEqual(unprefixed?.area, "metadata")
        XCTAssertEqual(unprefixed?.status, .cliSupported)
    }

    /// Absence of a matching entry is `.unknown` — no evidence, not an error.
    /// The recorded fixture has no `metadata plan` command, so the gating
    /// pass-through for our own plan/approve verbs rests on this.
    func testCapabilityLookupAbsentCommandIsUnknown() throws {
        let caps = try recorded()
        XCTAssertNil(caps.capability(forCommand: "metadata plan"))
        XCTAssertEqual(caps.status(forCommand: "metadata plan"), .unknown)
    }

    func testStatusForCommandMatchesPrefixesWithFlags() throws {
        let caps = try recorded()
        XCTAssertEqual(caps.status(forCommand: "asc metadata apply --app 123 --confirm"),
                       .cliSupported)
    }

    /// Review Focus: absence of evidence must not disable a working feature.
    func testUnknownCommandIsAllowedNotBlocked() throws {
        XCTAssertEqual(try recorded().status(forCommand: "asc something brand new"), .unknown)
        XCTAssertFalse(ASCCapabilityStatus.unknown.isBlocked)
        XCTAssertFalse(ASCCapabilityStatus.cliSupported.isBlocked)
        XCTAssertTrue(ASCCapabilityStatus.notPublicAPI.isBlocked)
    }

    func testWebSessionRequiresASessionRatherThanBeingBlocked() {
        XCTAssertTrue(ASCCapabilityStatus.webSession.requiresWebSession)
        XCTAssertFalse(ASCCapabilityStatus.webSession.isBlocked)
    }

    func testMalformedCapabilitiesRaises() {
        XCTAssertThrowsError(try ASCCapabilities.parse(Data("not json".utf8))) { error in
            XCTAssertEqual((error as? LutinError)?.code, "store_asc_failed")
        }
    }
}
