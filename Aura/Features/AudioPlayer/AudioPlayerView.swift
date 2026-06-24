import SwiftUI

struct AudioPlayerView: View {
    let url: URL
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            Text(url.lastPathComponent)
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
                    LocalAudioManager.shared.togglePlayPause()
                    isPlaying = LocalAudioManager.shared.isPlaying
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(formattedTime(duration))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .glassmorphic(opacity: 0.12, material: .sidebar)
        .onAppear {
            LocalAudioManager.shared.play(url: url)
            duration = LocalAudioManager.shared.duration
            isPlaying = true
            LocalAudioManager.shared.onPlaybackEnded = {
                isPlaying = false
                currentTime = 0
            }
        }
        .onReceive(timer) { _ in
            guard LocalAudioManager.shared.isPlaying else { return }
            currentTime = LocalAudioManager.shared.currentTime
            duration = LocalAudioManager.shared.duration
            isPlaying = true
        }
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
