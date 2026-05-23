import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinTextFieldTests: XCTestCase {

    func testRestFillIsSurfaceElevated() {
        let binding = Binding(get: { "" }, set: { _ in })
        let view = LutinTextField("Bundle ID", text: binding)
        XCTAssertEqual(view.restFillKey, .surfaceElevated)
    }

    func testBindingRoundTrip() {
        let binding = Binding(get: { "before" }, set: { _ in })
        let view = LutinTextField("Field", text: binding)
        XCTAssertEqual(view.text.wrappedValue, "before")
    }

    func testRenderingAttachment() throws {
        let binding = Binding(get: { "Sample" }, set: { _ in })
        let view = LutinTextField("Placeholder", text: binding)
        let png = try renderToPNG(view, size: CGSize(width: 220, height: 28))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinTextField-rest"
        att.lifetime = .keepAlways
        add(att)
    }
}
