import XCTest
import SwiftUI
@testable import LutinUI

@MainActor
final class LutinButtonTests: XCTestCase {

    func testPrimaryRoleResolvesAccentRestFill() {
        let view = LutinButton("Build", role: .primary, action: {})
        XCTAssertEqual(view.restFillKey, .brandAccent)
    }

    func testSecondaryRoleResolvesSurfaceRestFill() {
        let view = LutinButton("Cancel", role: .secondary, action: {})
        XCTAssertEqual(view.restFillKey, .surface)
    }

    func testActionFires() {
        var fired = false
        let view = LutinButton("Tap", role: .secondary, action: { fired = true })
        view.invokeForTest()
        XCTAssertTrue(fired)
    }

    func testRenderingAttachment() throws {
        for role in [LutinButton<Text>.Role.primary, .secondary] {
            for label in ["Build", "Cancel"] {
                let view = LutinButton(label, role: role, action: {})
                let png = try renderToPNG(view, size: CGSize(width: 200, height: 32))
                let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                att.name = "LutinButton-\(role)-\(label)"
                att.lifetime = .keepAlways
                add(att)
            }
        }
    }
}
