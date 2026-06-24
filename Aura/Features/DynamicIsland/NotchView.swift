import SwiftUI

struct NotchView: View {
    let viewModel: NotchViewModel
    @State private var currentTime: Date = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)

            switch viewModel.state {
            case .collapsed:
                EmptyView()
            case .expanded:
                expandedContent
            case .media:
                mediaContent
            }
        }
        .frame(width: viewModel.currentFrame.width, height: viewModel.currentFrame.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.state)
        .onReceive(timer) { date in
            currentTime = date
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        HStack {
            Text(currentTimeString)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var mediaContent: some View {
        HStack(spacing: 12) {
            artworkPlaceholder
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.nowPlayingTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(viewModel.nowPlayingArtist)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                viewModel.isPlaying.toggle()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.white.opacity(0.12))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            )
    }

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
}
