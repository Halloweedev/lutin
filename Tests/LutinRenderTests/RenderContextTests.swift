import XCTest
import CoreGraphics
import ImageIO
@testable import LutinRender

final class RenderContextTests: XCTestCase {
    func testCreatesAContextOfTheRequestedPixelSize() throws {
        let ctx = try RenderContext(pixelWidth: 200, pixelHeight: 120)
        XCTAssertEqual(ctx.cg.width, 200)
        XCTAssertEqual(ctx.cg.height, 120)
    }

    func testFinishProducesAValidCGImage() throws {
        let ctx = try RenderContext(pixelWidth: 50, pixelHeight: 40)
        let image = ctx.finish()
        XCTAssertEqual(image.width, 50)
        XCTAssertEqual(image.height, 40)
    }

    func testWritesAPngFileThatReadsBackAtTheSameSize() throws {
        let ctx = try RenderContext(pixelWidth: 64, pixelHeight: 48)
        let image = ctx.finish()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-ctx-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        try RenderContext.writePNG(image, to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let src = CGImageSourceCreateWithURL(url as CFURL, nil)
        let readBack = src.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        XCTAssertEqual(readBack?.width, 64)
        XCTAssertEqual(readBack?.height, 48)
    }
}
