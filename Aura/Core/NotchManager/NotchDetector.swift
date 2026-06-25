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
        let width: CGFloat = DataStore.shared.bool(for: .extendNotchWidth, default: true) ? 520 : 400
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.minY - 180,
            width: width,
            height: notch.height + 180
        )
    }

    static func collapsedRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        return CGRect(
            x: notch.midX - 40,
            y: notch.midY - notch.height / 2,
            width: 80,
            height: notch.height
        )
    }
}
