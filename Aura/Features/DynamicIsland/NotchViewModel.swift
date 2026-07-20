import Observation
import AppKit
import IOKit.ps
import MediaPlayer

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let imageData: Data?
    let sourceApp: String
    let timestamp: Date
    var isPinned: Bool

    var hasImage: Bool { imageData != nil }

    init(id: UUID = UUID(), text: String, imageData: Data? = nil, sourceApp: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    init(from persisted: PersistedClipboardItem) {
        self.id = persisted.id
        self.text = persisted.text
        self.imageData = persisted.imageData
        self.sourceApp = persisted.sourceApp
        self.timestamp = persisted.timestamp
        self.isPinned = persisted.isPinned
    }

    func toPersisted() -> PersistedClipboardItem {
        PersistedClipboardItem(
            id: id,
            text: text,
            imageData: imageData,
            sourceApp: sourceApp,
            timestamp: timestamp,
            isPinned: isPinned
        )
    }
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
    }

    enum NotchTab: String, CaseIterable {
        case media = "Media"
        case calendar = "Calendar"
        case clipboard = "Clipboard"
        case shelf = "Shelf"
        case pomodoro = "Focus"
    }

    var state: NotchState = .collapsed
    var isHovering: Bool = false
    var notchRect: CGRect = .zero
    var expandedRect: CGRect = .zero
    var collapsedRect: CGRect = .zero

    var activeTab: NotchTab = .media
    var availableTabs: [NotchTab] = [.media, .calendar, .clipboard, .shelf, .pomodoro]

    var nowPlayingTitle: String = ""
    var nowPlayingArtist: String = ""
    var isPlaying: Bool = false
    var progress: Double = 0
    var duration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var mediaSource: MediaSource = .local
    var hasMedia: Bool = false
    var sourceAppName: String = ""
    var sourceAppIcon: NSImage?
    var albumArt: NSImage?
    var dominantColors: [NSColor] = []

    var audioQualityBadge: String? = nil
    var hasDolbyAtmos: Bool = false
    var hasLossless: Bool = false

    var lastTrackTitle: String = ""
    var lastTrackArtist: String = ""
    var lastTrackIcon: NSImage?
    var lastTrackSource: MediaSource = .local
    var lastTrackAppName: String = ""

    var shelfItems: [URL] = []

    var clipboardHistory: [ClipboardItem] = []

    var cameraActive: Bool = false

    var currentDate: String = ""
    var currentTime: String = ""
    var batteryLevel: Double = 0
    var batteryCharging: Bool = false

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

    var duoModeEnabled: Bool {
        DataStore.shared.bool(for: .duoModeEnabled, default: true)
    }
    var duoLeftContent: NotchTab = .media
    var duoRightContent: NotchTab = .calendar

    var isDraggingToNotch: Bool = false
    var dragProgress: Double = 0

    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    private var albumArtRetryCount = 0
    private var albumArtTimer: DispatchSourceTimer?
    private var lastPasteboardChangeCount: Int = -1

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

        // Restore clipboard (pinned forever + last 7 days)
        DataStore.shared.pruneClipboardHistory()
        clipboardHistory = DataStore.shared.clipboardItems.map { ClipboardItem(from: $0) }

        // Restore shelf paths that still exist
        shelfItems = DataStore.shared.shelfPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var currentFrame: CGRect {
        switch state {
        case .collapsed: return collapsedRect
        case .expanded, .media: return expandedRect
        }
    }

    var formattedElapsed: String {
        formatTime(elapsedTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    func updateFrames(screen: NSScreen? = nil) {
        notchRect = NotchDetector.notchRect(screen: screen)
        expandedRect = NotchDetector.expandedRect(screen: screen)
        collapsedRect = NotchDetector.collapsedRect(
            screen: screen,
            isPlaying: isPlaying
        )
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

    var isShuffled: Bool = false
    var isRepeating: Bool = false

    func showMedia(
        title: String,
        artist: String,
        isPlaying: Bool,
        progress: Double,
        duration: TimeInterval,
        source: MediaSource = .local,
        appName: String = "",
        appIcon: NSImage? = nil,
        artworkData: Data? = nil,
        isShuffled: Bool = false,
        isRepeating: Bool = false
    ) {
        nowPlayingTitle = title
        nowPlayingArtist = artist
        self.isPlaying = isPlaying
        self.progress = progress
        self.duration = duration
        self.elapsedTime = duration > 0 ? progress * duration : 0
        mediaSource = source
        sourceAppName = appName
        sourceAppIcon = appIcon
        hasMedia = true
        self.isShuffled = isShuffled
        self.isRepeating = isRepeating

        // Prefer Spotify/Music artwork bytes; never treat app icon as album art
        if let artworkData, let img = NSImage(data: artworkData) {
            albumArt = img
            clearAlbumArtRetry()
        } else if title != lastTrackTitle || artist != lastTrackArtist {
            albumArt = nil
            albumArt = fetchAlbumArtwork()
            if albumArt == nil {
                startAlbumArtRetry()
            }
        } else if let artworkData = artworkData, albumArt == nil, let img = NSImage(data: artworkData) {
            albumArt = img
        } else if albumArt == nil {
            albumArt = fetchAlbumArtwork()
            if albumArt == nil {
                startAlbumArtRetry()
            }
        } else if artworkData != nil, let img = NSImage(data: artworkData!) {
            // Refresh art for same track when download completes
            albumArt = img
        }
        extractDominantColors()
        detectAudioQuality()

        lastTrackTitle = title
        lastTrackArtist = artist
        lastTrackIcon = albumArt ?? appIcon
        lastTrackSource = source
        lastTrackAppName = appName

        let bundleID = source.bundleID
        let iconData = (albumArt ?? appIcon)?.tiffRepresentation
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
        }

        if hasLossless && hasDolbyAtmos {
            audioQualityBadge = "Dolby Atmos"
        }
    }

    private func extractDominantColors() {
        guard let art = albumArt,
              let cgImage = art.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            dominantColors = []
            return
        }
        let size = CGSize(width: 8, height: 8)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
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
            return NSColor(
                red: CGFloat(parts[0] * 16) / 255,
                green: CGFloat(parts[1] * 16) / 255,
                blue: CGFloat(parts[2] * 16) / 255,
                alpha: 1
            )
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

    /// Album artwork only — app logo is drawn separately as a corner badge when art exists,
    /// or as the sole image when art is missing.
    var displayArt: NSImage? { albumArt }

    var hasAlbumArtwork: Bool { albumArt != nil }

    func hideMedia() {
        hasMedia = false
        isPlaying = false
        // Keep last track / art for "last played" — don't wipe albumArt
        state = isHovering ? .expanded : .collapsed
    }

    func togglePlayPause() { onTogglePlayPause?() }
    func nextTrack() { onNextTrack?() }
    func previousTrack() { onPreviousTrack?() }

    // MARK: - Shelf

    func addShelfItem(_ url: URL) {
        guard DataStore.shared.bool(for: .shelfEnabled, default: true) else { return }
        guard !shelfItems.contains(url) else { return }
        shelfItems.append(url)
        persistShelf()
    }

    func removeShelfItem(_ url: URL) {
        shelfItems.removeAll { $0 == url }
        persistShelf()
    }

    func clearShelf() {
        shelfItems.removeAll()
        persistShelf()
    }

    func dragOutShelfItem(_ url: URL) {
        if DataStore.shared.bool(for: .shelfAutoRemove, default: false) {
            removeShelfItem(url)
        }
    }

    private func persistShelf() {
        DataStore.shared.saveShelf(shelfItems)
    }

    // MARK: - Clipboard

    func pollClipboard() {
        guard DataStore.shared.bool(for: .clipboardEnabled, default: true) else { return }
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        guard changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = changeCount

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "System"

        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation {
            // Avoid duplicating same image blob
            if clipboardHistory.first?.imageData != tiff {
                addClipboardItem(text: "Image", imageData: tiff, sourceApp: sourceApp)
            }
            return
        }

        if let text = pb.string(forType: .string), !text.isEmpty {
            if clipboardHistory.first?.text != text || clipboardHistory.first?.hasImage == true {
                addClipboardItem(text: text, imageData: nil, sourceApp: sourceApp)
            }
        }
    }

    func addClipboardItem(text: String, imageData: Data? = nil, sourceApp: String) {
        let item = ClipboardItem(text: text, imageData: imageData, sourceApp: sourceApp)
        clipboardHistory.insert(item, at: 0)
        enforceClipboardLimits()
        persistClipboard()
    }

    func toggleClipboardPinned(_ id: UUID) {
        guard let index = clipboardHistory.firstIndex(where: { $0.id == id }) else { return }
        clipboardHistory[index].isPinned.toggle()
        // Move pinned to top
        clipboardHistory.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.timestamp > rhs.timestamp
        }
        persistClipboard()
    }

    func deleteClipboardItem(_ id: UUID) {
        clipboardHistory.removeAll { $0.id == id }
        persistClipboard()
    }

    private func enforceClipboardLimits() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        let maxHistory = Int(DataStore.shared.double(for: .clipboardHistorySize, default: 48))
        // Keep all pinned + unpinned within 7 days / max size
        clipboardHistory = clipboardHistory.filter { $0.isPinned || $0.timestamp >= cutoff }
        let pinned = clipboardHistory.filter(\.isPinned)
        var unpinned = clipboardHistory.filter { !$0.isPinned }
        let unpinnedBudget = max(0, maxHistory - pinned.count)
        if unpinned.count > unpinnedBudget {
            unpinned = Array(unpinned.prefix(unpinnedBudget))
        }
        clipboardHistory = pinned + unpinned
        clipboardHistory.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.timestamp > rhs.timestamp
        }
    }

    private func persistClipboard() {
        DataStore.shared.saveClipboard(clipboardHistory.map { $0.toPersisted() })
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
