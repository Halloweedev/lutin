import XCTest
@testable import LutinConfig

final class TokenResolverTests: XCTestCase {
    func testResolvesVersionToken() {
        let context = TokenResolver.Context(version: "1.0.0", name: "Barry")
        XCTAssertEqual(TokenResolver.resolve("Barry-${version}.dmg", context), "Barry-1.0.0.dmg")
    }

    func testResolvesNameToken() {
        let context = TokenResolver.Context(version: "2.3", name: "Barry")
        XCTAssertEqual(TokenResolver.resolve("${name}-${version}", context), "Barry-2.3")
    }

    func testResolvesBuildToken() {
        let context = TokenResolver.Context(version: "2.3", name: "Barry", build: "42")
        XCTAssertEqual(TokenResolver.resolve("${name}-${version}-${build}", context), "Barry-2.3-42")
    }

    func testLeavesUnknownTokensUntouched() {
        let context = TokenResolver.Context(version: "1.0.0", name: "Barry")
        XCTAssertEqual(TokenResolver.resolve("a-${unknown}-b", context), "a-${unknown}-b")
    }
}
