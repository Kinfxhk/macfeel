// make-icon.swift — draws the macfeel app icon (no design tool, no dependencies).
// Run via Assets/make-icon.sh; output: Assets/AppIcon.icns

import AppKit
import Foundation

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

func draw(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // Rounded-square ground: warm dusk gradient.
    let inset = s * 0.06
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = s * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [NSColor(hex: 0x322B3A), NSColor(hex: 0x18151C)])!
    gradient.draw(in: path, angle: -90)

    // Three slider tracks: the product in one glyph.
    let track = NSColor(hex: 0xECE7E1).withAlphaComponent(0.85)
    let amber = NSColor(hex: 0xE0895F)
    let rows: [(y: CGFloat, knob: CGFloat)] = [(0.66, 0.34), (0.50, 0.66), (0.34, 0.22)]
    let left = s * 0.20, right = s * 0.80, thickness = max(1.5, s * 0.03)
    for row in rows {
        let y = s * row.y
        let line = NSRect(x: left, y: y - thickness / 2, width: right - left, height: thickness)
        track.setFill()
        NSBezierPath(roundedRect: line, xRadius: thickness / 2, yRadius: thickness / 2).fill()

        let knobR = s * 0.062
        let cx = left + (right - left) * row.knob
        let knobRect = NSRect(x: cx - knobR, y: y - knobR, width: knobR * 2, height: knobR * 2)
        NSColor(hex: 0x18151C).setFill()
        NSBezierPath(ovalIn: knobRect.insetBy(dx: -knobR * 0.12, dy: -knobR * 0.12)).fill()
        amber.setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for px in sizes {
    guard let data = draw(px) else { continue }
    let names = px == 16 ? ["icon_16x16.png"]
        : px == 32 ? ["icon_16x16@2x.png", "icon_32x32.png"]
        : px == 64 ? ["icon_32x32@2x.png"]
        : px == 128 ? ["icon_128x128.png"]
        : px == 256 ? ["icon_128x128@2x.png", "icon_256x256.png"]
        : px == 512 ? ["icon_256x256@2x.png", "icon_512x512.png"]
        : ["icon_512x512@2x.png"]
    for name in names {
        try? data.write(to: iconset.appendingPathComponent(name))
    }
    try? data.write(to: outDir.appendingPathComponent("icon-\(px).png"))
    print("drew \(px)px")
}
