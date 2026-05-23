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
        XCTAssertEqual(template.background.colorA, "#FFFFFF")
    }

    func testMinimalAndWarmStillExist() throws {
        XCTAssertNoThrow(try Templates.named("minimal"))
        XCTAssertNoThrow(try Templates.named("warm"))
    }

    func testUnknownTemplateStillThrows() {
        XCTAssertThrowsError(try Templates.named("nope"))
    }

    func testBlueprintNameNoLongerResolves() {
        XCTAssertThrowsError(try Templates.named("blueprint")) { error in
            XCTAssertEqual((error as? LutinError)?.code, "unknown_template")
        }
    }
}
