import AppKit

enum MenuBarIconFactory {
    /// Template mark for the status item (black artwork, clear background).
    static func makeIcon(size: CGFloat = 18) -> NSImage {
        if let bundled = loadBundledMenuBarIcon(size: size) {
            return bundled
        }
        return drawATemplate(size: size)
    }

    /// Dock / marketing mark (full color).
    static func makeDockIcon(size: CGFloat = 512) -> NSImage? {
        if let img = loadImage(
            namedCandidates: [
                "aura-dock-icon",
                "aura-app-icon",
                "aura-dock-icon.png",
                "aura-app-icon.png",
            ],
            size: size,
            asTemplate: false
        ) {
            return img
        }
        // Last resort: rasterize from icns if present
        if let url = firstExistingURL(namedCandidates: ["AppIcon", "AppIcon.icns"]),
           let img = NSImage(contentsOf: url) {
            return resized(img, to: size, asTemplate: false)
        }
        return drawDockFallback(size: size)
    }

    /// Apply the branded dock icon so Settings / `.regular` activation is never generic.
    @MainActor
    static func applyApplicationIcon() {
        guard let icon = makeDockIcon(size: 512) else { return }
        NSApp.applicationIconImage = icon
    }

    // MARK: - Loading

    private static func loadBundledMenuBarIcon(size: CGFloat) -> NSImage? {
        guard let img = loadImage(
            namedCandidates: [
                "aura-menubar-icon",
                "aura-menubar-icon.png",
            ],
            size: size,
            asTemplate: true
        ) else { return nil }

        // Guard against opaque "white square" assets wrongly marked as templates
        if isMostlyOpaqueBackground(img) {
            return drawATemplate(size: size)
        }
        return img
    }

    private static func loadImage(
        namedCandidates: [String],
        size: CGFloat,
        asTemplate: Bool
    ) -> NSImage? {
        for url in candidateURLs(namedCandidates: namedCandidates) {
            if let img = NSImage(contentsOf: url) {
                return resized(img, to: size, asTemplate: asTemplate)
            }
        }
        return nil
    }

    private static func firstExistingURL(namedCandidates: [String]) -> URL? {
        candidateURLs(namedCandidates: namedCandidates).first
    }

    private static func candidateURLs(namedCandidates: [String]) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            let path = url.path
            guard !seen.contains(path), FileManager.default.fileExists(atPath: path) else { return }
            seen.insert(path)
            urls.append(url)
        }

        let bundles: [Bundle] = {
            var list: [Bundle] = [.main]
            // Prefer paths under the .app Resources — do not touch Bundle.module here.
            // Bundle.module fatals when the SPM resource bundle isn't beside a packaged .app.
            if let resourceURL = Bundle.main.resourceURL {
                let nested = [
                    resourceURL.appendingPathComponent("Aura_Aura.bundle"),
                    resourceURL.appendingPathComponent("Aura_Aura.bundle").appendingPathComponent("Contents"),
                ]
                for url in nested {
                    if let b = Bundle(url: url) { list.append(b) }
                }
            }
            return list
        }()

        for name in namedCandidates {
            let ns = name as NSString
            let base = ns.deletingPathExtension.isEmpty ? name : ns.deletingPathExtension
            let ext = ns.pathExtension.isEmpty ? "png" : ns.pathExtension
            let fileName = name.contains(".") ? name : "\(name).png"

            for bundle in bundles {
                if let u = bundle.url(forResource: base, withExtension: ext) {
                    append(u)
                }
                if let u = bundle.url(forResource: base, withExtension: ext, subdirectory: "Logos") {
                    append(u)
                }
                if let root = bundle.resourceURL {
                    append(root.appendingPathComponent("Logos").appendingPathComponent(fileName))
                    append(root.appendingPathComponent(fileName))
                    // Nested SPM copy: Resources/Logos/...
                    append(root.appendingPathComponent("Aura_Aura.bundle/Logos").appendingPathComponent(fileName))
                }
            }
        }
        return urls
    }

    private static func resized(_ image: NSImage, to size: CGFloat, asTemplate: Bool) -> NSImage {
        let target = NSSize(width: size, height: size)
        let scaled = NSImage(size: target, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(
                in: rect,
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        scaled.isTemplate = asTemplate
        return scaled
    }

    /// Detect broken menu-bar assets that are an opaque light square.
    private static func isMostlyOpaqueBackground(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return false }

        let w = min(cg.width, 32)
        let h = min(cg.height, 32)
        guard w > 0, h > 0 else { return false }

        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Sample four corners — a valid template is transparent there
        let corners = [0, w - 1, (h - 1) * w, (h - 1) * w + (w - 1)]
        var opaqueCorners = 0
        for idx in corners {
            let a = data[idx * 4 + 3]
            let r = data[idx * 4]
            let g = data[idx * 4 + 1]
            let b = data[idx * 4 + 2]
            if a > 200 && r > 200 && g > 200 && b > 200 {
                opaqueCorners += 1
            } else if a > 200 {
                opaqueCorners += 1
            }
        }
        return opaqueCorners >= 3
    }

    // MARK: - Drawn fallbacks

    private static func drawATemplate(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            NSColor.black.setFill()
            let pillH = size * 0.26
            let pillW = size * 0.72
            let pill = NSRect(
                x: (rect.width - pillW) / 2,
                y: (rect.height - pillH) / 2,
                width: pillW,
                height: pillH
            )
            NSBezierPath(roundedRect: pill, xRadius: pillH / 2, yRadius: pillH / 2).fill()
            // Clear aperture (destination-out)
            let ow = pillH * 0.52
            let oh = pillH * 0.40
            let hole = NSRect(x: pill.midX - ow / 2, y: pill.midY - oh / 2, width: ow, height: oh)
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.black.setFill()
            NSBezierPath(ovalIn: hole).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawDockFallback(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            let radius = size * 0.2237
            let bg = NSColor(calibratedWhite: 0.04, alpha: 1)
            bg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

            NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
            let pillH = size * 0.145
            let pillW = size * 0.42
            let pill = NSRect(
                x: (rect.width - pillW) / 2,
                y: (rect.height - pillH) / 2,
                width: pillW,
                height: pillH
            )
            NSBezierPath(roundedRect: pill, xRadius: pillH / 2, yRadius: pillH / 2).fill()

            bg.setFill()
            let ow = pillH * 0.52
            let oh = pillH * 0.40
            let hole = NSRect(x: pill.midX - ow / 2, y: pill.midY - oh / 2, width: ow, height: oh)
            NSBezierPath(ovalIn: hole).fill()
            return true
        }
        return image
    }
}
