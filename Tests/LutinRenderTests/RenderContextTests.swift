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

    // Finder reads the PNG's DPI to map pixels to points. Without an explicit
    // DPI the PNG defaults to 72, which renders @2× backgrounds at twice the
    // intended window size. Verify the custom DPI is round-tripped to disk.
    func testWritesTheRequestedDpiIntoThePngMetadata() throws {
        let ctx = try RenderContext(pixelWidth: 128, pixelHeight: 96)
        let image = ctx.finish()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutin-dpi-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        try RenderContext.writePNG(image, to: url, dpi: 144)

        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(src, 0, nil)
                  as? [CFString: Any] else {
            return XCTFail("Could not read back PNG properties.")
        }
        XCTAssertEqual(properties[kCGImagePropertyDPIWidth] as? CGFloat, 144)
        XCTAssertEqual(properties[kCGImagePropertyDPIHeight] as? CGFloat, 144)
    }
}
