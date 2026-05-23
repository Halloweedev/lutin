import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinStepperTests: XCTestCase {

    func testIncrementClampsAtMax() {
        var value = 10
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinStepper(value: binding, in: 0...10, step: 1)
        view.incrementForTest()
        XCTAssertEqual(value, 10)
    }

    func testDecrementClampsAtMin() {
        var value = 0
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinStepper(value: binding, in: 0...10, step: 1)
        view.decrementForTest()
        XCTAssertEqual(value, 0)
    }

    func testStepHonored() {
        var value = 0
        let binding = Binding(get: { value }, set: { value = $0 })
        let view = LutinStepper(value: binding, in: 0...10, step: 2)
        view.incrementForTest()
        XCTAssertEqual(value, 2)
    }

    func testRenderingAttachment() throws {
        let binding = Binding(get: { 5 }, set: { _ in })
        let view = LutinStepper(value: binding, in: 0...10, step: 1)
        let png = try renderToPNG(view, size: CGSize(width: 80, height: 28))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinStepper"
        att.lifetime = .keepAlways
        add(att)
    }
}
