import SwiftUI

struct SettingsView: View {
    @State private var selectedSection: Section = .appearance
    @State private var appSettings = AppSettingsManager.shared

    @State private var appearanceMode: String = DataStore.shared.string(for: .appearanceMode) ?? "dark"
    @State private var glassEnabled: Bool = DataStore.shared.bool(for: .glassmorphismEnabled, default: true)
    @State private var dockVisible: Bool = DataStore.shared.bool(for: .dockVisible, default: false)
    @State private var menuBarVisible: Bool = DataStore.shared.bool(for: .menuBarIconVisible, default: true)

    @State private var defaultOpacity: Double = DataStore.shared.double(for: .defaultOpacity, default: 1.0)
    @State private var defaultBlur: Double = DataStore.shared.double(for: .defaultBlur, default: 0.5)
    @State private var defaultPin: Bool = DataStore.shared.bool(for: .defaultPin, default: false)

    @State private var notchStyle: String = DataStore.shared.string(for: .notchStyle) ?? "melted"
    @State private var notchHideDelay: Double = DataStore.shared.double(for: .notchHideDelay, default: 1.0)

    @State private var focusDuration: Int = Int(DataStore.shared.double(for: .pomodoroFocusDuration, default: 25))
    @State private var shortBreakDuration: Int = Int(DataStore.shared.double(for: .pomodoroShortBreakDuration, default: 5))
    @State private var longBreakDuration: Int = Int(DataStore.shared.double(for: .pomodoroLongBreakDuration, default: 15))
    @State private var cyclesBeforeLongBreak: Int = Int(DataStore.shared.double(for: .pomodoroCyclesBeforeLongBreak, default: 4))

    @State private var spotifyConnected: Bool = DataStore.shared.bool(for: .spotifyEnabled, default: true)
    @State private var appleMusicConnected: Bool = DataStore.shared.bool(for: .appleMusicEnabled, default: true)

    @State private var hoveredSection: Section?

