import Observation
import AppKit
import IOKit.ps
import MediaPlayer

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

    var state: NotchState = .collapsed
    var isHovering: Bool = false
    var notchRect: CGRect = .zero
    var expandedRect: CGRect = .zero
    var collapsedRect: CGRect = .zero

    var nowPlayingTitle: String = ""
    var nowPlayingArtist: String = ""
    var isPlaying: Bool = false
    var progress: Double = 0
    var duration: TimeInterval = 0
    var mediaSource: MediaSource = .local
    var hasMedia: Bool = false
    var sourceAppName: String = ""
    var sourceAppIcon: NSImage?

    // Actual album artwork fetched via MPNowPlayingInfoCenter
    var albumArt: NSImage?

    // Last track cache — persists when playback stops
    var lastTrackTitle: String = ""
    var lastTrackArtist: String = ""
    var lastTrackIcon: NSImage?
    var lastTrackSource: MediaSource = .local
    var lastTrackAppName: String = ""

    var currentDate: String = ""
    var currentTime: String = ""
    var batteryLevel: Double = 0
    var batteryCharging: Bool = false

    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

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
        if hasMedia {
            state = .media
        } else {
            state = .expanded
        }
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

        // Fetch actual album artwork from MPNowPlayingInfoCenter
        albumArt = fetchAlbumArtwork()

        // Cache last track info (only app icon, NOT album art — 
        // album art from closed apps is no longer accessible)
        lastTrackTitle = title
        lastTrackArtist = artist
        lastTrackIcon = appIcon
        lastTrackSource = source
        lastTrackAppName = appName

        if isHovering {
            state = .media
        }
    }

    private func fetchAlbumArtwork() -> NSImage? {
        if let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let artwork = nowPlaying[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            return artwork.image(at: CGSize(width: 120, height: 120))
        }
        return nil
    }

    /// Best image for the current track: actual album art if accessible, app icon otherwise
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
}
