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
            abs(lhs.elapsedTime - rhs.elapsedTime) < 0.4 &&
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

        // Poll progress + recover state if notifications were missed
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollActivePlayer()
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
    }

    // MARK: - Spotify

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
            clearIfSource("com.spotify.client")
            return
        }

        publish(NowPlayingInfo(
            title: trackName,
            artist: artistName,
            duration: duration,
            elapsedTime: position,
            isPlaying: isPlaying,
            sourceApp: "com.spotify.client"
        ))
    }

    // MARK: - Apple Music

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
            clearIfSource("com.apple.Music")
            return
        }

        publish(NowPlayingInfo(
            title: trackName,
            artist: artistName,
            duration: duration,
            elapsedTime: elapsedTime,
            isPlaying: isPlaying,
            sourceApp: "com.apple.Music"
        ))
    }

    private func clearIfSource(_ bundleID: String) {
        if lastInfo?.sourceApp == bundleID {
            lastInfo = nil
            onUpdate?(nil)
        }
    }

    private func publish(_ info: NowPlayingInfo) {
        if info != lastInfo {
            lastInfo = info
            onUpdate?(info)
            NotificationCenter.default.post(name: .nowPlayingDidChange, object: nil)
        }
    }

    private func tickLocalProgress() {
        guard let info = lastInfo, info.isPlaying, info.duration > 0 else { return }
        let next = NowPlayingInfo(
            title: info.title,
            artist: info.artist,
            duration: info.duration,
            elapsedTime: min(info.duration, info.elapsedTime + 1),
            isPlaying: true,
            sourceApp: info.sourceApp
        )
        lastInfo = next
        onUpdate?(next)
    }

    private func pollActivePlayer() {
        // Soft refresh via AppleScript when we have an active source
        guard let source = lastInfo?.sourceApp else {
            // Try to discover currently playing Spotify/Music
            if isSpotifyConnected, let info = querySpotify() {
                publish(info)
            } else if isAppleMusicConnected, let info = queryAppleMusic() {
                publish(info)
            }
            return
        }
        if source == "com.spotify.client", isSpotifyConnected, let info = querySpotify() {
            publish(info)
        } else if source == "com.apple.Music", isAppleMusicConnected, let info = queryAppleMusic() {
            publish(info)
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
        let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == sourceBundleID
        })
        if let app = runningApp, let bundleID = app.bundleIdentifier {
            return (bundleID, app.localizedName ?? bundleID, app.icon)
        }
        return (sourceBundleID, sourceAppNameForBundle(sourceBundleID), nil)
    }

    private func sourceAppNameForBundle(_ bundleID: String) -> String {
        switch bundleID {
        case "com.spotify.client": return "Spotify"
        case "com.apple.Music", "com.apple.iTunes": return "Apple Music"
        default: return bundleID
        }
    }

    // MARK: - Remote Commands

    @objc private func handleRemoteToggle() { togglePlayPause() }
    @objc private func handleRemoteNext() { nextTrack() }
    @objc private func handleRemotePrevious() { previousTrack() }

    func togglePlayPause() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("""
            tell application "Spotify"
                if player state is playing then
                    pause
                else
                    play
                end if
            end tell
            """)
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("""
            tell application "Music"
                if player state is playing then
                    pause
                else
                    play
                end if
            end tell
            """)
        } else {
            Task { @MainActor in LocalAudioManager.shared.togglePlayPause() }
        }
    }

    func nextTrack() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to next track")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to next track")
        } else {
            // Local playlist advances are handled by AudioPlayerView observers
            NotificationCenter.default.post(name: Notification.Name("com.aura.localNextTrack"), object: nil)
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
    }

    func skipForward() {
        let seconds = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set player position to ((player position) + \(seconds))")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to set player position to ((player position) + \(seconds))")
        }
    }

    func skipBackward() {
        let seconds = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\"\nset player position to ((player position) - \(seconds))\nif player position < 0 then set player position to 0\nend tell")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\"\nset player position to ((player position) - \(seconds))\nif player position < 0 then set player position to 0\nend tell")
        }
    }

    private func skipIncrementSeconds() -> Int {
        let raw = DataStore.shared.string(for: .skipIncrement) ?? "15s"
        return Int(raw.replacingOccurrences(of: "s", with: "")) ?? 15
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }

    // MARK: - AppleScript helpers

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&error)
        }
    }

    private func querySpotify() -> NowPlayingInfo? {
        let source = """
        tell application "System Events"
            if not (exists process "Spotify") then return ""
        end tell
        tell application "Spotify"
            if player state is stopped then return ""
            set t to name of current track
            set a to artist of current track
            set d to (duration of current track) / 1000
            set p to player position
            set s to player state as string
            return t & "|||" & a & "|||" & d & "|||" & p & "|||" & s
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            duration: Double(parts[2]) ?? 0,
            elapsedTime: Double(parts[3]) ?? 0,
            isPlaying: parts[4].lowercased().contains("playing"),
            sourceApp: "com.spotify.client"
        )
    }

    private func queryAppleMusic() -> NowPlayingInfo? {
        let source = """
        tell application "System Events"
            if not (exists process "Music") then return ""
        end tell
        tell application "Music"
            if player state is stopped then return ""
            set t to name of current track
            set a to artist of current track
            set d to duration of current track
            set p to player position
            set s to player state as string
            return t & "|||" & a & "|||" & d & "|||" & p & "|||" & s
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            duration: Double(parts[2]) ?? 0,
            elapsedTime: Double(parts[3]) ?? 0,
            isPlaying: parts[4].lowercased().contains("playing"),
            sourceApp: "com.apple.Music"
        )
    }

    private func runAppleScriptReturning(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
