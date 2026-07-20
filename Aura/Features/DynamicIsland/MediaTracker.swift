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
    private let scriptQueue = DispatchQueue(label: "com.aura.media.script", qos: .userInitiated)
    private var artworkTask: URLSessionDataTask?
    private var lastArtworkURL: String?
    private var consecutiveMisses = 0

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
        var artworkData: Data?

        static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
            lhs.title == rhs.title &&
            lhs.artist == rhs.artist &&
            lhs.album == rhs.album &&
            abs(lhs.duration - rhs.duration) < 0.5 &&
            abs(lhs.elapsedTime - rhs.elapsedTime) < 0.75 &&
            lhs.isPlaying == rhs.isPlaying &&
            lhs.sourceApp == rhs.sourceApp &&
            lhs.artworkURL == rhs.artworkURL
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

        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteToggle), name: .remoteTogglePlayPause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteNext), name: .remoteNextTrack, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemotePrevious), name: .remotePreviousTrack, object: nil)

        // Immediate + steady refresh
        refreshNow()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
        if let pollingTimer {
            RunLoop.main.add(pollingTimer, forMode: .common)
        }
    }

    func stopTracking() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        artworkTask?.cancel()
    }

    func refreshNow() {
        scriptQueue.async { [weak self] in
            self?.pollActivePlayer()
        }
    }

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        guard isSpotifyConnected else { return }
        // Fast path from Spotify DNC, then full AppleScript refresh for art/position
        if let userInfo = notification.userInfo {
            let trackName = userInfo["Name"] as? String ?? ""
            let artistName = userInfo["Artist"] as? String ?? ""
            let playerState = userInfo["Player State"] as? String ?? ""
            let duration = (userInfo["Duration"] as? Double ?? 0) / 1000.0
            let position = (userInfo["Position"] as? Double ?? 0) / 1000.0
            if !trackName.isEmpty {
                let provisional = NowPlayingInfo(
                    title: trackName,
                    artist: artistName,
                    album: userInfo["Album"] as? String ?? "",
                    duration: duration,
                    elapsedTime: position,
                    isPlaying: playerState == "Playing",
                    sourceApp: "com.spotify.client",
                    artworkURL: lastInfo?.artworkURL,
                    isShuffled: lastInfo?.isShuffled ?? false,
                    isRepeating: lastInfo?.isRepeating ?? false,
                    artworkData: lastInfo?.artworkData
                )
                publish(provisional)
            }
        }
        refreshNow()
    }

    @objc private func appleMusicPlaybackChanged(_ notification: Notification) {
        guard isAppleMusicConnected else { return }
        refreshNow()
    }

    private func publish(_ info: NowPlayingInfo) {
        consecutiveMisses = 0
        var mutable = info
        if info.artworkURL == lastArtworkURL, let existing = lastInfo?.artworkData, mutable.artworkData == nil {
            mutable.artworkData = existing
        }
        let changed = lastInfo.map { $0 != mutable || ($0.artworkData == nil && mutable.artworkData != nil) } ?? true
        lastInfo = mutable
        guard changed else {
            // Still tick progress to UI
            DispatchQueue.main.async { [weak self] in self?.onUpdate?(mutable) }
            return
        }
        let snapshot = mutable
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(snapshot)
            NotificationCenter.default.post(name: .nowPlayingDidChange, object: nil)
        }
        if let urlString = info.artworkURL, !urlString.isEmpty,
           (urlString != lastArtworkURL || mutable.artworkData == nil) {
            fetchArtwork(urlString: urlString, for: mutable)
        }
    }

    private func clear() {
        // Only clear if the source apps are not running — never wipe because AppleScript failed
        let spotifyRunning = isAppRunning("com.spotify.client")
        let musicRunning = isAppRunning("com.apple.Music")
        if (isSpotifyConnected && spotifyRunning) || (isAppleMusicConnected && musicRunning) {
            consecutiveMisses = 0
            return
        }
        consecutiveMisses += 1
        guard consecutiveMisses >= 2 else { return }
        guard lastInfo != nil else { return }
        lastInfo = nil
        lastArtworkURL = nil
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(nil) }
    }

    private func pollActivePlayer() {
        if isSpotifyConnected, isAppRunning("com.spotify.client") {
            if let info = querySpotify() {
                publish(info)
                return
            }
            // Script failed (likely Automation permission) — keep existing track if any
            if lastInfo?.sourceApp == "com.spotify.client" {
                consecutiveMisses = 0
                return
            }
        }
        if isAppleMusicConnected, isAppRunning("com.apple.Music") {
            if let info = queryAppleMusic() {
                publish(info)
                return
            }
            if lastInfo?.sourceApp == "com.apple.Music" {
                consecutiveMisses = 0
                return
            }
        }
        clear()
    }

    private func isAppRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func fetchArtwork(urlString: String, for info: NowPlayingInfo) {
        guard let url = URL(string: urlString) else { return }
        artworkTask?.cancel()
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 8
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, data.count > 100 else { return }
            DispatchQueue.main.async {
                guard var current = self.lastInfo,
                      current.title == info.title else { return }
                current.artworkData = data
                self.lastInfo = current
                self.lastArtworkURL = urlString
                self.onUpdate?(current)
            }
        }
        artworkTask = task
        task.resume()
    }

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
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == sourceBundleID }) {
            return (sourceBundleID, app.localizedName ?? sourceBundleID, app.icon)
        }
        let name = sourceBundleID == "com.spotify.client" ? "Spotify" : "Apple Music"
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceBundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        return (sourceBundleID, name, icon)
    }

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
        scriptQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.pollActivePlayer() }
    }

    func nextTrack() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to next track")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to next track")
        }
        scriptQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.pollActivePlayer() }
    }

    func previousTrack() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to previous track")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to previous track")
        }
        scriptQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.pollActivePlayer() }
    }

    func toggleShuffle() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set shuffling to not shuffling")
        }
        refreshNow()
    }

    func toggleRepeat() {
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set repeating to not repeating")
        }
        refreshNow()
    }

    func skipForward() {
        let s = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\" to set player position to ((player position) + \(s))")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\" to set player position to ((player position) + \(s))")
        }
        refreshNow()
    }

    func skipBackward() {
        let s = skipIncrementSeconds()
        if lastInfo?.sourceApp == "com.spotify.client" {
            runAppleScript("tell application \"Spotify\"\nset player position to ((player position) - \(s))\nif player position < 0 then set player position to 0\nend tell")
        } else if lastInfo?.sourceApp == "com.apple.Music" {
            runAppleScript("tell application \"Music\"\nset player position to ((player position) - \(s))\nif player position < 0 then set player position to 0\nend tell")
        }
        refreshNow()
    }

    private func skipIncrementSeconds() -> Int {
        Int((DataStore.shared.string(for: .skipIncrement) ?? "15s").replacingOccurrences(of: "s", with: "")) ?? 15
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previousTrack(); return .success }
    }

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
            // Fallback via osascript (more reliable Automation prompt)
            _ = runOsascript(source)
        }
    }

    private func runAppleScriptReturning(_ source: String) -> String? {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let result = script.executeAndReturnError(&error)
            if error == nil, let value = result.stringValue, !value.isEmpty {
                return value
            }
        }
        return runOsascript(source)
    }

    private func runOsascript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (str?.isEmpty == false) ? str : nil
        } catch {
            return nil
        }
    }

    private func querySpotify() -> NowPlayingInfo? {
        // Boring Notch style — artwork url of current track
        let source = """
        tell application "Spotify"
            if player state is stopped then return ""
            try
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set d to (duration of current track) / 1000.0
                set p to player position
                set playing to (player state is playing)
                set sh to shuffling
                set rp to repeating
                set art to artwork url of current track as string
                return t & "|||" & a & "|||" & al & "|||" & d & "|||" & p & "|||" & playing & "|||" & sh & "|||" & rp & "|||" & art
            on error
                return ""
            end try
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6, !parts[0].isEmpty else { return nil }
        let art = parts.count > 8 ? parts[8].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: Double(parts[3]) ?? 0,
            elapsedTime: Double(parts[4]) ?? 0,
            isPlaying: parts[5].lowercased().contains("true"),
            sourceApp: "com.spotify.client",
            artworkURL: art.isEmpty ? nil : art,
            isShuffled: parts.count > 6 && parts[6].lowercased().contains("true"),
            isRepeating: parts.count > 7 && parts[7].lowercased().contains("true"),
            artworkData: nil
        )
    }

    private func queryAppleMusic() -> NowPlayingInfo? {
        let source = """
        tell application "Music"
            if player state is stopped then return ""
            try
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set d to duration of current track
                set p to player position
                set playing to (player state is playing)
                return t & "|||" & a & "|||" & al & "|||" & d & "|||" & p & "|||" & playing
            on error
                return ""
            end try
        end tell
        """
        guard let raw = runAppleScriptReturning(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6, !parts[0].isEmpty else { return nil }
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: Double(parts[3]) ?? 0,
            elapsedTime: Double(parts[4]) ?? 0,
            isPlaying: parts[5].lowercased().contains("true"),
            sourceApp: "com.apple.Music",
            artworkURL: nil,
            isShuffled: false,
            isRepeating: false,
            artworkData: nil
        )
    }
}
