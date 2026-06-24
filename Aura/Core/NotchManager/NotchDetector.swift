import AppKit

struct NotchDetector {
    static let defaultNotchWidth: CGFloat = 186
    static let defaultNotchHeight: CGFloat = 32

    static func hasNotch(screen: NSScreen? = nil) -> Bool {
        (screen ?? NSScreen.main)?.safeAreaInsets.top ?? 0 > 1
    }

    static func notchRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let top = screen.safeAreaInsets.top
        guard top > 1 else { return .zero }
        let frame = screen.frame
        return CGRect(
            x: frame.midX - defaultNotchWidth / 2,
            y: frame.maxY - top,
            width: defaultNotchWidth,
            height: top
        )
    }

    static func expandedRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        return CGRect(
            x: notch.midX - 150,
            y: notch.minY - 80,
            width: 300,
            height: notch.height + 80
        )
    }

    static func collapsedRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        return CGRect(
            x: notch.midX - 32,
            y: notch.midY - notch.height / 2,
            width: 64,
            height: notch.height
        )
    }
}
