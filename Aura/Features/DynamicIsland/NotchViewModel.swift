import Observation
import AppKit
import IOKit.ps
import MediaPlayer

struct ClipboardItem: Identifiable {
    let id = UUID()
    let text: String
    let sourceApp: String
    let timestamp: Date
}

@Observable
final class NotchViewModel {
    enum NotchState: String {
        case collapsed
        case expanded
        case media
    }

    enum MediaSource: Equatable {
        case local
        case system(bundleID: String)

        var bundleID: String? {
            switch self {
            case .local: return nil
            case .system(let id): return id
            }
        }

        var iconName: String {
            switch self {
            case .local: return "music.note.list"
            case .system(let id):
                switch id {
                case "com.spotify.client": return "spotify"
                case "com.apple.Music": return "apple.music"
                default: return "antenna.radiowaves.left.and.right"
                }
            }
        }
    }

    enum NotchTab: String, CaseIterable {
        case media = "Media"
        case calendar = "Calendar"
        case clipboard = "Clipboard"
        case shelf = "Shelf"
        case pomodoro = "Focus"
    }

    // State
    var state: NotchState = .collapsed
    var isHovering: Bool = false
    var notchRect: CGRect = .zero
    var expandedRect: CGRect = .zero
    var collapsedRect: CGRect = .zero

    // Tab system
    var activeTab: NotchTab = .media
    var availableTabs: [NotchTab] = [.media, .calendar, .clipboard, .shelf, .pomodoro]

    // Now Playing
    var nowPlayingTitle: String = ""
    var nowPlayingArtist: String = ""
    var isPlaying: Bool = false
    var progress: Double = 0
    var duration: TimeInterval = 0
    var mediaSource: MediaSource = .local
    var hasMedia: Bool = false
    var sourceAppName: String = ""
    var sourceAppIcon: NSImage?
    var albumArt: NSImage?
    var dominantColors: [NSColor] = []

    // Quality badges (Alcove-style: Lossless, Dolby Atmos, E)
    var audioQualityBadge: String? = nil
    var hasDolbyAtmos: Bool = false
    var hasLossless: Bool = false

    // Last track cache
    var lastTrackTitle: String = ""
    var lastTrackArtist: String = ""
    var lastTrackIcon: NSImage?
    var lastTrackSource: MediaSource = .local
    var lastTrackAppName: String = ""

    // Shelf
    var shelfItems: [URL] = []

    // Clipboard
    var clipboardHistory: [ClipboardItem] = []
    var clipboardPinned: Set<UUID> = []

    // Camera Mirror
    var cameraActive: Bool = false

    // System
    var currentDate: String = ""
    var currentTime: String = ""
    var batteryLevel: Double = 0
    var batteryCharging: Bool = false

    // System HUD replacement (Alcove-style)
    var systemHUDVolume: Float = 0.5
    var systemHUDBrightness: Float = 0.7
    var systemHUDType: SystemHUDType? = nil
    var systemHUDProgress: Double {
        switch systemHUDType {
        case .volume: return Double(systemHUDVolume)
        case .brightness: return Double(systemHUDBrightness)
        case nil: return 0
        }
    }
    enum SystemHUDType: String {
        case volume
        case brightness
    }

    // Duo Mode
    var duoModeEnabled: Bool {
        DataStore.shared.bool(for: .duoModeEnabled, default: false)
    }
    var duoLeftContent: NotchTab = .media
    var duoRightContent: NotchTab = .calendar

    // Weather (Boring Notch-inspired)
    var weatherEnabled: Bool = false
    var weatherTemperature: String = "--"
    var weatherCondition: String = ""
    var weatherIcon: String = "cloud"

    // Drag-to-expand state
    var isDraggingToNotch: Bool = false
    var dragProgress: Double = 0

    // Callbacks
    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    init() {
        if let saved = DataStore.shared.lastTrack {
            lastTrackTitle = saved.title
            lastTrackArtist = saved.artist
            lastTrackAppName = saved.sourceAppName
            if let bundleID = saved.sourceBundleID {
                lastTrackSource = .system(bundleID: bundleID)
            } else {
                lastTrackSource = .local
            }
            if let data = saved.appIconData {
                lastTrackIcon = NSImage(data: data)
            }
        }
        if DataStore.shared.bool(for: .rememberLastTab, default: false),
           let savedTab = DataStore.shared.string(for: .lastActiveTab),
           let tab = NotchTab(rawValue: savedTab) {
            activeTab = tab
        }
    }

    var currentFrame: CGRect {
        switch state {
        case .collapsed: return collapsedRect
        case .expanded, .media: return expandedRect
        }
    }

    func updateFrames(screen: NSScreen? = nil) {
        notchRect = NotchDetector.notchRect(screen: screen)
        expandedRect = NotchDetector.expandedRect(screen: screen)
        collapsedRect = NotchDetector.collapsedRect(screen: screen)
    }

    func handleHoverEnter() {
        isHovering = true
        state = .expanded
    }

    func handleHoverExit() {
        isHovering = false
        state = .collapsed
    }

    func updateSystemInfo() {
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        currentDate = df.string(from: now)
        df.dateFormat = "h:mm"
        currentTime = df.string(from: now)

        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as? [Any] ?? []
        if let ps = sources.first as? NSDictionary {
            batteryLevel = (ps[kIOPSCurrentCapacityKey as String] as? Double ?? 50) / 100.0
            batteryCharging = (ps[kIOPSPowerSourceStateKey as String] as? String == "AC Power")
        } else {
            batteryLevel = 0
            batteryCharging = false
        }
    }

