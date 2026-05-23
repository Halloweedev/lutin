import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinPickerTests: XCTestCase {

    func testSelectionBindingRoundTrip() {
        var selection = "B"
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let view = LutinPicker(selection: binding, options: [
            .init(id: "A", label: "Option A"),
            .init(id: "B", label: "Option B"),
            .init(id: "C", label: "Option C"),
        ])
        XCTAssertEqual(view.selection.wrappedValue, "B")
        view.selectForTest("C")
        XCTAssertEqual(selection, "C")
    }

    func testRenderingAttachment() throws {
        let binding = Binding(get: { "A" }, set: { _ in })
        let view = LutinPicker(selection: binding, options: [
            .init(id: "A", label: "Light"),
            .init(id: "B", label: "Dark"),
            .init(id: "C", label: "System"),
        ])
        let png = try renderToPNG(view, size: CGSize(width: 220, height: 28))
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.name = "LutinPicker"
        att.lifetime = .keepAlways
        add(att)
    }
}
