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
    private var progressTimer: Timer?
    private var artworkTask: URLSessionDataTask?
    private var lastArtworkURL: String?

    struct NowPlayingInfo: Equatable {
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let elapsedTime: Double
        let isPlaying: Bool
        let sourceApp: String
        let artworkURL: String?
        let isShuffled: Bool
        let isRepeating: Bool
        /// Downloaded album art bytes (Spotify artwork url / Music artwork)
        var artworkData: Data?

        static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
            lhs.title == rhs.title &&
            lhs.artist == rhs.artist &&
            lhs.album == rhs.album &&
            lhs.duration == rhs.duration &&
            abs(lhs.elapsedTime - rhs.elapsedTime) < 0.5 &&
            lhs.isPlaying == rhs.isPlaying &&
            lhs.sourceApp == rhs.sourceApp &&
            lhs.artworkURL == rhs.artworkURL &&
            lhs.isShuffled == rhs.isShuffled &&
            lhs.isRepeating == rhs.isRepeating &&
            (lhs.artworkData == nil) == (rhs.artworkData == nil)
        }
    }

    var onUpdate: ((NowPlayingInfo?) -> Void)?
    private(set) var lastInfo: NowPlayingInfo?
    private(set) var isSpotifyConnected = false
    private(set) var isAppleMusicConnected = false

    func startTracking() {
        isSpotifyConnected = DataStore.shared.bool(for: .spotifyEnabled, default: true)
        isAppleMusicConnected = DataStore.shared.bool(for: .appleMusicEnabled, default: true)
        setupRemoteCommands()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyPlaybackChanged),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appleMusicPlaybackChanged),
            name: NSNotification.Name("com.apple.iTunes.playerInfo"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteToggle),
            name: .remoteTogglePlayPause,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteNext),
            name: .remoteNextTrack,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemotePrevious),
            name: .remotePreviousTrack,
            object: nil
        )

        // Immediate fetch on launch, then keep refreshing (Boring Notch style)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.pollActivePlayer(force: true)
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.pollActivePlayer(force: false)
            }
        }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickLocalProgress()
        }
    }

    func stopTracking() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        artworkTask?.cancel()
    }

    func refreshNow() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.pollActivePlayer(force: true)
        }
    }

    // MARK: - Spotify notification (lightweight; full state via AppleScript poll)

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        guard isSpotifyConnected else { return }
        pollActivePlayer(force: true)
    }

    @objc private func appleMusicPlaybackChanged(_ notification: Notification) {
        guard isAppleMusicConnected else { return }
        pollActivePlayer(force: true)
    }

    private func publish(_ info: NowPlayingInfo) {
        var mutable = info
        // Reuse cached art if same URL
        if info.artworkURL == lastArtworkURL, let existing = lastInfo?.artworkData {
            mutable.artworkData = existing
        }
        lastInfo = mutable
        onUpdate?(mutable)
        NotificationCenter.default.post(name: .nowPlayingDidChange, object: nil)

        if let urlString = info.artworkURL, !urlString.isEmpty, urlString != lastArtworkURL || mutable.artworkData == nil {
            fetchArtwork(urlString: urlString, for: mutable)
        }
    }

    private func clear() {
        if lastInfo != nil {
            lastInfo = nil
            lastArtworkURL = nil
            onUpdate?(nil)
        }
    }

    private func tickLocalProgress() {
        guard var info = lastInfo, info.isPlaying, info.duration > 0 else { return }
        info = NowPlayingInfo(
            title: info.title,
            artist: info.artist,
            album: info.album,
            duration: info.duration,
            elapsedTime: min(info.duration, info.elapsedTime + 1),
            isPlaying: true,
            sourceApp: info.sourceApp,
            artworkURL: info.artworkURL,
            isShuffled: info.isShuffled,
            isRepeating: info.isRepeating,
            artworkData: info.artworkData
        )
        lastInfo = info
        onUpdate?(info)
    }

    private func pollActivePlayer(force: Bool) {
        if isSpotifyConnected, let info = querySpotify() {
            if force || info != lastInfoWithoutArt() {
                publish(info)
            }
            return
        }
        if isAppleMusicConnected, let info = queryAppleMusic() {
            if force || info != lastInfoWithoutArt() {
                publish(info)
            }
            return
        }
        // Nothing playing
        if force || lastInfo != nil {
            DispatchQueue.main.async { [weak self] in self?.clear() }
        }
    }

    private func lastInfoWithoutArt() -> NowPlayingInfo? {
        guard let i = lastInfo else { return nil }
        return NowPlayingInfo(
            title: i.title, artist: i.artist, album: i.album,
            duration: i.duration, elapsedTime: i.elapsedTime, isPlaying: i.isPlaying,
            sourceApp: i.sourceApp, artworkURL: i.artworkURL,
            isShuffled: i.isShuffled, isRepeating: i.isRepeating, artworkData: nil
        )
    }

    // MARK: - Artwork download (Spotify artwork url)

    private func fetchArtwork(urlString: String, for info: NowPlayingInfo) {
        guard let url = URL(string: urlString) else { return }
        artworkTask?.cancel()
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, !data.isEmpty else { return }
            DispatchQueue.main.async {
                guard var current = self.lastInfo,
                      current.title == info.title,
                      current.artworkURL == urlString else { return }
                current.artworkData = data
                self.lastInfo = current
                self.lastArtworkURL = urlString
                self.onUpdate?(current)
            }
        }
        artworkTask = task
        task.resume()
    }

    // MARK: - Settings

    func setSpotifyConnected(_ connected: Bool) {
        isSpotifyConnected = connected
        DataStore.shared.set(key: .spotifyEnabled, value: connected)
        refreshNow()
    }

    func setAppleMusicConnected(_ connected: Bool) {
        isAppleMusicConnected = connected
        DataStore.shared.set(key: .appleMusicEnabled, value: connected)
        refreshNow()
    }

    func sourceAppInfo() -> (bundleID: String, name: String, icon: NSImage?)? {
        guard let sourceBundleID = lastInfo?.sourceApp else { return nil }
        let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == sourceBundleID
        })
        if let app = runningApp, let bundleID = app.bundleIdentifier {
            return (bundleID, app.localizedName ?? bundleID, app.icon)
        }
        let name = sourceBundleID == "com.spotify.client" ? "Spotify" : "Apple Music"
        return (sourceBundleID, name, nil)
    }

    // MARK: - Remote Commands

    @objc private func handleRemoteToggle() { togglePlayPause() }
    @objc private func handleRemoteNext() { nextTrack() }
    @objc private func handleRemotePrevious() { previousTrack() }

    func togglePlayPause() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to playpause")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to playpause")
        } else {
            Task { @MainActor in LocalAudioManager.shared.togglePlayPause() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.pollActivePlayer(force: true)
        }
    }

    func nextTrack() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to next track")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to next track")
        } else {
            NotificationCenter.default.post(name: Notification.Name("com.aura.localNextTrack"), object: nil)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollActivePlayer(force: true)
        }
    }

    func previousTrack() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to previous track")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to previous track")
        } else {
            NotificationCenter.default.post(name: Notification.Name("com.aura.localPreviousTrack"), object: nil)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollActivePlayer(force: true)
        }
    }

    func toggleShuffle() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set shuffling to not shuffling")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to set shuffle enabled to not shuffle enabled")
        }
        refreshNow()
    }

    func toggleRepeat() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set repeating to not repeating")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("""
            tell application "Music"
                if song repeat is off then
                    set song repeat to all
                else
                    set song repeat to off
                end if
            end tell
            """)
        }
        refreshNow()
    }

    func skipForward() {
        let seconds = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set player position to ((player position) + \(seconds))")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to set player position to ((player position) + \(seconds))")
        }
        refreshNow()
    }

    func skipBackward() {
        let seconds = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\"\nset player position to ((player position) - \(seconds))\nif player position < 0 then set player position to 0\nend tell")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\"\nset player position to ((player position) - \(seconds))\nif player position < 0 then set player position to 0\nend tell")
        }
        refreshNow()
    }

    private func skipIncrementSeconds() -> Int {
        let raw = DataStore.shared.string(for: .skipIncrement) ?? "15s"
        return Int(raw.replacingOccurrences(of: "s", with: "")) ?? 15
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previousTrack(); return .success }
    }

    // MARK: - AppleScript queries (Boring Notch approach)

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    private func runAppleScriptReturning(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    /// Spotify: same fields Boring Notch uses, including `artwork url of current track`
    private func querySpotify() -> NowPlayingInfo? {
        let source = """
        tell application "System Events"
            if not (exists process "Spotify") then return ""
        end tell
        tell application "Spotify"
            try
                if player state is stopped then return ""
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set d to (duration of current track) / 1000
                set p to player position
                set s to player state as string
                set sh to shuffling
                set rp to repeating
                set art to artwork url of current track
                return t & "|||" & a & "|||" & al & "|||" & d & "|||" & p & "|||" & s & "|||" & sh & "|||" & rp & "|||" & art
            on error
                return ""
            end try
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts.count > 2 ? parts[2] : "",
            duration: Double(parts[3]) ?? 0,
            elapsedTime: Double(parts[4]) ?? 0,
            isPlaying: parts[5].lowercased().contains("playing"),
            sourceApp: "com.spotify.client",
            artworkURL: parts.count > 8 ? parts[8] : nil,
            isShuffled: parts.count > 6 ? parts[6].lowercased().contains("true") : false,
            isRepeating: parts.count > 7 ? parts[7].lowercased().contains("true") : false,
            artworkData: nil
        )
    }

    private func queryAppleMusic() -> NowPlayingInfo? {
        let source = """
        tell application "System Events"
            if not (exists process "Music") then return ""
        end tell
        tell application "Music"
            try
                if player state is stopped then return ""
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set d to duration of current track
                set p to player position
                set s to player state as string
                return t & "|||" & a & "|||" & al & "|||" & d & "|||" & p & "|||" & s
            on error
                return ""
            end try
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts.count > 2 ? parts[2] : "",
            duration: Double(parts[3]) ?? 0,
            elapsedTime: Double(parts[4]) ?? 0,
            isPlaying: parts[5].lowercased().contains("playing"),
            sourceApp: "com.apple.Music",
            artworkURL: nil,
            isShuffled: false,
            isRepeating: false,
            artworkData: nil
        )
    }
}
