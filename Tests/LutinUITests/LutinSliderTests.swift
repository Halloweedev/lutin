import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinSliderTests: XCTestCase {

    func testValueBindingRoundTrip() {
        var value = 0.5
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinSlider(value: binding, in: 0...1)
        view.setForTest(0.75)
        XCTAssertEqual(value, 0.75, accuracy: 0.001)
    }

    func testClampsAtBounds() {
        var value = 0.5
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinSlider(value: binding, in: 0...1)
        view.setForTest(2.0)
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
        view.setForTest(-1.0)
        XCTAssertEqual(value, 0.0, accuracy: 0.001)
    }

    func testRenderingAttachment() throws {
        let binding = Binding(get: { 0.5 }, set: { _ in })
        let view = LutinSlider(value: binding, in: 0...1)
        let png = try renderToPNG(view, size: CGSize(width: 200, height: 20))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinSlider"
        att.lifetime = .keepAlways
        add(att)
    }
}
