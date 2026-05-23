import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinToggleTests: XCTestCase {

    func testBindingFlipsOnInteraction() {
        var value = false
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinToggle("Show toolbar", isOn: binding)
        view.toggleForTest()
        XCTAssertTrue(value)
        view.toggleForTest()
        XCTAssertFalse(value)
    }

    func testRenderingAttachmentOn() throws {
        let binding = Binding(get: { true }, set: { _ in })
        let view = LutinToggle("Show toolbar", isOn: binding)
        let png = try renderToPNG(view, size: CGSize(width: 200, height: 24))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinToggle-on"
        att.lifetime = .keepAlways
        add(att)
    }

    func testRenderingAttachmentOff() throws {
        let binding = Binding(get: { false }, set: { _ in })
        let view = LutinToggle("Show toolbar", isOn: binding)
        let png = try renderToPNG(view, size: CGSize(width: 200, height: 24))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinToggle-off"
        att.lifetime = .keepAlways
        add(att)
    }
}
