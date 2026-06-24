import AppKit
import MediaPlayer

final class MediaTracker: @unchecked Sendable {
    static let shared = MediaTracker()

    private var timer: Timer?

    struct NowPlayingInfo: Equatable {
        let title: String
        let artist: String
        let duration: Double
        let elapsedTime: Double
        let isPlaying: Bool
    }

    var onUpdate: ((NowPlayingInfo?) -> Void)?
    private var lastInfo: NowPlayingInfo?

    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollLocalPlayback()
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func pollLocalPlayback() {
        Task { @MainActor in
            let manager = LocalAudioManager.shared
            let info: NowPlayingInfo?
            if let url = manager.currentURL {
                info = NowPlayingInfo(
                    title: url.deletingPathExtension().lastPathComponent,
                    artist: "Local File",
                    duration: manager.duration,
                    elapsedTime: manager.currentTime,
                    isPlaying: manager.isPlaying
                )
            } else {
                info = nil
            }

            if info != self.lastInfo {
                self.lastInfo = info
                self.publishToSystem(info)
                self.onUpdate?(info)
            }
        }
    }

    private func publishToSystem(_ info: NowPlayingInfo?) {
        guard let info else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0
        ]
    }
}
