import AppKit
import MediaPlayer

extension Notification.Name {
    static let remoteNextTrack = Notification.Name("com.aura.remoteNextTrack")
    static let remotePreviousTrack = Notification.Name("com.aura.remotePreviousTrack")
    static let remoteTogglePlayPause = Notification.Name("com.aura.remoteTogglePlayPause")
    static let nowPlayingDidChange = Notification.Name("com.aura.nowPlayingDidChange")
}

final class MediaTracker: @unchecked Sendable {
    static let shared = MediaTracker()

    private var pollingTimer: Timer?

    struct NowPlayingInfo: Equatable {
        let title: String
        let artist: String
        let duration: Double
        let elapsedTime: Double
        let isPlaying: Bool
        let sourceApp: String

        static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
            lhs.title == rhs.title &&
            lhs.artist == rhs.artist &&
            lhs.duration == rhs.duration &&
            lhs.elapsedTime == rhs.elapsedTime &&
            lhs.isPlaying == rhs.isPlaying &&
            lhs.sourceApp == rhs.sourceApp
        }
    }

    var onUpdate: ((NowPlayingInfo?) -> Void)?
    private var lastInfo: NowPlayingInfo?
    private(set) var isSpotifyConnected = false
    private(set) var isAppleMusicConnected = false

    func startTracking() {
        isSpotifyConnected = DataStore.shared.bool(for: .spotifyEnabled, default: true)
        isAppleMusicConnected = DataStore.shared.bool(for: .appleMusicEnabled, default: true)
        setupRemoteCommands()

        // Listen for Spotify playback changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyPlaybackChanged),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        // Listen for Apple Music / iTunes playback changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appleMusicPlaybackChanged),
            name: NSNotification.Name("com.apple.iTunes.playerInfo"),
            object: nil
        )

        // Poll as fallback for browsers and other apps
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollBrowserMedia()
        }
    }

    func stopTracking() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Spotify Detection

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        guard isSpotifyConnected else { return }
        guard let userInfo = notification.userInfo else { return }

        let playerState = userInfo["Player State"] as? String ?? ""
        let trackName = userInfo["Name"] as? String ?? ""
        let artistName = userInfo["Artist"] as? String ?? ""
        let duration = (userInfo["Duration"] as? Double ?? 0) / 1000.0
        let position = (userInfo["Position"] as? Double ?? 0) / 1000.0
        let isPlaying = playerState == "Playing"

        guard !trackName.isEmpty else {
            if lastInfo != nil {
                lastInfo = nil
                onUpdate?(nil)
            }
            return
        }

        let info = NowPlayingInfo(
            title: trackName,
            artist: artistName,
            duration: duration,
            elapsedTime: position,
            isPlaying: isPlaying,
            sourceApp: "com.spotify.client"
        )

        if info != lastInfo {
            lastInfo = info
            onUpdate?(info)
        }
    }

    // MARK: - Apple Music Detection

    @objc private func appleMusicPlaybackChanged(_ notification: Notification) {
        guard isAppleMusicConnected else { return }
        guard let userInfo = notification.userInfo else { return }

        let playerState = userInfo["Player State"] as? String ?? ""
        let trackName = userInfo["Name"] as? String ?? ""
        let artistName = userInfo["Artist"] as? String ?? ""
        let duration = (userInfo["Total Time"] as? Double ?? 0) / 1000.0
        let elapsedTime = (userInfo["Elapsed Time"] as? Double) ?? 0
        let isPlaying = playerState == "Playing"

        guard !trackName.isEmpty else {
            if lastInfo != nil {
                lastInfo = nil
                onUpdate?(nil)
            }
            return
        }

        let info = NowPlayingInfo(
            title: trackName,
            artist: artistName,
            duration: duration,
            elapsedTime: elapsedTime,
            isPlaying: isPlaying,
            sourceApp: "com.apple.Music"
        )

        if info != lastInfo {
            lastInfo = info
            onUpdate?(info)
        }
    }

    // MARK: - Browser & Fallback Detection

    private func pollBrowserMedia() {
        let browserBundleIDs: Set<String> = [
            "com.apple.WebKit.WebContent",
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi"
        ]

        guard let sourceBundleID = lastInfo?.sourceApp,
              browserBundleIDs.contains(sourceBundleID) else { return }

        // Only clear if the source browser is no longer running
        let appRunning = NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == sourceBundleID
        })

        if !appRunning {
            lastInfo = nil
            onUpdate?(nil)
        }
    }

    // MARK: - Settings

    func setSpotifyConnected(_ connected: Bool) {
        isSpotifyConnected = connected
        DataStore.shared.set(key: .spotifyEnabled, value: connected)
    }

    func setAppleMusicConnected(_ connected: Bool) {
        isAppleMusicConnected = connected
        DataStore.shared.set(key: .appleMusicEnabled, value: connected)
    }

    // MARK: - Source App Info

    func sourceAppInfo() -> (bundleID: String, name: String, icon: NSImage?)? {
        guard let sourceBundleID = lastInfo?.sourceApp else { return nil }
        // Use the exact source app reported by the notification, not a random running app
        let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == sourceBundleID
        })
        if let app = runningApp, let bundleID = app.bundleIdentifier {
            return (bundleID, app.localizedName ?? bundleID, app.icon)
        }
        // Fallback: return bundle ID with name from a known mapping
        let name = sourceAppNameForBundle(sourceBundleID)
        return (sourceBundleID, name, nil)
    }

    private func sourceAppNameForBundle(_ bundleID: String) -> String {
        switch bundleID {
        case "com.spotify.client": return "Spotify"
        case "com.apple.Music", "com.apple.iTunes": return "Apple Music"
        case "com.apple.WebKit.WebContent": return "Safari"
        case "com.google.Chrome": return "Chrome"
        case "com.brave.Browser": return "Brave"
        case "com.microsoft.edgemac": return "Edge"
        case "com.operasoftware.Opera": return "Opera"
        case "com.vivaldi.Vivaldi": return "Vivaldi"
        default: return bundleID
        }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                LocalAudioManager.shared.togglePlayPause()
            }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                LocalAudioManager.shared.togglePlayPause()
            }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                LocalAudioManager.shared.togglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: .remoteNextTrack, object: nil)
            return .success
        }

        center.previousTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: .remotePreviousTrack, object: nil)
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = positionEvent.positionTime
            Task { @MainActor in
                LocalAudioManager.shared.seek(to: time)
            }
            return .success
        }
    }
}
