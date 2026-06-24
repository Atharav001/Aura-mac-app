import SwiftUI

struct MenuBarView: View {
    let viewModel: MenuBarViewModel
    @State private var hoveredButton: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 16)

                focusSection
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 16)

                widgetSection
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 16)

                audioHubSection
                Spacer(minLength: 0)

                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 16)
                footerSection
            }
        }
        .scrollIndicators(.hidden)
        .glassmorphic(opacity: 0.3, material: .popover)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 1) {
                Text("Aura")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Command Center")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FOCUS")

            menuButton(
                id: "pomodoro",
                icon: "timer",
                title: "Start Pomodoro",
                subtitle: "25 min focus session"
            ) {
                NotificationCenter.default.post(name: .startPomodoro, object: nil)
                MenuBarManager.shared.closePopover()
            }

            menuButton(
                id: "deepwork",
                icon: "brain.head.profile",
                title: "Start Deep Work",
                subtitle: "50 min focus session"
            ) {
                NotificationCenter.default.post(name: .startDeepWork, object: nil)
                MenuBarManager.shared.closePopover()
            }

            menuButton(
                id: "stopwatch",
                icon: "stopwatch",
                title: "Spawn Stopwatch",
                subtitle: "Count up timer widget"
            ) {
                PanelManager.shared.spawnPanel(size: NSSize(width: 280, height: 320)) {
                    WidgetContainer {
                        StopwatchWidget()
                    }
                }
                MenuBarManager.shared.closePopover()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Widget Section

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("WIDGETS")

            menuButton(
                id: "todo",
                icon: "checklist",
                title: "Spawn To-Do Widget",
                subtitle: "Task list with DataStore"
            ) {
                PanelManager.shared.spawnPanel(size: NSSize(width: 320, height: 420)) {
                    WidgetContainer {
                        TodoWidget()
                    }
                }
                MenuBarManager.shared.closePopover()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Audio Hub Section

    private var audioHubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("LOCAL AUDIO HUB")

            Button {
                viewModel.selectMusicDirectory()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18)
                    Text(viewModel.musicDirectory?.lastPathComponent ?? "Select Music Folder")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.06))
                )
            }
            .buttonStyle(PlainButtonStyle())

            if viewModel.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning for MP3 files...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 6)
                .padding(.vertical, 4)
            }

            if !viewModel.mp3Files.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(viewModel.mp3Files, id: \.self) { file in
                            audioFileRow(file)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            if viewModel.mp3Files.isEmpty && viewModel.musicDirectory != nil && !viewModel.isScanning {
                Text("No MP3 files found")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 6)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func audioFileRow(_ url: URL) -> some View {
        Button {
            viewModel.playMP3(url)
            MenuBarManager.shared.closePopover()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 16)

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 0) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit Aura")
                        .font(.system(size: 11, weight: .regular))
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("v1.0.0")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.trailing, 16)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Shared Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.leading, 6)
    }

    private func menuButton(id: String, icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hoveredButton == id ? .white.opacity(0.12) : .white.opacity(0.05))
            )
            .animation(AnimationCurves.widgetAppear, value: hoveredButton == id)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered in
            hoveredButton = isHovered ? id : nil
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let startPomodoro = Notification.Name("com.aura.startPomodoro")
    static let startDeepWork = Notification.Name("com.aura.startDeepWork")
}
