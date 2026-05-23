import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinNumericFieldTests: XCTestCase {

    func testRestFillIsSurfaceElevated() {
        let binding = Binding<Int>(get: { 0 }, set: { _ in })
        let view = LutinNumericField("", value: binding, format: .number)
        XCTAssertEqual(view.restFillKey, .surfaceElevated)
    }

    func testBindingRoundTrip() {
        let binding = Binding<Int>(get: { 42 }, set: { _ in })
        let view = LutinNumericField("x", value: binding, format: .number)
        XCTAssertEqual(view.value.wrappedValue, 42)
    }

    func testRenderingAttachment() throws {
        let binding = Binding<Int>(get: { 123 }, set: { _ in })
        let view = LutinNumericField("x", value: binding, format: .number)
        let png = try renderToPNG(view, size: CGSize(width: 80, height: 28))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinNumericField-rest"
        att.lifetime = .keepAlways
        add(att)
    }
}
