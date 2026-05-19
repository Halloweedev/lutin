import XCTest
import CoreGraphics
import LutinCore
@testable import LutinRender

final class BackgroundStyleTests: XCTestCase {
    private func pngBytes(_ image: CGImage) -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-style-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try! RenderContext.writePNG(image, to: url)
        return (try? Data(contentsOf: url)) ?? Data()
    }

    private func spec(grid: Bool, noise: Double, cornerRadius: Int) -> BackgroundSpec {
        BackgroundSpec(kind: .generated, widthPoints: 120, heightPoints: 120, scale: 2,
                       colorA: "#EEF4FF", colorB: "#DDE8FF", grid: grid, noise: noise,
                       cornerRadius: cornerRadius, imageURL: nil)
    }

    func testGridChangesTheOutput() throws {
        let plain = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0, cornerRadius: 0))
        let withGrid = try BackgroundRenderer().renderBase(spec(grid: true, noise: 0, cornerRadius: 0))
        XCTAssertNotEqual(pngBytes(plain), pngBytes(withGrid))
    }

    func testNoiseChangesTheOutput() throws {
        let plain = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0, cornerRadius: 0))
        let noisy = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0.05, cornerRadius: 0))
        XCTAssertNotEqual(pngBytes(plain), pngBytes(noisy))
    }

    func testCornerRadiusChangesTheOutput() throws {
        let fullBleed = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0, cornerRadius: 0))
        let rounded = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0, cornerRadius: 24))
        XCTAssertNotEqual(pngBytes(fullBleed), pngBytes(rounded))
    }

    func testNoiseIsDeterministic() throws {
        let a = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0.05, cornerRadius: 0))
        let b = try BackgroundRenderer().renderBase(spec(grid: false, noise: 0.05, cornerRadius: 0))
        XCTAssertEqual(pngBytes(a), pngBytes(b))
    }
}
