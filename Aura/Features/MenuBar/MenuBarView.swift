import SwiftUI

struct MenuBarView: View {
    let viewModel: MenuBarViewModel
    @State private var hoveredButton: String?
    @State private var appSettings = AppSettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().overlay(.primary.opacity(0.08)).padding(.horizontal, 16)

            commandCenterSection
            Divider().overlay(.primary.opacity(0.08)).padding(.horizontal, 16)

            settingsRow
            Spacer(minLength: 8)

            Divider().overlay(.primary.opacity(0.08)).padding(.horizontal, 16)
            footerSection
        }
        .padding(.bottom, 4)
        .glassmorphic(opacity: 0.28, material: .popover, blendingMode: .behindWindow, cornerRadius: 14)
        .tint(appSettings.accentColor)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.45, blue: 0.95).opacity(0.85),
                                Color(red: 0.35, green: 0.62, blue: 1.0).opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(nsImage: MenuBarIconFactory.makeIcon(size: 16))
                    .renderingMode(.template)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Aura")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Command Center")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Command Center Actions

    private var commandCenterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("QUICK ACTIONS")

            menuButton(
                id: "pomodoro",
                icon: "timer",
                title: "Start Pomodoro",
                subtitle: "Focus ↔ break loop"
            ) {
                NotificationCenter.default.post(name: .startPomodoro, object: nil)
                MenuBarManager.shared.closePopover()
            }

            menuButton(
                id: "deepwork",
                icon: "brain.head.profile",
                title: "Start Deep Work",
                subtitle: "Long focus session"
            ) {
                NotificationCenter.default.post(name: .startDeepWork, object: nil)
                MenuBarManager.shared.closePopover()
            }

            menuButton(
                id: "stopwatch",
                icon: "stopwatch",
                title: "Spawn Stopwatch",
                subtitle: "Floating timer widget"
            ) {
                PanelManager.shared.spawnPanel(size: NSSize(width: 280, height: 380)) {
                    WidgetContainer {
                        StopwatchWidget()
                    }
                }
                MenuBarManager.shared.closePopover()
            }

            menuButton(
                id: "todo",
                icon: "checklist",
                title: "Spawn To-Do List",
                subtitle: "Your saved tasks"
            ) {
                PanelManager.shared.spawnPanel(size: NSSize(width: 320, height: 420)) {
                    WidgetContainer {
                        TodoWidget()
                    }
                }
                MenuBarManager.shared.closePopover()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Settings

    private var settingsRow: some View {
        Button {
            MenuBarManager.shared.closePopover()
            PanelManager.shared.openSettingsWindow()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Notch, media, modules & timers")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hoveredButton == "settings" ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onHover { hoveredButton = $0 ? "settings" : nil }
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("v1.0.0")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 6)
            .padding(.bottom, 2)
    }

    private func menuButton(id: String, icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hoveredButton == id ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
            )
            .animation(AnimationCurves.widgetAppear, value: hoveredButton == id)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hoveredButton = $0 ? id : nil }
    }
}

extension Notification.Name {
    static let startPomodoro = Notification.Name("com.aura.startPomodoro")
    static let startDeepWork = Notification.Name("com.aura.startDeepWork")
}
