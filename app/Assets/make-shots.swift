// make-shots.swift — compose App Store screenshots (1280×800) from a window capture.
//
//   make-shots <window.png> <out.png> <paper-hex>
//
// The Mac App Store accepts 1280×800 / 1440×900 / 2560×1600 / 2880×1800. The app
// window is 900×668, so it is scaled to fit and centred on the app's own paper
// colour rather than being cropped.

import AppKit
import Foundation

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: make-shots <window.png> <out.png> <paper-hex e.g. 1E1B22>")
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let paper = NSColor(hex: UInt32(args[3], radix: 16) ?? 0x1E1B22)

guard let src = NSImage(contentsOf: inURL),
      let srcRep = src.representations.first else {
    print("cannot read \(inURL.path)")
    exit(1)
}

let canvasW = 1280, canvasH = 800
let margin = 46
let maxW = canvasW - margin * 2
let maxH = canvasH - margin * 2

// Fit preserving aspect ratio.
let scale = min(Double(maxW) / Double(srcRep.pixelsWide), Double(maxH) / Double(srcRep.pixelsHigh))
let drawW = Double(srcRep.pixelsWide) * scale
let drawH = Double(srcRep.pixelsHigh) * scale
let originX = (Double(canvasW) - drawW) / 2
let originY = (Double(canvasH) - drawH) / 2

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvasW, pixelsHigh: canvasH,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

paper.setFill()
NSRect(x: 0, y: 0, width: canvasW, height: canvasH).fill()

let frame = NSRect(x: originX, y: originY, width: drawW, height: drawH)
let clip = NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12)
clip.addClip()
src.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1.0,
         respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
NSGraphicsContext.current?.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Hairline border so the window edge reads against the paper.
NSColor(hex: 0x000000).withAlphaComponent(0.18).setStroke()
let border = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
border.lineWidth = 1
border.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: outURL)
print("wrote \(outURL.path) (\(canvasW)×\(canvasH), window \(Int(drawW))×\(Int(drawH)))")
