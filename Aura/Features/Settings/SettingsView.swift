import SwiftUI

// MARK: - Boring Notch style settings

let settingsSidebarBG = Color(nsColor: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1))
let settingsContentBG = Color(nsColor: NSColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1))
let settingsCardBG = Color(nsColor: NSColor(red: 0.173, green: 0.173, blue: 0.173, alpha: 1))
let settingsBorder = Color.white.opacity(0.06)
let settingsCyan = Color(red: 0.196, green: 0.678, blue: 0.902)
let settingsBlue = Color(red: 0, green: 0.478, blue: 1)
let settingsSecondaryText = Color(red: 0.6, green: 0.6, blue: 0.6)
let settingsBadgeBG = Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))

struct SettingsView: View {
    @State private var selectedSection: Section = .general
    @State private var appSettings = AppSettingsManager.shared

    // General
    @State private var extendHoverArea = true
    @State private var enableHaptics = true
    @State private var openNotchOnHover = true
    @State private var rememberLastTab = false
    @State private var minHoverDuration: Double = DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    @State private var enableGestures = true
    @State private var mediaHorizontalGestures = false
    @State private var closeGesture = true
    @State private var gestureSensitivity: Double = 0.5
    @State private var notchHeightOption = "Match menubar height"

    // Appearance
    @State private var showTabs = true
    @State private var settingsIconInNotch = true
    @State private var windowShadow = true
    @State private var cornerRadiusScaling = true
    @State private var simpleCloseAnim = true
    @State private var coloredSpectrograms = true
    @State private var playerTinting = true
    @State private var blurBehindAlbum = true
    @State private var sliderColorOption = "Match album art"
    @State private var useSpectrogram = false

    // Battery
    @State private var showBatteryGeneral1 = true
    @State private var showBatteryGeneral2 = true
    @State private var showBatteryInfo1 = true
    @State private var showBatteryInfo2 = true

    // Media
    @State private var musicSource = "Spotify"
    @State private var showMediaControls = true
    @State private var liveActivityToggle1 = true
    @State private var liveActivityToggle2 = true
    @State private var liveActivityDefault = "Default"
    @State private var liveActivityDuration = "10 seconds"
    @State private var hideInFullscreen = "Always hide in fullscreen"

    // Our existing settings
    @State private var appearanceMode = DataStore.shared.string(for: .appearanceMode) ?? "dark"
    @State private var glassEnabled = DataStore.shared.bool(for: .glassmorphismEnabled, default: true)
    @State private var dockVisible = DataStore.shared.bool(for: .dockVisible, default: false)
    @State private var menuBarVisible = DataStore.shared.bool(for: .menuBarIconVisible, default: true)
    @State private var notchStyle = DataStore.shared.string(for: .notchStyle) ?? "melted"
    @State private var notchHideDelay = DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    @State private var defaultOpacity = DataStore.shared.double(for: .defaultOpacity, default: 1.0)
    @State private var defaultBlur = DataStore.shared.double(for: .defaultBlur, default: 0.5)
    @State private var defaultPin = DataStore.shared.bool(for: .defaultPin, default: false)
    @State private var focusDuration = Int(DataStore.shared.double(for: .pomodoroFocusDuration, default: 25))
    @State private var shortBreakDuration = Int(DataStore.shared.double(for: .pomodoroShortBreakDuration, default: 5))
    @State private var longBreakDuration = Int(DataStore.shared.double(for: .pomodoroLongBreakDuration, default: 15))
    @State private var cyclesBeforeLongBreak = Int(DataStore.shared.double(for: .pomodoroCyclesBeforeLongBreak, default: 4))
    @State private var spotifyConnected = DataStore.shared.bool(for: .spotifyEnabled, default: true)
    @State private var appleMusicConnected = DataStore.shared.bool(for: .appleMusicEnabled, default: true)

    @State private var hoveredSection: Section?
    @State private var showMusicSourcePicker = false

