#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outDir = URL(fileURLWithPath: "Sources/LutinUI/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let slots: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
// BrandAccent light value
let red: CGFloat = 0.290, green: CGFloat = 0.471, blue: CGFloat = 1.000

for (size, scale) in slots {
    let pixels = size * scale
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let image = ctx.makeImage()!
    let suffix = scale == 2 ? "@2x" : ""
    let name = "icon_\(size)\(suffix).png"
    let url = outDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}
print("Wrote 10 placeholder icons to \(outDir.path)")
