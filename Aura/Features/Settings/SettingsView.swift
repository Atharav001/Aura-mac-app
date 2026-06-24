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
    @State private var extendHoverArea = DataStore.shared.bool(for: .extendHoverArea, default: true)
    @State private var enableHaptics = DataStore.shared.bool(for: .enableHaptics, default: true)
    @State private var openNotchOnHover = DataStore.shared.bool(for: .openNotchOnHover, default: true)
    @State private var rememberLastTab = DataStore.shared.bool(for: .rememberLastTab, default: false)
    @State private var minHoverDuration: Double = DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    @State private var enableGestures = DataStore.shared.bool(for: .enableGestures, default: true)
    @State private var mediaHorizontalGestures = DataStore.shared.bool(for: .mediaHorizontalGestures, default: false)
    @State private var closeGesture = DataStore.shared.bool(for: .closeGesture, default: true)
    @State private var gestureSensitivity: Double = DataStore.shared.double(for: .gestureSensitivity, default: 0.5)
    @State private var notchHeightOption = DataStore.shared.string(for: .notchHeightOption) ?? "Match menubar height"

    // Appearance
    @State private var showTabs = DataStore.shared.bool(for: .showTabs, default: true)
    @State private var settingsIconInNotch = DataStore.shared.bool(for: .settingsIconInNotch, default: true)
    @State private var windowShadow = DataStore.shared.bool(for: .windowShadow, default: true)
    @State private var cornerRadiusScaling = DataStore.shared.bool(for: .cornerRadiusScaling, default: true)
    @State private var simpleCloseAnim = DataStore.shared.bool(for: .simpleCloseAnim, default: true)
    @State private var coloredSpectrograms = DataStore.shared.bool(for: .coloredSpectrograms, default: true)
    @State private var playerTinting = DataStore.shared.bool(for: .playerTinting, default: true)
    @State private var blurBehindAlbum = DataStore.shared.bool(for: .blurBehindAlbum, default: true)
    @State private var sliderColorOption = DataStore.shared.string(for: .sliderColorOption) ?? "Match album art"
    @State private var useSpectrogram = DataStore.shared.bool(for: .useSpectrogram, default: false)

    // Battery
    @State private var showBatteryGeneral1 = DataStore.shared.bool(for: .showBatteryInNotch, default: true)
    @State private var showBatteryGeneral2 = DataStore.shared.bool(for: .showBatteryPercentage, default: true)
    @State private var showBatteryInfo1 = DataStore.shared.bool(for: .showChargingIndicator, default: true)
    @State private var showBatteryInfo2 = DataStore.shared.bool(for: .showTimeRemaining, default: true)

    // Media
    @State private var musicSource = DataStore.shared.string(for: .musicSource) ?? "Spotify"
    @State private var showMediaControls = DataStore.shared.bool(for: .showMediaControls, default: true)
    @State private var liveActivityToggle1 = DataStore.shared.bool(for: .liveActivityToggle1, default: true)
    @State private var liveActivityToggle2 = DataStore.shared.bool(for: .liveActivityToggle2, default: true)
    @State private var liveActivityDefault = DataStore.shared.string(for: .liveActivityDefault) ?? "Default"
    @State private var liveActivityDuration = DataStore.shared.string(for: .liveActivityDuration) ?? "10 seconds"
    @State private var hideInFullscreen = DataStore.shared.string(for: .hideInFullscreen) ?? "Always hide in fullscreen"

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
    @State private var checkUpdatesAutomatically = DataStore.shared.bool(for: .checkUpdatesAutomatically, default: true)
    @State private var downloadBetaVersions = DataStore.shared.bool(for: .downloadBetaVersions, default: false)

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
        .frame(minWidth: 680, minHeight: 520)
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
                        .onChange(of: extendHoverArea) { _, nv in DataStore.shared.set(key: .extendHoverArea, value: nv) }
                    dividerRow
                    toggleRow("Enable haptics", value: $enableHaptics)
                        .onChange(of: enableHaptics) { _, nv in DataStore.shared.set(key: .enableHaptics, value: nv) }
                    dividerRow
                    toggleRow("Open notch on hover", value: $openNotchOnHover)
                        .onChange(of: openNotchOnHover) { _, nv in DataStore.shared.set(key: .openNotchOnHover, value: nv) }
                    dividerRow
                    toggleRow("Remember last tab", value: $rememberLastTab)
                        .onChange(of: rememberLastTab) { _, nv in DataStore.shared.set(key: .rememberLastTab, value: nv) }
                    dividerRow
                    sliderRow("Minimum hover duration", value: $minHoverDuration, range: 0.1...1.0, format: { String(format: "%.1fs", $0) })
                        .onChange(of: minHoverDuration) { _, nv in DataStore.shared.set(key: .notchHideDelay, value: nv) }
                }

                // Gesture control card
                settingsCard("Gesture control", badge: "Beta") {
                    toggleRow("Enable gestures", value: $enableGestures)
                        .onChange(of: enableGestures) { _, nv in DataStore.shared.set(key: .enableGestures, value: nv) }
                    dividerRow
                    toggleRow("Media change with horizontal gestures", value: $mediaHorizontalGestures)
                        .onChange(of: mediaHorizontalGestures) { _, nv in DataStore.shared.set(key: .mediaHorizontalGestures, value: nv) }
                    dividerRow
                    toggleRow("Close gesture", value: $closeGesture)
                        .onChange(of: closeGesture) { _, nv in DataStore.shared.set(key: .closeGesture, value: nv) }
                    dividerRow
                    sliderRow("Gesture sensitivity", value: $gestureSensitivity, range: 0...1, format: { v in v < 0.33 ? "Low" : v < 0.66 ? "Medium" : "High" })
                        .onChange(of: gestureSensitivity) { _, nv in DataStore.shared.set(key: .gestureSensitivity, value: nv) }
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
                        .onChange(of: showTabs) { _, nv in DataStore.shared.set(key: .showTabs, value: nv) }
                    dividerRow
                    toggleRow("Settings icon in notch", value: $settingsIconInNotch)
                        .onChange(of: settingsIconInNotch) { _, nv in DataStore.shared.set(key: .settingsIconInNotch, value: nv) }
                    dividerRow
                    toggleRow("Enable window shadow", value: $windowShadow)
                        .onChange(of: windowShadow) { _, nv in DataStore.shared.set(key: .windowShadow, value: nv) }
                    dividerRow
                    toggleRow("Corner radius scaling", value: $cornerRadiusScaling)
                        .onChange(of: cornerRadiusScaling) { _, nv in DataStore.shared.set(key: .cornerRadiusScaling, value: nv) }
                    dividerRow
                    toggleRow("Use simpler close animation", value: $simpleCloseAnim)
                        .onChange(of: simpleCloseAnim) { _, nv in DataStore.shared.set(key: .simpleCloseAnim, value: nv) }
                }

                // Media panel
                settingsCard("Media") {
                    toggleRow("Enable colored spectrograms", value: $coloredSpectrograms)
                        .onChange(of: coloredSpectrograms) { _, nv in DataStore.shared.set(key: .coloredSpectrograms, value: nv) }
                    dividerRow
                    toggleRow("Player tinting", value: $playerTinting)
                        .onChange(of: playerTinting) { _, nv in DataStore.shared.set(key: .playerTinting, value: nv) }
                    dividerRow
                    toggleRow("Enable blur effect behind album art", value: $blurBehindAlbum)
                        .onChange(of: blurBehindAlbum) { _, nv in DataStore.shared.set(key: .blurBehindAlbum, value: nv) }
                    dividerRow
                    chevronRow("Slider color", value: $sliderColorOption)
                        .onChange(of: sliderColorOption) { _, nv in DataStore.shared.set(key: .sliderColorOption, value: nv) }
                }

                // Custom music live activity animation
                settingsCard("Custom music live activity animation", badge: "Coming soon") {
                    toggleRow("Use music visualizer spectrogram", value: $useSpectrogram)
                        .onChange(of: useSpectrogram) { _, nv in DataStore.shared.set(key: .useSpectrogram, value: nv) }
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
                        .onChange(of: showBatteryGeneral1) { _, nv in
                            DataStore.shared.set(key: .showBatteryInNotch, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show percentage", value: $showBatteryGeneral2)
                        .onChange(of: showBatteryGeneral2) { _, nv in
                            DataStore.shared.set(key: .showBatteryPercentage, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                }

                settingsCard("Battery Information") {
                    toggleRow("Show charging indicator", value: $showBatteryInfo1)
                        .onChange(of: showBatteryInfo1) { _, nv in
                            DataStore.shared.set(key: .showChargingIndicator, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show time remaining", value: $showBatteryInfo2)
                        .onChange(of: showBatteryInfo2) { _, nv in
                            DataStore.shared.set(key: .showTimeRemaining, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
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
                                            DataStore.shared.set(key: .musicSource, value: src)
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
                        .onChange(of: showMediaControls) { _, nv in
                            DataStore.shared.set(key: .showMediaControls, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                }

                // Live Activity
                settingsCard("Live activity") {
                    toggleRow("Show now playing", value: $liveActivityToggle1)
                        .onChange(of: liveActivityToggle1) { _, nv in
                            DataStore.shared.set(key: .liveActivityToggle1, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show playback progress", value: $liveActivityToggle2)
                        .onChange(of: liveActivityToggle2) { _, nv in
                            DataStore.shared.set(key: .liveActivityToggle2, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    chevronRow("Default view", value: $liveActivityDefault)
                        .onChange(of: liveActivityDefault) { _, nv in DataStore.shared.set(key: .liveActivityDefault, value: nv) }
                    dividerRow
                    chevronRow("Hide after", value: $liveActivityDuration)
                        .onChange(of: liveActivityDuration) { _, nv in DataStore.shared.set(key: .liveActivityDuration, value: nv) }
                    dividerRow
                    chevronRow("Fullscreen behavior", value: $hideInFullscreen, badge: "Beta")
                        .onChange(of: hideInFullscreen) { _, nv in DataStore.shared.set(key: .hideInFullscreen, value: nv) }
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

                // Spotify
                settingsCard("Music Integrations") {
                    VStack(spacing: 8) {
                        appConnectionRow(
                            appName: "Spotify",
                            bundleID: "com.spotify.client",
                            isConnected: $spotifyConnected,
                            onToggle: { nv in MediaTracker.shared.setSpotifyConnected(nv) }
                        )
                        dividerRow
                        appConnectionRow(
                            appName: "Apple Music",
                            bundleID: "com.apple.Music",
                            isConnected: $appleMusicConnected,
                            onToggle: { nv in MediaTracker.shared.setAppleMusicConnected(nv) }
                        )
                    }
                }

                settingsCard("Now Playing Status") {
                    VStack(alignment: .leading, spacing: 6) {
                        let notchVM = NotchManager.shared.viewModel
                        if spotifyConnected || appleMusicConnected {
                            if !notchVM.nowPlayingTitle.isEmpty {
                                HStack {
                                    Image(systemName: "music.note").foregroundColor(.green).font(.system(size: 10))
                                    Text("Now Playing: \(notchVM.nowPlayingTitle)")
                                        .font(.system(size: 11)).foregroundColor(.white)
                                    Spacer()
                                }
                                HStack {
                                    Text(notchVM.nowPlayingArtist)
                                        .font(.system(size: 10)).foregroundColor(settingsSecondaryText)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(.orange).font(.system(size: 10))
                                    Text("Listening... waiting for playback")
                                        .font(.system(size: 11)).foregroundColor(settingsSecondaryText)
                                    Spacer()
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "poweroff").foregroundColor(settingsSecondaryText).font(.system(size: 10))
                                Text("Enable Spotify or Apple Music above")
                                    .font(.system(size: 11)).foregroundColor(settingsSecondaryText)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
                    Text("Aura uses macOS Distributed Notification Center to detect when Spotify or Apple Music changes tracks. No private APIs required. Enable the apps above, then play music — it will appear in the Aura notch automatically.")
                        .font(.system(size: 11))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(4)
                }
            }
            .padding(20)
        }
    }

    private func appConnectionRow(appName: String, bundleID: String, isConnected: Binding<Bool>, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            if let appIcon = appIcon(for: bundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: appName == "Spotify" ? "music.note.list" : "apple.logo")
                    .font(.system(size: 14))
                    .foregroundColor(settingsSecondaryText)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(appName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Text(isConnected.wrappedValue ? "Connected" : "Not connected")
                    .font(.system(size: 9))
                    .foregroundColor(isConnected.wrappedValue ? .green : settingsSecondaryText)
            }

            Spacer()

            Button(isConnected.wrappedValue ? "Disconnect" : "Connect") {
                if !isConnected.wrappedValue {
                    NSWorkspace.shared.openApplication(at: applicationURL(for: bundleID), configuration: NSWorkspace.OpenConfiguration())
                }
                isConnected.wrappedValue.toggle()
                onToggle(isConnected.wrappedValue)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isConnected.wrappedValue ? Color.red.opacity(0.3) : settingsBlue.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(settingsBorder))
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    private func applicationURL(for bundleID: String) -> URL {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) ?? URL(string: "https://\(bundleID == "com.spotify.client" ? "spotify.com" : "apple.com/music")")!
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
                        toggleRow("Check automatically", value: $checkUpdatesAutomatically)
                            .onChange(of: checkUpdatesAutomatically) { _, nv in DataStore.shared.set(key: .checkUpdatesAutomatically, value: nv) }
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        toggleRow("Download beta versions", value: $downloadBetaVersions)
                            .onChange(of: downloadBetaVersions) { _, nv in DataStore.shared.set(key: .downloadBetaVersions, value: nv) }
                    }

                    settingsCard(nil) {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://opencode.ai/sponsor")!)
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill").foregroundColor(.white).font(.system(size: 12))
                                Text("Support Us").foregroundColor(.white).font(.system(size: 12))
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(settingsSecondaryText).font(.system(size: 10))
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(settingsBorder).frame(height: 1)
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/anomalyco/Aura-mac-app")!)
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundColor(.white).font(.system(size: 12))
                                Text("GitHub").foregroundColor(.white).font(.system(size: 12))
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(settingsSecondaryText).font(.system(size: 10))
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
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

    private func headerWithButton(_ text: String, buttonTitle: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Button(buttonTitle) {
                if text == "General" {
                    NSApp.terminate(nil)
                } else if text == "About" {
                    NSWorkspace.shared.open(URL(string: "https://github.com/anomalyco/aura/releases")!)
                }
                action?()
            }
            .font(.system(size: 11))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(settingsBorder)
            )
            .buttonStyle(.plain)
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
