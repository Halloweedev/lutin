import XCTest
import SwiftUI
import AppKit

@MainActor
func renderToPNG<V: View>(_ view: V, size: CGSize) throws -> Data {
    let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    hosting.frame = CGRect(origin: .zero, size: size)
    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        throw NSError(domain: "render", code: 1)
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 2)
    }
    return png
}

/// Renders a view hosted in a borderless window and, when
/// `LUTIN_PREVIEW_DUMP=1`, writes the PNG to `/tmp/<dumpName>.png`.
///
/// The window is what makes a `ScrollView` lay out before `cacheDisplay`;
/// the dump name is a parameter so each suite keeps its own `/tmp` filenames.
@MainActor
func snapshotPNG<V: View>(_ view: V, size: CGSize, dumpName: String) -> NSBitmapImageRep {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    window.displayIfNeeded()

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    host.cacheDisplay(in: host.bounds, to: rep)

    if ProcessInfo.processInfo.environment["LUTIN_PREVIEW_DUMP"] == "1" {
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: "/tmp/\(dumpName).png"))
    }
    return rep
}

/// A sampled colour signature: enough to tell "painted something" from
/// "painted a flat rectangle", and light from dark.
@MainActor
func sampledColors(_ rep: NSBitmapImageRep) -> Set<UInt32> {
    var seen = Set<UInt32>()
    for x in stride(from: 0, to: rep.pixelsWide, by: 7) {
        for y in stride(from: 0, to: rep.pixelsHigh, by: 7) {
            guard let color = rep.colorAt(x: x, y: y) else { continue }
            let packed = (UInt32(color.redComponent * 255) << 16)
                | (UInt32(color.greenComponent * 255) << 8)
                | UInt32(color.blueComponent * 255)
            seen.insert(packed)
        }
    }
    return seen
}
