import XCTest
@testable import LutinUI

final class AutoIDGenerationTests: XCTestCase {
    func testSlugifyBasic() {
        XCTAssertEqual(CanvasFileDropDelegate.slugify("Lutin"), "lutin")
        XCTAssertEqual(CanvasFileDropDelegate.slugify("My App"), "my-app")
        XCTAssertEqual(CanvasFileDropDelegate.slugify("Foo_Bar.123"), "foo-bar-123")
    }
    func testSlugifyTrimsAndCollapses() {
        XCTAssertEqual(CanvasFileDropDelegate.slugify("  --hi---there--  "), "hi-there")
    }
    func testSlugifyEmptyFallback() {
        XCTAssertEqual(CanvasFileDropDelegate.slugify(""), "item")
        XCTAssertEqual(CanvasFileDropDelegate.slugify("   "), "item")
    }
    func testUniqueIDSuffixes() {
        let existing: Set<String> = ["lutin", "lutin-2"]
        XCTAssertEqual(CanvasFileDropDelegate.uniqueID("lutin", existing: existing), "lutin-3")
    }
    func testUniqueIDNoSuffixWhenFree() {
        XCTAssertEqual(CanvasFileDropDelegate.uniqueID("barry", existing: []), "barry")
    }
}
