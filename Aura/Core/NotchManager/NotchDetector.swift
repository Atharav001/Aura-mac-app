import AppKit

struct NotchDetector {
    static let defaultNotchWidth: CGFloat = 185
    static let defaultNotchHeight: CGFloat = 32
    /// Expanded drop-down content height (Boring Notch–like density)
    static let expandedContentHeight: CGFloat = 190

    static func hasNotch(screen: NSScreen? = nil) -> Bool {
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        if sim { return true }
        return (screen ?? NSScreen.main)?.safeAreaInsets.top ?? 0 > 1
    }

    /// Physical camera cutout — top flush with screen.maxY (+1px Boring Notch trick)
    static func notchRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let sim = DataStore.shared.bool(for: .simulatedNotch, default: false)
        let safeTop = screen.safeAreaInsets.top
        let top: CGFloat
        if sim || safeTop <= 1 {
            let option = DataStore.shared.string(for: .nonNotchDisplayHeight) ?? "Match menubar height"
            top = option == "Match real notch size" ? defaultNotchHeight : max(defaultNotchHeight - 1, 28)
        } else {
            let option = DataStore.shared.string(for: .notchHeightOption) ?? "Match real notch size"
            // BN reduces menubar-matching heights by 1px for flush alignment
            top = option == "Match menubar height" ? max(safeTop - 1, 28) : max(safeTop - 1, 1)
        }
        let frame = screen.frame
        return CGRect(
            x: frame.midX - defaultNotchWidth / 2,
            y: frame.maxY - top + 1,
            width: defaultNotchWidth,
            height: top
        )
    }

    static func expandedRect(screen: NSScreen? = nil) -> CGRect {
        guard let screen = (screen ?? NSScreen.main) else { return .zero }
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        let width: CGFloat = min(
            DataStore.shared.double(for: .notchWidth, default: 640),
            screen.frame.width - 48
        )
        let height = notch.height + expandedContentHeight
        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height + 1,
            width: width,
            height: height
        )
    }

    static func collapsedRect(screen: NSScreen? = nil, isPlaying: Bool = false) -> CGRect {
        let notch = notchRect(screen: screen)
        guard notch != .zero else { return .zero }
        // Boring Notch MusicLiveActivity:
        // chinWidth += 2 * max(0, closedNotchHeight - 12) + 20
        // Only widen while a song is actively playing.
        let musicBoost: CGFloat = isPlaying
            ? (2 * max(0, notch.height - 12) + 20)
            : 0
        let width = notch.width + musicBoost
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.minY,
            width: width,
            height: notch.height
        )
    }

    static func duoLeftRect(screen: NSScreen? = nil) -> CGRect {
        let expanded = expandedRect(screen: screen)
        let split = DataStore.shared.double(for: .duoModeSplit, default: 58)
        return CGRect(x: expanded.minX, y: expanded.minY, width: expanded.width * CGFloat(split / 100), height: expanded.height)
    }

    static func duoRightRect(screen: NSScreen? = nil) -> CGRect {
        let expanded = expandedRect(screen: screen)
        let split = DataStore.shared.double(for: .duoModeSplit, default: 58)
        let leftWidth = expanded.width * CGFloat(split / 100)
        return CGRect(x: expanded.minX + leftWidth, y: expanded.minY, width: expanded.width - leftWidth, height: expanded.height)
    }
}