    enum Section: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case battery = "Battery"
        case media = "Media"
        case connections = "Connections"
        case timers = "Timers"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .battery: return "battery.100"
            case .media: return "music.note"
            case .connections: return "cable.connector"
            case .timers: return "timer"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .layoutPriority(1)
            Rectangle().fill(settingsBorder).frame(width: 1)
            contentArea
        }
        .frame(minWidth: 620, minHeight: 460)
        .background(settingsContentBG)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Aura")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 20)

            ForEach(Section.allCases, id: \.self) { section in
                sidebarItem(section)
            }

            Spacer()

            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundColor(settingsSecondaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(width: 180)
        .background(settingsSidebarBG)
    }

    private func sidebarItem(_ section: Section) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredSection == section

        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? settingsBlue : settingsCyan)
                    .frame(width: 20)

                Text(section.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : settingsSecondaryText)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? settingsBlue.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
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
            case .general: generalContent
            case .appearance: appearanceContent
            case .battery: batteryContent
            case .media: mediaContent
            case .connections: connectionsContent
            case .timers: timerContent
            case .about: aboutContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settingsContentBG)
    }

    // MARK: - General

    private var generalContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerWithButton("General", buttonTitle: "Quit app")

                // Notch behavior card
                settingsCard("Notch behavior") {
                    toggleRow("Extend hover area", value: $extendHoverArea)
                    dividerRow
                    toggleRow("Enable haptics", value: $enableHaptics)
                    dividerRow
                    toggleRow("Open notch on hover", value: $openNotchOnHover)
                    dividerRow
                    toggleRow("Remember last tab", value: $rememberLastTab)
                    dividerRow
                    sliderRow("Minimum hover duration", value: $minHoverDuration, range: 0.1...1.0, format: { String(format: "%.1fs", $0) })
                        .onChange(of: minHoverDuration) { _, nv in DataStore.shared.set(key: .notchHideDelay, value: nv) }
                }

                // Gesture control card
                settingsCard("Gesture control", badge: "Beta") {
                    toggleRow("Enable gestures", value: $enableGestures)
                    dividerRow
                    toggleRow("Media change with horizontal gestures", value: $mediaHorizontalGestures)
                    dividerRow
                    toggleRow("Close gesture", value: $closeGesture)
                    dividerRow
                    sliderRow("Gesture sensitivity", value: $gestureSensitivity, range: 0...1, format: { v in v < 0.33 ? "Low" : v < 0.66 ? "Medium" : "High" })
                }

                footerText("Two-finger swipe up on notch to close, two-finger swipe down on notch to open when Open notch on hover option is disabled")
            }
            .padding(20)
        }
    }

    // MARK: - Appearance

    private var appearanceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Appearance")

                // Custom - Theme
                settingsCard("Theme") {
                    HStack {
                        Text("Appearance Mode").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $appearanceMode) {
                            Text("Dark").tag("dark")
                            Text("Light").tag("light")
                            Text("System").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: appearanceMode) { _, nv in
                            DataStore.shared.set(key: .appearanceMode, value: nv)
                            NSApp.appearance = nv == "dark" ? NSAppearance(named: .darkAqua) : nv == "light" ? NSAppearance(named: .aqua) : nil
                        }
                    }
                    dividerRow
                    toggleRow("Glassmorphism Effect", value: $glassEnabled)
                        .onChange(of: glassEnabled) { _, nv in AppSettingsManager.shared.saveAndNotify(glassmorphism: nv) }
                    dividerRow
                    toggleRow("Show in Dock", value: $dockVisible)
                        .onChange(of: dockVisible) { _, nv in
                            DataStore.shared.set(key: .dockVisible, value: nv)
                            if nv { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
                        }
                    dividerRow
                    toggleRow("Show Menu Bar Icon", value: $menuBarVisible)
                        .onChange(of: menuBarVisible) { _, nv in
                            DataStore.shared.set(key: .menuBarIconVisible, value: nv)
                            MenuBarManager.shared.toggleIconVisibility(nv)
                        }
                }

                // General panel (Boring Notch style)
                settingsCard("General") {
                    toggleRow("Always show tabs", value: $showTabs)
                    dividerRow
                    toggleRow("Settings icon in notch", value: $settingsIconInNotch)
                    dividerRow
                    toggleRow("Enable window shadow", value: $windowShadow)
                    dividerRow
                    toggleRow("Corner radius scaling", value: $cornerRadiusScaling)
                    dividerRow
                    toggleRow("Use simpler close animation", value: $simpleCloseAnim)
                }

                // Media panel
                settingsCard("Media") {
                    toggleRow("Enable colored spectrograms", value: $coloredSpectrograms)
                    dividerRow
                    toggleRow("Player tinting", value: $playerTinting)
                    dividerRow
                    toggleRow("Enable blur effect behind album art", value: $blurBehindAlbum)
                    dividerRow
                    chevronRow("Slider color", value: $sliderColorOption)
                }

                // Custom music live activity animation
                settingsCard("Custom music live activity animation", badge: "Coming soon") {
                    toggleRow("Use music visualizer spectrogram", value: $useSpectrogram)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Battery

    private var batteryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Battery")

                settingsCard("General") {
                    toggleRow("Show battery in notch", value: $showBatteryGeneral1)
                    dividerRow
                    toggleRow("Show percentage", value: $showBatteryGeneral2)
                }

                settingsCard("Battery Information") {
                    toggleRow("Show charging indicator", value: $showBatteryInfo1)
                    dividerRow
                    toggleRow("Show time remaining", value: $showBatteryInfo2)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Media

    private var mediaContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Media")

                // Media Source
                settingsCard("Media Source") {
                    VStack(spacing: 4) {
                        Button {
                            showMusicSourcePicker.toggle()
                        } label: {
                            HStack {
                                Text("Music Source").foregroundColor(.white).font(.system(size: 12))
                                Spacer()
                                Text(musicSource).foregroundColor(settingsSecondaryText).font(.system(size: 12))
                                Image(systemName: "chevron.up.down").foregroundColor(settingsSecondaryText).font(.system(size: 9))
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            if showMusicSourcePicker {
                                VStack(spacing: 0) {
                                    ForEach(["Spotify", "Apple Music", "Local Files", "System Audio"], id: \.self) { src in
                                        Button {
                                            musicSource = src
                                            showMusicSourcePicker = false
                                        } label: {
                                            HStack {
                                                Text(src).foregroundColor(.white).font(.system(size: 12))
                                                Spacer()
                                                if src == musicSource {
                                                    Image(systemName: "checkmark").foregroundColor(.white).font(.system(size: 10))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(src == musicSource ? settingsBlue.opacity(0.3) : Color.clear)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(width: 160)
                                .background(settingsCardBG)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(settingsBorder))
                                .shadow(color: .black.opacity(0.3), radius: 8)
                                .offset(x: 0, y: 28)
                            }
                        }
                        Text("Select which music service to display in the notch")
                            .font(.system(size: 10)).foregroundColor(settingsSecondaryText)
                    }
                }

                // Media Controls
                settingsCard("Media controls", badge: "Beta") {
                    toggleRow("Show media controls in notch", value: $showMediaControls)
                }

                // Live Activity
                settingsCard("Live activity") {
                    toggleRow("Show now playing", value: $liveActivityToggle1)
                    dividerRow
                    toggleRow("Show playback progress", value: $liveActivityToggle2)
                    dividerRow
                    chevronRow("Default view", value: $liveActivityDefault)
                    dividerRow
                    chevronRow("Hide after", value: $liveActivityDuration)
                    dividerRow
                    chevronRow("Fullscreen behavior", value: $hideInFullscreen, badge: "Beta")
                }
            }
            .padding(20)
        }
    }

    // MARK: - Connections

    private var connectionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Connections")

                settingsCard("Music Integrations") {
                    toggleRow("Spotify", value: $spotifyConnected)
                        .onChange(of: spotifyConnected) { _, nv in MediaTracker.shared.setSpotifyConnected(nv) }
                    dividerRow
                    toggleRow("Apple Music", value: $appleMusicConnected)
                        .onChange(of: appleMusicConnected) { _, nv in MediaTracker.shared.setAppleMusicConnected(nv) }
                }

                settingsCard("Browser Support") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(["Safari", "Chrome", "Brave", "Edge", "Opera", "Vivaldi"], id: \.self) { browser in
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 10))
                                Text(browser).foregroundColor(.white).font(.system(size: 11))
                            }
                            if browser != "Vivaldi" {
                                Rectangle().fill(settingsBorder).frame(height: 1).padding(.leading, 16)
                            }
                        }
                    }
                }

                settingsCard("How It Works") {
                    Text("Aura detects media playback from connected apps using macOS Now Playing. Any app that reports now playing information will automatically appear in the Aura notch.")
                        .font(.system(size: 11))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Timers

    private var timerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Timers")

                settingsCard("Pomodoro Timer") {
                    VStack(spacing: 12) {
                        timerPickerRow("Focus Duration", value: $focusDuration, options: [(15, "15 min"), (20, "20 min"), (25, "25 min"), (30, "30 min"), (45, "45 min"), (50, "50 min"), (60, "60 min")])
                            .onChange(of: focusDuration) { _, nv in DataStore.shared.set(key: .pomodoroFocusDuration, value: Double(nv)) }
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        timerPickerRow("Short Break", value: $shortBreakDuration, options: [(3, "3 min"), (5, "5 min"), (10, "10 min")])
                            .onChange(of: shortBreakDuration) { _, nv in DataStore.shared.set(key: .pomodoroShortBreakDuration, value: Double(nv)) }
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        timerPickerRow("Long Break", value: $longBreakDuration, options: [(10, "10 min"), (15, "15 min"), (20, "20 min"), (30, "30 min")])
                            .onChange(of: longBreakDuration) { _, nv in DataStore.shared.set(key: .pomodoroLongBreakDuration, value: Double(nv)) }
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        timerPickerRow("Cycles", value: $cyclesBeforeLongBreak, options: [(2, "2"), (3, "3"), (4, "4"), (5, "5")])
                            .onChange(of: cyclesBeforeLongBreak) { _, nv in DataStore.shared.set(key: .pomodoroCyclesBeforeLongBreak, value: Double(nv)) }
                    }
                }

                if #available(macOS 14.0, *) {
                    settingsCard("Widget Defaults") {
                        opacitySliderRow("Window Opacity", value: $defaultOpacity, onChange: { DataStore.shared.set(key: .defaultOpacity, value: $0) })
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        opacitySliderRow("Backdrop Blur", value: $defaultBlur, onChange: { DataStore.shared.set(key: .defaultBlur, value: $0) })
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        toggleRow("Pin by Default", value: $defaultPin)
                            .onChange(of: defaultPin) { _, nv in DataStore.shared.set(key: .defaultPin, value: nv) }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerWithButton("About", buttonTitle: "Check for Updates...")

                    settingsCard(nil) {
                        HStack {
                            Text("Version").foregroundColor(settingsSecondaryText).font(.system(size: 12))
                            Spacer()
                            Text("Aura").foregroundColor(settingsSecondaryText).font(.system(size: 12))
                        }
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        HStack {
                            Text("Build").foregroundColor(settingsSecondaryText).font(.system(size: 12))
                            Spacer()
                            Text("1.0.0").foregroundColor(settingsSecondaryText).font(.system(size: 12))
                        }
                    }

                    settingsCard("Software updates") {
                        toggleRow("Check automatically", value: .constant(false))
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        toggleRow("Download beta versions", value: .constant(false))
                    }

                    settingsCard(nil) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill").foregroundColor(.white).font(.system(size: 12))
                            Text("Support Us").foregroundColor(.white).font(.system(size: 12))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(settingsSecondaryText).font(.system(size: 10))
                        }
                        .padding(.vertical, 2)
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundColor(.white).font(.system(size: 12))
                            Text("GitHub").foregroundColor(.white).font(.system(size: 12))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(settingsSecondaryText).font(.system(size: 10))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(20)
            }

            // Footer
            HStack {
                Spacer()
                Text("Made with 🫶🏻 by Aura")
                    .font(.system(size: 10))
                    .foregroundColor(settingsSecondaryText)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(settingsCardBG)
        }
    }

    // MARK: - Reusable Components

    private func headerText(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
        }
    }

    private func headerWithButton(_ text: String, buttonTitle: String) -> some View {
        HStack {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text(buttonTitle)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(settingsBorder)
                )
        }
    }

    private func settingsCard(_ title: String?, badge: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(settingsSecondaryText).textCase(.uppercase)
                    if let badge {
                        Text(badge).font(.system(size: 9, weight: .medium)).foregroundColor(settingsSecondaryText)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(settingsBadgeBG)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(settingsCardBG)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(settingsBorder))
        }
    }

    private var dividerRow: some View {
        Rectangle().fill(settingsBorder).frame(height: 1).padding(.vertical, 1)
    }

    private func toggleRow(_ label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label).foregroundColor(.white).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(settingsBlue)
        }
        .padding(.vertical, 4)
    }

    private func chevronRow(_ label: String, value: Binding<String>, badge: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundColor(.white).font(.system(size: 12))
            if let badge {
                Text(badge).font(.system(size: 9, weight: .medium)).foregroundColor(settingsSecondaryText)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(settingsBadgeBG)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
            Text(value.wrappedValue).foregroundColor(settingsSecondaryText).font(.system(size: 12))
            Image(systemName: "chevron.up.down").foregroundColor(settingsSecondaryText).font(.system(size: 8))
        }
        .padding(.vertical, 4)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, format: @escaping (Double) -> String) -> some View {
        HStack {
            Text(label).foregroundColor(.white).font(.system(size: 12))
            Spacer()
            Text(format(value.wrappedValue)).foregroundColor(settingsSecondaryText).font(.system(size: 11))
            Slider(value: value, in: range)
                .tint(settingsBlue)
                .controlSize(.small)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
    }

    private func opacitySliderRow(_ label: String, value: Binding<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).foregroundColor(.white).font(.system(size: 12))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%").foregroundColor(settingsSecondaryText).font(.system(size: 11, design: .monospaced))
            }
            Slider(value: value, in: 0.3...1.0).tint(settingsBlue).controlSize(.small)
                .onChange(of: value.wrappedValue) { _, nv in onChange(nv) }
        }
        .padding(.vertical, 4)
    }

    private func timerPickerRow(_ label: String, value: Binding<Int>, options: [(Int, String)]) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).foregroundColor(.white).font(.system(size: 12))
                Spacer()
            }
            Picker("", selection: value) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0).foregroundColor(.white)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(settingsSecondaryText)
            .lineSpacing(3)
            .padding(.top, 4)
    }
}
