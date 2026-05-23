import XCTest
import LutinCore
@testable import LutinConfig

final class CuratedTemplatesTests: XCTestCase {
    func testDarkTemplateExists() throws {
        let template = try Templates.named("dark")
        XCTAssertEqual(template.background.type, "solid")
        XCTAssertEqual(template.background.colorA, "#1C1E26")
        XCTAssertFalse(template.background.grid)
    }

    func testWarmTemplateExists() throws {
        let template = try Templates.named("warm")
        XCTAssertEqual(template.background.type, "solid")
        XCTAssertEqual(template.background.colorA, "#FBEFE6")
    }

    func testBlueprintAndMinimalStillExist() throws {
        XCTAssertNoThrow(try Templates.named("blueprint"))
        XCTAssertNoThrow(try Templates.named("minimal"))
    }

    func testUnknownTemplateStillThrows() {
        XCTAssertThrowsError(try Templates.named("nope"))
    }
}
