import XCTest
import LutinCore
@testable import LutinConfig

final class CuratedTemplatesTests: XCTestCase {
    func testDarkTemplateExists() throws {
        let template = try Templates.named("dark")
        XCTAssertEqual(template.background.template, "dark")
        XCTAssertTrue(template.background.grid)
    }

    func testWarmTemplateExists() throws {
        let template = try Templates.named("warm")
        XCTAssertEqual(template.background.template, "warm")
    }

    func testBlueprintAndMinimalStillExist() throws {
        XCTAssertNoThrow(try Templates.named("blueprint"))
        XCTAssertNoThrow(try Templates.named("minimal"))
    }

    func testUnknownTemplateStillThrows() {
        XCTAssertThrowsError(try Templates.named("nope"))
    }
}
