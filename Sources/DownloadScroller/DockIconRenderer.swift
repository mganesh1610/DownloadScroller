import AppKit

enum DockIconRenderer {
    /// Keep the recent file prominent, with a consistent DownloadScroller mark.
    /// Vector drawing keeps the badge crisp at the Dock's current magnification.
    static func image(with thumbnail: NSImage) -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512), flipped: false) { _ in
            let available = NSRect(x: 30, y: 62, width: 420, height: 420)
            let source = thumbnail.size
            if source.width > 0, source.height > 0 {
                let scale = min(available.width / source.width, available.height / source.height)
                let size = NSSize(width: source.width * scale, height: source.height * scale)
                let rect = NSRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2,
                                  width: size.width, height: size.height)
                thumbnail.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            }

            let badge = NSRect(x: 292, y: 24, width: 196, height: 196)
            let shape = NSBezierPath(roundedRect: badge, xRadius: 54, yRadius: 54)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.set()
            NSColor(srgbRed: 0.64, green: 0.94, blue: 0.81, alpha: 1).setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(starting: NSColor(srgbRed: 0.72, green: 0.97, blue: 0.86, alpha: 1),
                       ending: NSColor(srgbRed: 0.40, green: 0.80, blue: 0.71, alpha: 1))?.draw(in: shape, angle: -70)
            NSColor.white.withAlphaComponent(0.75).setStroke()
            shape.lineWidth = 4
            shape.stroke()

            let mark = "DS" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 88, weight: .bold),
                .foregroundColor: NSColor(srgbRed: 0.055, green: 0.19, blue: 0.21, alpha: 1)
            ]
            let size = mark.size(withAttributes: attributes)
            mark.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2), withAttributes: attributes)
            return true
        }
        image.accessibilityDescription = "DownloadScroller recent file"
        return image
    }
}
