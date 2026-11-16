import AppKit

/// Original, shared vector artwork for the app icon, onboarding, and Dock badge.
enum AppLogo {
    static func image(dark: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { rect in
            draw(in: rect, dark: dark)
            return true
        }
        image.accessibilityDescription = "DownloadScroller"
        return image
    }

    static func draw(in rect: NSRect, dark: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
        let base = NSBezierPath(roundedRect: NSRect(x: 66, y: 66, width: 892, height: 892), xRadius: 200, yRadius: 200)
        let top = dark ? NSColor(srgbRed: 0.12, green: 0.27, blue: 0.46, alpha: 1)
                       : NSColor(srgbRed: 0.31, green: 0.69, blue: 1, alpha: 1)
        let bottom = dark ? NSColor(srgbRed: 0.035, green: 0.075, blue: 0.16, alpha: 1)
                          : NSColor(srgbRed: 0.10, green: 0.36, blue: 0.87, alpha: 1)
        NSGradient(starting: bottom, ending: top)?.draw(in: base, angle: 75)
        NSColor.white.withAlphaComponent(dark ? 0.18 : 0.45).setStroke()
        base.lineWidth = 3
        base.stroke()
        for index in (0..<3).reversed() {
            context.saveGState()
            context.translateBy(x: 730, y: 228)
            context.rotate(by: CGFloat(index) * 0.16)
            let page = NSBezierPath(roundedRect: NSRect(x: -432, y: 0, width: 432, height: 550), xRadius: 62, yRadius: 62)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(srgbRed: 0.015, green: 0.08, blue: 0.25, alpha: dark ? 0.36 : 0.18)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -8)
            shadow.set()
            NSColor.white.withAlphaComponent([0.96, 0.58, 0.34][index]).setFill()
            page.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(index == 0 ? 0.9 : 0.5).setStroke()
            page.lineWidth = 3
            page.stroke()
            if index == 0 {
                let arrow = NSBezierPath()
                arrow.move(to: NSPoint(x: -216, y: 410))
                arrow.line(to: NSPoint(x: -216, y: 210))
                arrow.move(to: NSPoint(x: -294, y: 286))
                arrow.line(to: NSPoint(x: -216, y: 206))
                arrow.line(to: NSPoint(x: -138, y: 286))
                arrow.lineWidth = 42
                arrow.lineCapStyle = .round
                arrow.lineJoinStyle = .round
                NSColor(srgbRed: 0.10, green: 0.39, blue: 0.85, alpha: 1).setStroke()
                arrow.stroke()
                let tray = NSBezierPath()
                tray.move(to: NSPoint(x: -310, y: 162))
                tray.line(to: NSPoint(x: -310, y: 125))
                tray.line(to: NSPoint(x: -122, y: 125))
                tray.line(to: NSPoint(x: -122, y: 162))
                tray.lineWidth = 28
                tray.lineCapStyle = .round
                tray.lineJoinStyle = .round
                tray.stroke()
            }
            context.restoreGState()
        }
    }
}
