import AppKit

enum DockIconRenderer {
    /// The same app logo identifies every recent-file thumbnail. No text badge.
    static func image(with thumbnail: NSImage, dark: Bool = false) -> NSImage {
        let logo = AppLogo.image(dark: dark)
        let image = NSImage(size: NSSize(width: 512, height: 512), flipped: false) { _ in
            let available = NSRect(x: 30, y: 62, width: 420, height: 420)
            let source = thumbnail.size
            if source.width > 0, source.height > 0 {
                let scale = min(available.width / source.width, available.height / source.height)
                let size = NSSize(width: source.width * scale, height: source.height * scale)
                thumbnail.draw(in: NSRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2,
                                          width: size.width, height: size.height),
                               from: .zero, operation: .sourceOver, fraction: 1)
            }
            let badge = NSRect(x: 282, y: 12, width: 220, height: 220)
            let edge = badge.insetBy(dx: 11, dy: 11)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.set()
            NSColor.white.withAlphaComponent(0.95).setFill()
            NSBezierPath(roundedRect: edge, xRadius: 46, yRadius: 46).fill()
            NSGraphicsContext.restoreGraphicsState()
            logo.draw(in: badge, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        image.accessibilityDescription = "DownloadScroller recent file"
        return image
    }
}
