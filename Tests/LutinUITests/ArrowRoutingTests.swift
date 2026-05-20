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
        // item.x/y are icon centers (matches DMGLayout + DecorationCompositor),
        // so the route's endpoints equal the raw config coordinates.
        XCTAssertEqual(route?.start, CGPoint(x: 100, y: 200))
        XCTAssertEqual(route?.end,   CGPoint(x: 400, y: 200))
    }

    func testRouteReturnsNilForMissingId() {
        let route = ArrowRouting.route(from: "nope", to: "apps", items: [], iconSize: 96)
        XCTAssertNil(route)
    }
}
