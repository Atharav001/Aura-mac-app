import AppKit

struct NotchDetector {
    static let defaultNotchWidth: CGFloat = 186
    static let defaultNotchHeight: CGFloat = 32
    static let expandedContentHeight: CGFloat = 230

    static func hasNotch(screen: NSScreen? = nil) -> Bool {
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        if sim { return true }
        return (screen ?? NSScreen.main)?.safeAreaInsets.top ?? 0 > 1
    }

    static func notchRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        let top: CGFloat
        let safeTop = screen.safeAreaInsets.top
        if sim || safeTop <= 1 {
            top = defaultNotchHeight
        } else {
            top = safeTop
        }
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
        let width: CGFloat = min(
            DataStore.shared.double(for: .notchWidth, default: 520),
            (screen ?? NSScreen.main)?.frame.width ?? 520
        )
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.minY - expandedContentHeight,
            width: width,
            height: notch.height + expandedContentHeight
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

    // Duo mode: left bubble (media/timer) and right bubble (calendar/compact)
    static func duoLeftRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        let split = DataStore.shared.double(for: .duoModeSplit, default: 60)
        let totalWidth: CGFloat = min(
            DataStore.shared.double(for: .notchWidth, default: 520),
            (screen ?? NSScreen.main)?.frame.width ?? 520
        )
        let leftWidth = totalWidth * CGFloat(split / 100)
        return CGRect(
            x: notch.midX - totalWidth / 2,
            y: notch.minY - expandedContentHeight,
            width: leftWidth,
            height: notch.height + expandedContentHeight
        )
    }

    static func duoRightRect(screen: NSScreen? = nil) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        let split = DataStore.shared.double(for: .duoModeSplit, default: 60)
        let totalWidth: CGFloat = min(
            DataStore.shared.double(for: .notchWidth, default: 520),
            (screen ?? NSScreen.main)?.frame.width ?? 520
        )
        let leftWidth = totalWidth * CGFloat(split / 100)
        let rightWidth = totalWidth - leftWidth
        return CGRect(
            x: notch.midX - totalWidth / 2 + leftWidth,
            y: notch.minY - expandedContentHeight,
            width: rightWidth,
            height: notch.height + expandedContentHeight
        )
    }
}
