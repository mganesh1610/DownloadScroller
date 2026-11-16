import AppKit

// Original vector artwork, rendered at each macOS app icon size.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let sizes = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (points, scale) in sizes {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let base = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.23, blue: 0.27, alpha: 1),
               ending: NSColor(srgbRed: 0.055, green: 0.10, blue: 0.15, alpha: 1))!.draw(in: base, angle: -70)
    NSColor.white.withAlphaComponent(0.12).setStroke(); base.lineWidth = 3; base.stroke()
    for index in (0..<3).reversed() {
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: 740, y: 350)
        context.cgContext.rotate(by: CGFloat(index) * -0.20)
        let rect = NSRect(x: -510, y: CGFloat(index) * 80, width: 565, height: 240)
        let card = NSBezierPath(roundedRect: rect, xRadius: 48, yRadius: 48)
        let color = [NSColor(srgbRed: 0.64, green: 0.94, blue: 0.81, alpha: 1),
                     NSColor(srgbRed: 0.35, green: 0.69, blue: 0.66, alpha: 1),
                     NSColor(srgbRed: 0.24, green: 0.45, blue: 0.49, alpha: 1)][index]
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23)
        shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -8); shadow.set()
        color.setFill(); card.fill()
        NSGraphicsContext.restoreGraphicsState()
        if index == 0 {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: -370, y: 120)); line.line(to: NSPoint(x: -160, y: 120))
            line.lineWidth = 20; line.lineCapStyle = .round
            NSColor(srgbRed: 0.08, green: 0.23, blue: 0.25, alpha: 0.6).setStroke(); line.stroke()
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: -45, y: 158)); arrow.line(to: NSPoint(x: -45, y: 85))
            arrow.move(to: NSPoint(x: -73, y: 110)); arrow.line(to: NSPoint(x: -45, y: 82)); arrow.line(to: NSPoint(x: -17, y: 110))
            arrow.lineWidth = 15; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
        }
        context.cgContext.restoreGState()
    }
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
