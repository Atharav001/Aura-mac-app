import AppKit

enum MenuBarIconFactory {
    /// Template Dynamic Island pill for the status item (renders with system menu-bar tint).
    static func makeIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high

            let pillHeight = size * 0.40
            let pillWidth = size * 0.78
            let pillRect = NSRect(
                x: (rect.width - pillWidth) / 2,
                y: (rect.height - pillHeight) / 2,
                width: pillWidth,
                height: pillHeight
            )

            NSColor.black.setFill()
            NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

            // Small centered "camera" oval so it reads as a notch at 16–18pt
            let camW = pillWidth * 0.28
            let camH = pillHeight * 0.55
            let cam = NSRect(
                x: pillRect.midX - camW / 2,
                y: pillRect.midY - camH / 2,
                width: camW,
                height: camH
            )
            NSColor.black.setFill()
            NSBezierPath(ovalIn: cam).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
