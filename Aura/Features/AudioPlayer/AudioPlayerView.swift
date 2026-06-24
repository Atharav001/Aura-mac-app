import SwiftUI

struct AudioPlayerView: View {
    let playlist: [URL]
    @State private var currentIndex: Int
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(playlist: [URL], currentIndex: Int) {
        self.playlist = playlist
        self._currentIndex = State(initialValue: currentIndex)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(playlist[safe: currentIndex]?.lastPathComponent ?? "Unknown")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            progressBar

            HStack(spacing: 16) {
                Text(formattedTime(currentTime))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Button {
                    previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(playlist.count <= 1)

                Button {
                    LocalAudioManager.shared.togglePlayPause()
                    isPlaying = LocalAudioManager.shared.isPlaying
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(playlist.count <= 1)

                Spacer()

                Text(formattedTime(duration))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .glassmorphic(opacity: 0.12, material: .sidebar)
        .onAppear {
            playCurrent()
        }
        .onReceive(timer) { _ in
            guard LocalAudioManager.shared.isPlaying else { return }
            currentTime = LocalAudioManager.shared.currentTime
            duration = LocalAudioManager.shared.duration
            isPlaying = true
        }
    }

    private func playCurrent() {
        guard let url = playlist[safe: currentIndex] else { return }
        LocalAudioManager.shared.play(url: url)
        duration = LocalAudioManager.shared.duration
        currentTime = 0
        isPlaying = true
        LocalAudioManager.shared.onPlaybackEnded = { [self] in
            nextTrack()
        }
    }

    private func nextTrack() {
        guard playlist.count > 1 else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        playCurrent()
    }

    private func previousTrack() {
        guard playlist.count > 1 else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        playCurrent()
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))
                    .frame(height: 3)
                Capsule()
                    .fill(.white.opacity(0.5))
                    .frame(
                        width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0,
                        height: 3
                    )
                    .animation(.linear(duration: 0.2), value: currentTime)
            }
        }
        .frame(height: 3)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
