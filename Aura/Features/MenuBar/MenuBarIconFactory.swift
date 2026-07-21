import AppKit

enum MenuBarIconFactory {
    /// Template Dynamic Island pill for the status item.
    /// Prefers bundled logo asset when present; falls back to a crisp vector draw.
    static func makeIcon(size: CGFloat = 18) -> NSImage {
        if let bundled = loadBundledMenuBarIcon(size: size) {
            return bundled
        }
        return drawIslandTemplate(size: size)
    }

    /// Colorful dock / marketing mark when available.
    static func makeDockIcon(size: CGFloat = 128) -> NSImage? {
        loadImage(namedCandidates: [
            "aura-dock-icon",
            "aura-app-icon",
            "aura-dock-icon.png",
            "aura-app-icon.png"
        ], size: size, asTemplate: false)
    }

    private static func loadBundledMenuBarIcon(size: CGFloat) -> NSImage? {
        loadImage(namedCandidates: [
            "aura-menubar-icon",
            "aura-menubar-icon.png"
        ], size: size, asTemplate: true)
    }

    private static func loadImage(namedCandidates: [String], size: CGFloat, asTemplate: Bool) -> NSImage? {
        let urls: [URL] = namedCandidates.flatMap { name -> [URL] in
            var list: [URL] = []
            if let u = Bundle.main.url(forResource: (name as NSString).deletingPathExtension.isEmpty ? name : (name as NSString).deletingPathExtension,
                                       withExtension: (name as NSString).pathExtension.isEmpty ? "png" : (name as NSString).pathExtension) {
                list.append(u)
            }
            // SPM resource bundle / Logos folder copies
            if let resourceURL = Bundle.main.resourceURL {
                list.append(resourceURL.appendingPathComponent("Logos").appendingPathComponent(name.hasSuffix(".png") ? name : "\(name).png"))
                list.append(resourceURL.appendingPathComponent(name.hasSuffix(".png") ? name : "\(name).png"))
            }
            return list
        }

        for url in urls {
            if let img = NSImage(contentsOf: url) {
                let scaled = NSImage(size: NSSize(width: size, height: size))
                scaled.lockFocus()
                img.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                         from: .zero,
                         operation: .sourceOver,
                         fraction: 1)
                scaled.unlockFocus()
                scaled.isTemplate = asTemplate
                return scaled
            }
        }
        return nil
    }

    private static func drawIslandTemplate(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            let pillHeight = size * 0.38
            let pillWidth = size * 0.82
            let pillRect = NSRect(
                x: (rect.width - pillWidth) / 2,
                y: (rect.height - pillHeight) / 2,
                width: pillWidth,
                height: pillHeight
            )
            NSColor.black.setFill()
            NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()
            let camW = pillWidth * 0.26
            let camH = pillHeight * 0.52
            let cam = NSRect(
                x: pillRect.midX - camW / 2,
                y: pillRect.midY - camH / 2,
                width: camW,
                height: camH
            )
            NSBezierPath(ovalIn: cam).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
