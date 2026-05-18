import XCTest
import LutinCore
@testable import LutinCLI

final class OutputRendererTests: XCTestCase {
    struct Payload: Encodable { let name: String }

    func testJsonSuccessProducesEnvelope() throws {
        let json = OutputRenderer.jsonString(success: Payload(name: "Barry"))
        XCTAssertTrue(json.contains("\"ok\":true"))
        XCTAssertTrue(json.contains("\"name\":\"Barry\""))
    }

    func testJsonFailureProducesEnvelope() {
        let error = LutinError(code: "license_required", message: "nope")
        let json = OutputRenderer.jsonString(failure: error)
        XCTAssertTrue(json.contains("\"ok\":false"))
        XCTAssertTrue(json.contains("\"code\":\"license_required\""))
    }
}