    private var albumArtRetryCount = 0
    private var albumArtTimer: DispatchSourceTimer?

    func showMedia(title: String, artist: String, isPlaying: Bool, progress: Double, duration: TimeInterval, source: MediaSource = .local, appName: String = "", appIcon: NSImage? = nil) {
        nowPlayingTitle = title
        nowPlayingArtist = artist
        self.isPlaying = isPlaying
        self.progress = progress
        self.duration = duration
        mediaSource = source
        sourceAppName = appName
        sourceAppIcon = appIcon
        hasMedia = true

        albumArt = fetchAlbumArtwork()
        if albumArt == nil {
            startAlbumArtRetry()
        }
        extractDominantColors()
        detectAudioQuality()

        lastTrackTitle = title
        lastTrackArtist = artist
        lastTrackIcon = appIcon
        lastTrackSource = source
        lastTrackAppName = appName

        let bundleID = source.bundleID
        let iconData = appIcon?.tiffRepresentation
        DataStore.shared.setLastTrack(title: title, artist: artist, sourceBundleID: bundleID, sourceAppName: appName, appIconData: iconData)

        if isHovering {
            state = .expanded
        }
    }

    private func detectAudioQuality() {
        hasLossless = false
        hasDolbyAtmos = false
        audioQualityBadge = nil

        if let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            if let q = nowPlaying["MPNowPlayingInfoPropertyAudioFormat"] as? Int {
                if q == 1 { hasLossless = true; audioQualityBadge = "Lossless" }
                else if q == 2 { hasDolbyAtmos = true; audioQualityBadge = "Dolby Atmos" }
            }
            if let _ = nowPlaying["MPNowPlayingInfoPropertyIsLiveBroadcast"] as? Bool {
                audioQualityBadge = "Live"
            }
        }

        if hasLossless && hasDolbyAtmos {
            audioQualityBadge = "Dolby Atmos"
        }
    }

    private func extractDominantColors() {
        guard let art = albumArt ?? sourceAppIcon,
              let cgImage = art.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            dominantColors = []
            return
        }
        let size = CGSize(width: 8, height: 8)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        guard let pixelData = context.data else { return }
        let data = pixelData.assumingMemoryBound(to: UInt8.self)

        var colorCount: [String: Int] = [:]
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let offset = (y * Int(size.width) + x) * 4
                let r = data[offset], g = data[offset + 1], b = data[offset + 2]
                let key = "\(r>>4),\(g>>4),\(b>>4)"
                colorCount[key, default: 0] += 1
            }
        }
        let sorted = colorCount.sorted { $0.value > $1.value }.prefix(4)
        dominantColors = sorted.compactMap { (key, _) -> NSColor? in
            let parts = key.split(separator: ",").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return NSColor(red: CGFloat(parts[0] * 16) / 255, green: CGFloat(parts[1] * 16) / 255, blue: CGFloat(parts[2] * 16) / 255, alpha: 1)
        }
    }

    private func startAlbumArtRetry() {
        albumArtRetryCount = 0
        albumArtTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 0.3, repeating: 0.3, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if let art = self.fetchAlbumArtwork() {
                self.albumArt = art
                self.extractDominantColors()
                self.albumArtTimer?.cancel()
                self.albumArtTimer = nil
            } else {
                self.albumArtRetryCount += 1
                if self.albumArtRetryCount >= 8 {
                    self.albumArtTimer?.cancel()
                    self.albumArtTimer = nil
                }
            }
        }
        albumArtTimer = timer
        timer.resume()
    }

    private func fetchAlbumArtwork() -> NSImage? {
        if let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let artwork = nowPlaying[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            return artwork.image(at: CGSize(width: 120, height: 120))
        }
        return nil
    }

    func clearAlbumArtRetry() {
        albumArtTimer?.cancel()
        albumArtTimer = nil
    }

    var displayArt: NSImage? {
        albumArt ?? sourceAppIcon
    }

    func hideMedia() {
        hasMedia = false
        state = isHovering ? .expanded : .collapsed
    }

    func togglePlayPause() {
        onTogglePlayPause?()
    }

    func nextTrack() {
        onNextTrack?()
    }

    func previousTrack() {
        onPreviousTrack?()
    }

    // MARK: - Shelf

    func addShelfItem(_ url: URL) {
        shelfItems.append(url)
    }

    func removeShelfItem(_ url: URL) {
        shelfItems.removeAll { $0 == url }
    }

    func clearShelf() {
        shelfItems.removeAll()
    }

    // MARK: - Clipboard

    func addClipboardItem(_ text: String, sourceApp: String) {
        clipboardHistory.insert(ClipboardItem(text: text, sourceApp: sourceApp, timestamp: Date()), at: 0)
        let maxHistory = Int(DataStore.shared.double(for: .clipboardHistorySize, default: 48))
        if clipboardHistory.count > maxHistory {
            clipboardHistory = Array(clipboardHistory.prefix(maxHistory))
        }
    }

    func toggleClipboardPinned(_ id: UUID) {
        if clipboardPinned.contains(id) {
            clipboardPinned.remove(id)
        } else {
            clipboardPinned.insert(id)
        }
    }

    // MARK: - Swipe Gesture Handling

    func handleSwipeLeft() {
        guard DataStore.shared.bool(for: .mediaHorizontalGestures, default: true) else { return }
        nextTrack()
    }

    func handleSwipeRight() {
        guard DataStore.shared.bool(for: .mediaHorizontalGestures, default: true) else { return }
        previousTrack()
    }
}
