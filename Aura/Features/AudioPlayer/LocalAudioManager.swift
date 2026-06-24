import AppKit
import AVFoundation

@MainActor
final class LocalAudioManager: NSObject {
    static let shared = LocalAudioManager()

    private var player: AVAudioPlayer?
    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentURL: URL?
    var onPlaybackEnded: (() -> Void)?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayFile),
            name: .playAudioFile,
            object: nil
        )
    }

    @objc private func handlePlayFile(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        play(url: url)
    }

    func play(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            currentURL = url
        } catch {
            currentURL = nil
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentURL = nil
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
    }

    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }
}

extension LocalAudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.onPlaybackEnded?()
        }
    }
}