    enum Section: String, CaseIterable {
        case appearance = "Appearance"
        case widgets = "Widgets"
        case notch = "Notch"
        case timers = "Timers"
        case connections = "Connections"
        case about = "About"

        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .widgets: return "square.grid.2x2"
            case .notch: return "rectangle.topthird.inset.filled"
            case .timers: return "timer"
            case .connections: return "cable.connector"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .layoutPriority(1)
            Divider()
            contentArea
                .layoutPriority(0)
        }
        .frame(minWidth: 580, minHeight: 420)
        .background(
            Group {
                if appSettings.glassmorphismEnabled {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Aura Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ForEach(Section.allCases, id: \.self) { section in
                sidebarItem(section)
            }

            Spacer()

            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(width: 180)
        .background(.regularMaterial)
    }

    private func sidebarItem(_ section: Section) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredSection == section

        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)

                Text(section.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            hoveredSection = hovering ? section : nil
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
            case .appearance: appearanceContent
            case .widgets: widgetContent
            case .notch: notchContent
            case .timers: timerContent
            case .connections: connectionsContent
            case .about: aboutContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Appearance

    private var appearanceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Theme")

                VStack(alignment: .leading, spacing: 12) {
                    settingsLabel("Appearance Mode")
                    Picker("", selection: $appearanceMode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appearanceMode) { _, newValue in
                        DataStore.shared.set(key: .appearanceMode, value: newValue)
                        switch newValue {
                        case "light":
                            NSApp.appearance = NSAppearance(named: .aqua)
                        case "dark":
                            NSApp.appearance = NSAppearance(named: .darkAqua)
                        default:
                            NSApp.appearance = nil
                        }
                    }
                }

                Divider()

                sectionHeader("Effects")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $glassEnabled) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Glassmorphism Effect")
                                .font(.system(size: 12, weight: .medium))
                            Text("Frosted glass background on widgets and menus")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: glassEnabled) { _, newValue in
                        AppSettingsManager.shared.saveAndNotify(glassmorphism: newValue)
                    }
                }

                Divider()

                sectionHeader("Visibility")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $dockVisible) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Show in Dock")
                                .font(.system(size: 12, weight: .medium))
                            Text("Display Aura icon in the macOS Dock")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: dockVisible) { _, newValue in
                        DataStore.shared.set(key: .dockVisible, value: newValue)
                        if newValue {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }

                    Toggle(isOn: $menuBarVisible) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Show Menu Bar Icon")
                                .font(.system(size: 12, weight: .medium))
                            Text("Show Aura icon in the menu bar")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: menuBarVisible) { _, newValue in
                        DataStore.shared.set(key: .menuBarIconVisible, value: newValue)
                        MenuBarManager.shared.toggleIconVisibility(newValue)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Widgets

    private var widgetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Default Widget Appearance")

                VStack(alignment: .leading, spacing: 16) {
                    sliderRow(
                        label: "Window Opacity",
                        description: "Overall transparency of widget windows",
                        value: $defaultOpacity,
                        range: 0.3...1.0,
                        onChange: { DataStore.shared.set(key: .defaultOpacity, value: $0) }
                    )

                    sliderRow(
                        label: "Backdrop Blur",
                        description: "Frosted glass blur intensity on widget backgrounds",
                        value: $defaultBlur,
                        range: 0.0...1.0,
                        onChange: { DataStore.shared.set(key: .defaultBlur, value: $0) }
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $defaultPin) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Pin by Default")
                                .font(.system(size: 12, weight: .medium))
                            Text("New widgets appear above all other windows")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: defaultPin) { _, newValue in
                        DataStore.shared.set(key: .defaultPin, value: newValue)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Notch

    private var notchContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Notch Bar")

                VStack(alignment: .leading, spacing: 12) {
                    settingsLabel("Style")
                    Picker("", selection: $notchStyle) {
                        Text("Melted Drop").tag("melted")
                        Text("Rounded Pill").tag("pill")
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: notchStyle) { _, newValue in
                        AppSettingsManager.shared.saveAndNotify(notchStyle: newValue)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    settingsLabel("Auto-Hide Delay: \(String(format: "%.1f", notchHideDelay))s")
                    Slider(value: $notchHideDelay, in: 0.5...3.0, step: 0.1)
                        .onChange(of: notchHideDelay) { _, newValue in
                            DataStore.shared.set(key: .notchHideDelay, value: newValue)
                        }
                    Text("How long the notch stays visible after your cursor leaves")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Divider()

                sectionHeader("Music Integration")

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Spotify", isOn: .constant(false))
                        .disabled(true)
                    Toggle("Apple Music", isOn: .constant(false))
                        .disabled(true)
                    Text("Music app integration coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Timers

    private var timerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Pomodoro Timer")

                VStack(alignment: .leading, spacing: 16) {
                    pickerRow(
                        label: "Focus Duration",
                        description: "Length of each focus session",
                        value: $focusDuration,
                        options: [
                            (15, "15 min"), (20, "20 min"), (25, "25 min"),
                            (30, "30 min"), (45, "45 min"), (50, "50 min"), (60, "60 min")
                        ],
                        onChange: { DataStore.shared.set(key: .pomodoroFocusDuration, value: Double($0)) }
                    )

                    pickerRow(
                        label: "Short Break",
                        description: "Break between focus sessions",
                        value: $shortBreakDuration,
                        options: [(3, "3 min"), (5, "5 min"), (10, "10 min")],
                        onChange: { DataStore.shared.set(key: .pomodoroShortBreakDuration, value: Double($0)) }
                    )

                    pickerRow(
                        label: "Long Break",
                        description: "Extended break after several cycles",
                        value: $longBreakDuration,
                        options: [(10, "10 min"), (15, "15 min"), (20, "20 min"), (30, "30 min")],
                        onChange: { DataStore.shared.set(key: .pomodoroLongBreakDuration, value: Double($0)) }
                    )

                    pickerRow(
                        label: "Cycles Before Long Break",
                        description: "Number of focus sessions before a long break",
                        value: $cyclesBeforeLongBreak,
                        options: [(2, "2"), (3, "3"), (4, "4"), (5, "5")],
                        onChange: { DataStore.shared.set(key: .pomodoroCyclesBeforeLongBreak, value: Double($0)) }
                    )
                }
            }
            .padding(24)
        }
    }

    // MARK: - Connections

    private var connectionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Music Integrations")

                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $spotifyConnected) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Spotify")
                                .font(.system(size: 12, weight: .medium))
                            Text("Show Spotify now playing in the notch")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: spotifyConnected) { _, newValue in
                        MediaTracker.shared.setSpotifyConnected(newValue)
                    }

                    Toggle(isOn: $appleMusicConnected) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Apple Music")
                                .font(.system(size: 12, weight: .medium))
                            Text("Show Apple Music now playing in the notch")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: appleMusicConnected) { _, newValue in
                        MediaTracker.shared.setAppleMusicConnected(newValue)
                    }
                }

                Divider()

                sectionHeader("Browser Support")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Now Playing works automatically with:")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Safari", systemImage: "checkmark.circle.fill")
                        Label("Chrome", systemImage: "checkmark.circle.fill")
                        Label("Brave", systemImage: "checkmark.circle.fill")
                        Label("Edge", systemImage: "checkmark.circle.fill")
                        Label("Opera", systemImage: "checkmark.circle.fill")
                        Label("Vivaldi", systemImage: "checkmark.circle.fill")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .padding(.leading, 4)
                }

                Divider()

                sectionHeader("How It Works")

                Text("Aura detects media playback from connected apps using macOS Now Playing. Any app that reports now playing information will automatically appear in the Aura notch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(24)
        }
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))

            Text("Aura")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Text("v1.0.0")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)

            Text("A minimal, glassmorphic command center for macOS.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func settingsLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
    }

    private func sliderRow(label: String, description: String, value: Binding<Double>, range: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .onChange(of: value.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func pickerRow(label: String, description: String, value: Binding<Int>, options: [(Int, String)], onChange: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Picker("", selection: value) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: value.wrappedValue) { _, newValue in
                onChange(newValue)
            }
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}
