import XCTest
import LutinConfig
@testable import LutinUI

final class ArrowRoutingTests: XCTestCase {
    func testRouteFromAtoB() {
        let items = [
            LutinConfig.Item(type: "app", id: "app", x: 100, y: 200, label: nil),
            LutinConfig.Item(type: "applications", id: "apps", x: 400, y: 200, label: nil),
        ]
        let route = ArrowRouting.route(from: "app", to: "apps", items: items, iconSize: 96)
        XCTAssertEqual(route?.start, CGPoint(x: 148, y: 248))   // center of app icon
        XCTAssertEqual(route?.end,   CGPoint(x: 448, y: 248))   // center of apps icon
    }

    func testRouteReturnsNilForMissingId() {
        let route = ArrowRouting.route(from: "nope", to: "apps", items: [], iconSize: 96)
        XCTAssertNil(route)
    }
}
