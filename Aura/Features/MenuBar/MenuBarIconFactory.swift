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
            // SPM resource bundle (Aura_Aura.bundle)
            #if SWIFT_PACKAGE
            list.append(.module)
            #endif
            if let resourceURL = Bundle.main.resourceURL {
                let spm = resourceURL.appendingPathComponent("Aura_Aura.bundle")
                if let b = Bundle(url: spm) { list.append(b) }
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

            let cx = rect.midX
            let cy = rect.midY + size * 0.01
            let h = size * 0.72
            let w = size * 0.62
            let stroke = size * 0.14
            let top = cy - h / 2
            let bottom = cy + h / 2
            let left = cx - w / 2
            let right = cx + w / 2
            let inset = stroke * 0.85

            let leftLeg = NSBezierPath()
            leftLeg.move(to: NSPoint(x: cx - 0.5, y: top))
            leftLeg.line(to: NSPoint(x: left, y: bottom))
            leftLeg.line(to: NSPoint(x: left + stroke, y: bottom))
            leftLeg.line(to: NSPoint(x: cx + inset * 0.2, y: top + stroke))
            leftLeg.close()
            leftLeg.fill()

            let rightLeg = NSBezierPath()
            rightLeg.move(to: NSPoint(x: cx + 0.5, y: top))
            rightLeg.line(to: NSPoint(x: right, y: bottom))
            rightLeg.line(to: NSPoint(x: right - stroke, y: bottom))
            rightLeg.line(to: NSPoint(x: cx - inset * 0.2, y: top + stroke))
            rightLeg.close()
            rightLeg.fill()

            let barH = stroke * 0.78
            let barW = w * 0.34
            let barY = cy + h * 0.05
            NSBezierPath(
                rect: NSRect(x: cx - barW / 2, y: barY - barH / 2, width: barW, height: barH)
            ).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawDockFallback(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            let radius = size * 0.2237
            NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

            NSColor.white.setFill()
            let cx = rect.midX
            let cy = rect.midY + size * 0.01
            let h = size * 0.38
            let w = size * 0.32
            let stroke = size * 0.07
            let top = cy - h / 2
            let bottom = cy + h / 2
            let left = cx - w / 2
            let right = cx + w / 2
            let inset = stroke * 0.85

            let leftLeg = NSBezierPath()
            leftLeg.move(to: NSPoint(x: cx - 0.5, y: top))
            leftLeg.line(to: NSPoint(x: left, y: bottom))
            leftLeg.line(to: NSPoint(x: left + stroke, y: bottom))
            leftLeg.line(to: NSPoint(x: cx + inset * 0.2, y: top + stroke))
            leftLeg.close()
            leftLeg.fill()

            let rightLeg = NSBezierPath()
            rightLeg.move(to: NSPoint(x: cx + 0.5, y: top))
            rightLeg.line(to: NSPoint(x: right, y: bottom))
            rightLeg.line(to: NSPoint(x: right - stroke, y: bottom))
            rightLeg.line(to: NSPoint(x: cx - inset * 0.2, y: top + stroke))
            rightLeg.close()
            rightLeg.fill()

            let barH = stroke * 0.78
            let barW = w * 0.34
            let barY = cy + h * 0.05
            NSBezierPath(
                rect: NSRect(x: cx - barW / 2, y: barY - barH / 2, width: barW, height: barH)
            ).fill()
            return true
        }
        return image
    }
}
