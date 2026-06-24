import AppKit
import Foundation

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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        fetchViaMediaRemote { [weak self] info in
            guard let self else { return }
            if info != self.lastInfo {
                self.lastInfo = info
                DispatchQueue.main.async {
                    self.onUpdate?(info)
                }
            }
        }
    }

    private func fetchViaMediaRemote(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_LAZY
        ) else {
            completion(nil)
            return
        }
        defer { dlclose(handle) }

        guard let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            completion(nil)
            return
        }

        let fn = unsafeBitCast(
            sym,
            to: (@convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void).self
        )
        fn(DispatchQueue.main) { dict in
            guard let dict else { completion(nil); return }
            let info = NowPlayingInfo(
                title: dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown",
                artist: dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown",
                duration: dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0,
                elapsedTime: dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0,
                isPlaying: (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
            )
            completion(info)
        }
    }
}
