import XCTest
@testable import LutinCore

final class LutinErrorTests: XCTestCase {
    func testErrorCarriesCodeAndMessage() {
        let error = LutinError(code: "config_not_found", message: "No config found")
        XCTAssertEqual(error.code, "config_not_found")
        XCTAssertEqual(error.message, "No config found")
        XCTAssertNil(error.details)
    }

    func testFailureEnvelopeEncodesError() throws {
        let error = LutinError(code: "bad", message: "broke", details: ["field": "app.path"])
        let envelope = JSONEnvelope<EmptyPayload>.failure(error)
        let data = try JSONEncoder().encode(envelope)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"ok\":false"))
        XCTAssertTrue(json.contains("\"code\":\"bad\""))
        XCTAssertTrue(json.contains("\"field\":\"app.path\""))
    }

    func testSuccessEnvelopeEncodesData() throws {
        struct Payload: Encodable { let name: String }
        let envelope = JSONEnvelope.success(Payload(name: "Barry"))
        let data = try JSONEncoder().encode(envelope)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"ok\":true"))
        XCTAssertTrue(json.contains("\"name\":\"Barry\""))
    }
}
