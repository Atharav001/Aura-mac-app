import AppKit

struct NotchDetector {
    static let defaultNotchWidth: CGFloat = 186
    static let defaultNotchHeight: CGFloat = 32
    static let expandedContentHeight: CGFloat = 200

    static func hasNotch(screen: NSScreen? = nil) -> Bool {
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        if sim { return true }
        return (screen ?? NSScreen.main)?.safeAreaInsets.top ?? 0 > 1
    }

    /// Physical camera cutout (or simulated) in screen coordinates.
    /// Top edge is flush with `screen.frame.maxY` (upper margin of the display).
    static func notchRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        let safeTop = screen.safeAreaInsets.top
        let top: CGFloat
        if sim || safeTop <= 1 {
            // Match menubar-ish height on non-notch / simulated
            let option = DataStore.shared.string(for: .nonNotchDisplayHeight) ?? "Match menubar height"
            top = option == "Match real notch size" ? defaultNotchHeight : max(defaultNotchHeight, 28)
        } else {
            let option = DataStore.shared.string(for: .notchHeightOption) ?? "Match real notch size"
            top = option == "Match menubar height" ? max(safeTop, 28) : safeTop
        }
        let frame = screen.frame
        // +1px flush trick (Boring Notch): avoids a hairline gap under the top bezel
        return CGRect(
            x: frame.midX - defaultNotchWidth / 2,
            y: frame.maxY - top + 1,
            width: defaultNotchWidth,
            height: top
        )
    }

    /// Expanded island: top edge flush with screen top, drops down below the camera.
    static func expandedRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        let width: CGFloat = min(
            DataStore.shared.double(for: .notchWidth, default: 620),
            screen.frame.width - 40
        )
        let height = notch.height + expandedContentHeight
        // Top of panel == screen top (frame.maxY), flush with upper margin
        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height + 1,
            width: width,
            height: height
        )
    }

    static func collapsedRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        // Slightly wider than camera for hover target, still flush to top
        return CGRect(
            x: notch.midX - notch.width / 2,
            y: notch.minY,
            width: notch.width,
            height: notch.height
        )
    }

    static func duoLeftRect(screen: NSScreen? = nil) -> CGRect {
        let expanded = expandedRect(screen: screen)
        let split = DataStore.shared.double(for: .duoModeSplit, default: 58)
        return CGRect(
            x: expanded.minX,
            y: expanded.minY,
            width: expanded.width * CGFloat(split / 100),
            height: expanded.height
        )
    }

    static func duoRightRect(screen: NSScreen? = nil) -> CGRect {
        let expanded = expandedRect(screen: screen)
        let split = DataStore.shared.double(for: .duoModeSplit, default: 58)
        let leftWidth = expanded.width * CGFloat(split / 100)
        return CGRect(
            x: expanded.minX + leftWidth,
            y: expanded.minY,
            width: expanded.width - leftWidth,
            height: expanded.height
        )
    }
}
