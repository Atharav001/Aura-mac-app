import Observation
import AppKit

@Observable
final class NotchViewModel {
    enum NotchState: String {
        case collapsed
        case expanded
        case media
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

    func showMedia(title: String, artist: String, isPlaying: Bool, progress: Double, duration: TimeInterval) {
        nowPlayingTitle = title
        nowPlayingArtist = artist
        self.isPlaying = isPlaying
        self.progress = progress
        self.duration = duration
        state = .media
    }

    func hideMedia() {
        state = isHovering ? .expanded : .collapsed
    }
}
