import SwiftUI

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
    @State private var hoverExpandDelay: Double = DataStore.shared.double(for: .hoverExpandDelay, default: 0.0)
    @State private var enableGestures = DataStore.shared.bool(for: .enableGestures, default: true)
    @State private var mediaHorizontalGestures = DataStore.shared.bool(for: .mediaHorizontalGestures, default: false)
    @State private var closeGesture = DataStore.shared.bool(for: .closeGesture, default: true)
    @State private var gestureSensitivity: Double = DataStore.shared.double(for: .gestureSensitivity, default: 0.5)
    @State private var middleClickAction = DataStore.shared.string(for: .middleClickAction) ?? "Cycle states"
    @State private var screenshotPrivacy = DataStore.shared.bool(for: .screenshotPrivacy, default: false)

    // Display
    @State private var notchHeightOption = DataStore.shared.string(for: .notchHeightOption) ?? "Match menubar height"
    @State private var nonNotchHeight = DataStore.shared.string(for: .nonNotchDisplayHeight) ?? "Match menubar height"
    @State private var notchWidth: Double = DataStore.shared.double(for: .notchWidth, default: 520)
    @State private var simulatedNotch = DataStore.shared.bool(for: .simulatedNotch, default: false)
    @State private var duoModeEnabled = DataStore.shared.bool(for: .duoModeEnabled, default: false)
    @State private var duoModeSplit: Double = DataStore.shared.double(for: .duoModeSplit, default: 60)

    // Appearance
    @State private var notchStyle = DataStore.shared.string(for: .notchStyle) ?? "melted"
    @State private var glassVariant = DataStore.shared.string(for: .glassVariant) ?? "sidebar"
    @State private var borderColor = DataStore.shared.string(for: .borderColor) ?? ""
    @State private var borderWidth: Double = DataStore.shared.double(for: .borderWidth, default: 0.5)
    @State private var appearanceMode = DataStore.shared.string(for: .appearanceMode) ?? "dark"
    @State private var glassEnabled = DataStore.shared.bool(for: .glassmorphismEnabled, default: true)
    @State private var showTabs = DataStore.shared.bool(for: .showTabs, default: true)
    @State private var settingsIconInNotch = DataStore.shared.bool(for: .settingsIconInNotch, default: true)
    @State private var windowShadow = DataStore.shared.bool(for: .windowShadow, default: true)
    @State private var cornerRadiusScaling = DataStore.shared.bool(for: .cornerRadiusScaling, default: true)
    @State private var simpleCloseAnim = DataStore.shared.bool(for: .simpleCloseAnim, default: true)
    @State private var disableOvershoot = DataStore.shared.bool(for: .disableOvershoot, default: false)
    @State private var dockVisible = DataStore.shared.bool(for: .dockVisible, default: false)
    @State private var menuBarVisible = DataStore.shared.bool(for: .menuBarIconVisible, default: true)

    // Media / Music
    @State private var musicSource = DataStore.shared.string(for: .musicSource) ?? "Spotify"
    @State private var showMediaControls = DataStore.shared.bool(for: .showMediaControls, default: true)
    @State private var showVisualizer = DataStore.shared.bool(for: .showVisualizer, default: false)
    @State private var skipIncrement = DataStore.shared.string(for: .skipIncrement) ?? "15s"
    @State private var liveActivityToggle1 = DataStore.shared.bool(for: .liveActivityToggle1, default: true)
    @State private var liveActivityToggle2 = DataStore.shared.bool(for: .liveActivityToggle2, default: true)
    @State private var liveActivityDefault = DataStore.shared.string(for: .liveActivityDefault) ?? "Default"
    @State private var hideInFullscreen = DataStore.shared.string(for: .hideInFullscreen) ?? "Always hide in fullscreen"

    // Appearance media
    @State private var coloredSpectrograms = DataStore.shared.bool(for: .coloredSpectrograms, default: true)
    @State private var playerTinting = DataStore.shared.bool(for: .playerTinting, default: true)
    @State private var blurBehindAlbum = DataStore.shared.bool(for: .blurBehindAlbum, default: true)
    @State private var sliderColorOption = DataStore.shared.string(for: .sliderColorOption) ?? "Match album art"
    @State private var useSpectrogram = DataStore.shared.bool(for: .useSpectrogram, default: false)

    // Battery
    @State private var showBatteryInNotch = DataStore.shared.bool(for: .showBatteryInNotch, default: true)
    @State private var showBatteryPercentage = DataStore.shared.bool(for: .showBatteryPercentage, default: true)
    @State private var showChargingIndicator = DataStore.shared.bool(for: .showChargingIndicator, default: true)
    @State private var showTimeRemaining = DataStore.shared.bool(for: .showTimeRemaining, default: true)

    // Calendar
    @State private var hideAllDayEvents = DataStore.shared.bool(for: .hideAllDayEvents, default: false)
    @State private var calendarTitleTruncation = DataStore.shared.bool(for: .calendarTitleTruncation, default: true)

    // Shelf
    @State private var shelfEnabled = DataStore.shared.bool(for: .shelfEnabled, default: true)
    @State private var shelfAutoRemove = DataStore.shared.bool(for: .shelfAutoRemove, default: false)

    // Clipboard
    @State private var clipboardEnabled = DataStore.shared.bool(for: .clipboardEnabled, default: true)
    @State private var clipboardHistorySize: Double = DataStore.shared.double(for: .clipboardHistorySize, default: 48)

    // Camera
    @State private var cameraMirrorEnabled = DataStore.shared.bool(for: .cameraMirrorEnabled, default: false)

    // System HUD
    @State private var replaceSystemHUD = DataStore.shared.bool(for: .replaceSystemHUD, default: false)

    // Pomodoro
    @State private var focusDuration = Int(DataStore.shared.double(for: .pomodoroFocusDuration, default: 25))
    @State private var shortBreakDuration = Int(DataStore.shared.double(for: .pomodoroShortBreakDuration, default: 5))
    @State private var longBreakDuration = Int(DataStore.shared.double(for: .pomodoroLongBreakDuration, default: 15))
    @State private var cyclesBeforeLongBreak = Int(DataStore.shared.double(for: .pomodoroCyclesBeforeLongBreak, default: 4))

    // Widget defaults
    @State private var defaultOpacity = DataStore.shared.double(for: .defaultOpacity, default: 1.0)
    @State private var defaultBlur = DataStore.shared.double(for: .defaultBlur, default: 0.5)
    @State private var defaultPin = DataStore.shared.bool(for: .defaultPin, default: false)

    // Connections
    @State private var spotifyConnected = DataStore.shared.bool(for: .spotifyEnabled, default: true)
    @State private var appleMusicConnected = DataStore.shared.bool(for: .appleMusicEnabled, default: true)

    // About
    @State private var checkUpdatesAutomatically = DataStore.shared.bool(for: .checkUpdatesAutomatically, default: true)
    @State private var downloadBetaVersions = DataStore.shared.bool(for: .downloadBetaVersions, default: false)

    @State private var hoveredSection: Section?
    @State private var showMusicSourcePicker = false
    @State private var showMiddleClickPicker = false
    @State private var showSkipPicker = false

    enum Section: String, CaseIterable {
        case general = "General"
        case display = "Display"
        case appearance = "Appearance"
        case interactions = "Interactions"
        case media = "Media"
        case modules = "Modules"
        case calendar = "Calendar"
        case system = "System"
        case battery = "Battery"
        case connections = "Connections"
        case timers = "Timers"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .display: return "rectangle.3.group"
            case .appearance: return "paintpalette"
            case .interactions: return "hand.point.up"
            case .media: return "music.note"
            case .modules: return "square.3.layers.3d"
            case .calendar: return "calendar"
            case .system: return "gearshape.2"
            case .battery: return "battery.100"
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
        .frame(minWidth: 720, minHeight: 560)
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
        .onHover { hovering in hoveredSection = hovering ? section : nil }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
            case .general: generalContent
            case .display: displayContent
            case .appearance: appearanceContent
            case .interactions: interactionsContent
            case .media: mediaContent
            case .modules: modulesContent
            case .calendar: calendarContent
            case .system: systemContent
            case .battery: batteryContent
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

                settingsCard("Notch behavior") {
                    toggleRow("Open notch on hover", value: $openNotchOnHover)
                        .onChange(of: openNotchOnHover) { _, nv in DataStore.shared.set(key: .openNotchOnHover, value: nv) }
                    dividerRow
                    toggleRow("Extend hover area", value: $extendHoverArea)
                        .onChange(of: extendHoverArea) { _, nv in DataStore.shared.set(key: .extendHoverArea, value: nv) }
                    dividerRow
                    toggleRow("Remember last tab", value: $rememberLastTab)
                        .onChange(of: rememberLastTab) { _, nv in DataStore.shared.set(key: .rememberLastTab, value: nv) }
                    dividerRow
                    toggleRow("Screenshot privacy", value: $screenshotPrivacy)
                        .onChange(of: screenshotPrivacy) { _, nv in DataStore.shared.set(key: .screenshotPrivacy, value: nv) }
                }

                settingsCard("Hover timings") {
                    sliderRow("Expand delay", value: $hoverExpandDelay, range: 0.0...1.0, format: { String(format: "%.1fs", $0) })
                        .onChange(of: hoverExpandDelay) { _, nv in DataStore.shared.set(key: .hoverExpandDelay, value: nv) }
                    dividerRow
                    sliderRow("Hide delay", value: $minHoverDuration, range: 0.1...1.0, format: { String(format: "%.1fs", $0) })
                        .onChange(of: minHoverDuration) { _, nv in DataStore.shared.set(key: .notchHideDelay, value: nv) }
                }

                settingsCard("Animations") {
                    toggleRow("Use simpler close animation", value: $simpleCloseAnim)
                        .onChange(of: simpleCloseAnim) { _, nv in DataStore.shared.set(key: .simpleCloseAnim, value: nv) }
                    dividerRow
                    toggleRow("Disable spring overshoot", value: $disableOvershoot)
                        .onChange(of: disableOvershoot) { _, nv in DataStore.shared.set(key: .disableOvershoot, value: nv) }
                    dividerRow
                    toggleRow("Enable window shadow", value: $windowShadow)
                        .onChange(of: windowShadow) { _, nv in DataStore.shared.set(key: .windowShadow, value: nv) }
                }

                settingsCard("Dock & Menu Bar") {
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

                footerText("Two-finger swipe up on notch to hide, two-finger swipe down to open when hover is disabled.")
            }
            .padding(20)
        }
    }

    // MARK: - Display

    private var displayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Display")

                settingsCard("Notch Display Height") {
                    chevronRow("Notch height", value: $notchHeightOption)
                        .onChange(of: notchHeightOption) { _, nv in DataStore.shared.set(key: .notchHeightOption, value: nv) }
                    dividerRow
                    chevronRow("Non-notch display height", value: $nonNotchHeight)
                        .onChange(of: nonNotchHeight) { _, nv in DataStore.shared.set(key: .nonNotchDisplayHeight, value: nv) }
                    dividerRow
                    toggleRow("Simulate notch on non-notch displays", value: $simulatedNotch)
                        .onChange(of: simulatedNotch) { _, nv in DataStore.shared.set(key: .simulatedNotch, value: nv) }
                }

                settingsCard("Notch Width") {
                    sliderRow("Width", value: $notchWidth, range: 320...640, format: { "\(Int($0))pt" })
                        .onChange(of: notchWidth) { _, nv in DataStore.shared.set(key: .notchWidth, value: nv) }
                }

                settingsCard("Duo Mode") {
                    toggleRow("Enable Duo Mode", value: $duoModeEnabled)
                        .onChange(of: duoModeEnabled) { _, nv in DataStore.shared.set(key: .duoModeEnabled, value: nv) }
                    dividerRow
                    if duoModeEnabled {
                        sliderRow("Split ratio", value: $duoModeSplit, range: 50...80, format: { "\(Int($0))/\(100 - Int($0))" })
                            .onChange(of: duoModeSplit) { _, nv in DataStore.shared.set(key: .duoModeSplit, value: nv) }
                    }
                }

                settingsCard("Tab Bar") {
                    toggleRow("Show tab bar in expanded notch", value: $showTabs)
                        .onChange(of: showTabs) { _, nv in DataStore.shared.set(key: .showTabs, value: nv) }
                    dividerRow
                    toggleRow("Settings icon in notch", value: $settingsIconInNotch)
                        .onChange(of: settingsIconInNotch) { _, nv in DataStore.shared.set(key: .settingsIconInNotch, value: nv) }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Appearance

    private var appearanceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Appearance")

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
                }

                settingsCard("Material Variant") {
                    chevronRow("Glass variant", value: $glassVariant)
                        .onChange(of: glassVariant) { _, nv in DataStore.shared.set(key: .glassVariant, value: nv) }
                }

                settingsCard("Notch Style") {
                    HStack {
                        Text("Style").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $notchStyle) {
                            Text("Melted").tag("melted")
                            Text("Pill").tag("pill")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        .onChange(of: notchStyle) { _, nv in AppSettingsManager.shared.saveAndNotify(notchStyle: nv) }
                    }
                    dividerRow
                    HStack {
                        Text("Border color").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        TextField("Hex (#RRGGBB)", text: $borderColor)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(settingsSecondaryText)
                            .frame(width: 100)
                            .onChange(of: borderColor) { _, nv in DataStore.shared.set(key: .borderColor, value: nv) }
                    }
                    dividerRow
                    sliderRow("Border width", value: $borderWidth, range: 0...3, format: { String(format: "%.1fpt", $0) })
                        .onChange(of: borderWidth) { _, nv in DataStore.shared.set(key: .borderWidth, value: nv) }
                }

                settingsCard("Extras") {
                    toggleRow("Corner radius scaling", value: $cornerRadiusScaling)
                        .onChange(of: cornerRadiusScaling) { _, nv in DataStore.shared.set(key: .cornerRadiusScaling, value: nv) }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Interactions

    private var interactionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Interactions")

                settingsCard("Gestures") {
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

                settingsCard("Mouse & Keyboard") {
                    chevronRow("Middle click action", value: $middleClickAction)
                        .onChange(of: middleClickAction) { _, nv in DataStore.shared.set(key: .middleClickAction, value: nv) }
                    dividerRow
                    toggleRow("Enable haptics", value: $enableHaptics)
                        .onChange(of: enableHaptics) { _, nv in DataStore.shared.set(key: .enableHaptics, value: nv) }
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

                settingsCard("Now Playing") {
                    toggleRow("Show media controls in notch", value: $showMediaControls)
                        .onChange(of: showMediaControls) { _, nv in
                            DataStore.shared.set(key: .showMediaControls, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show visualizer", value: $showVisualizer)
                        .onChange(of: showVisualizer) { _, nv in DataStore.shared.set(key: .showVisualizer, value: nv) }
                    dividerRow
                    chevronRow("Skip increment", value: $skipIncrement)
                        .onChange(of: skipIncrement) { _, nv in DataStore.shared.set(key: .skipIncrement, value: nv) }
                }

                settingsCard("Live Activity") {
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
                    chevronRow("Fullscreen behavior", value: $hideInFullscreen, badge: "Beta")
                        .onChange(of: hideInFullscreen) { _, nv in DataStore.shared.set(key: .hideInFullscreen, value: nv) }
                }

                settingsCard("Player Appearance") {
                    toggleRow("Player tinting from album art", value: $playerTinting)
                        .onChange(of: playerTinting) { _, nv in DataStore.shared.set(key: .playerTinting, value: nv) }
                    dividerRow
                    toggleRow("Enable blur effect behind album art", value: $blurBehindAlbum)
                        .onChange(of: blurBehindAlbum) { _, nv in DataStore.shared.set(key: .blurBehindAlbum, value: nv) }
                    dividerRow
                    toggleRow("Colored spectrograms", value: $coloredSpectrograms)
                        .onChange(of: coloredSpectrograms) { _, nv in DataStore.shared.set(key: .coloredSpectrograms, value: nv) }
                    dividerRow
                    chevronRow("Slider color", value: $sliderColorOption)
                        .onChange(of: sliderColorOption) { _, nv in DataStore.shared.set(key: .sliderColorOption, value: nv) }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Modules

    private var modulesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Modules")

                settingsCard("Shelf (Drop Zone)") {
                    toggleRow("Enable Shelf", value: $shelfEnabled)
                        .onChange(of: shelfEnabled) { _, nv in DataStore.shared.set(key: .shelfEnabled, value: nv) }
                    dividerRow
                    toggleRow("Auto-remove on drag out", value: $shelfAutoRemove)
                        .onChange(of: shelfAutoRemove) { _, nv in DataStore.shared.set(key: .shelfAutoRemove, value: nv) }
                    dividerRow
                    Text("Drag files to the notch area to stage them temporarily. Drag out to move, or use Option+drag to copy.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(3)
                }

                settingsCard("Clipboard Monitor") {
                    toggleRow("Enable clipboard monitoring", value: $clipboardEnabled)
                        .onChange(of: clipboardEnabled) { _, nv in DataStore.shared.set(key: .clipboardEnabled, value: nv) }
                    dividerRow
                    sliderRow("History size", value: $clipboardHistorySize, range: 10...100, format: { "\(Int($0)) items" })
                        .onChange(of: clipboardHistorySize) { _, nv in DataStore.shared.set(key: .clipboardHistorySize, value: nv) }
                    dividerRow
                    Text("Tracks your last copied items. Tap any item to re-copy it. Pin important items with the yellow dot.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(3)
                }

                settingsCard("Camera Mirror") {
                    toggleRow("Enable camera mirror", value: $cameraMirrorEnabled)
                        .onChange(of: cameraMirrorEnabled) { _, nv in DataStore.shared.set(key: .cameraMirrorEnabled, value: nv) }
                    dividerRow
                    Text("Quick mirror to check your appearance before video calls. Camera activates only when the mirror tab is open.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(3)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Calendar

    private var calendarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Calendar")

                settingsCard("Display") {
                    toggleRow("Hide all-day events", value: $hideAllDayEvents)
                        .onChange(of: hideAllDayEvents) { _, nv in DataStore.shared.set(key: .hideAllDayEvents, value: nv) }
                    dividerRow
                    toggleRow("Truncate long titles", value: $calendarTitleTruncation)
                        .onChange(of: calendarTitleTruncation) { _, nv in DataStore.shared.set(key: .calendarTitleTruncation, value: nv) }
                    dividerRow
                    Text("Tap an event to see details. Tap a day in the week view to see all events for that day.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(3)
                }
            }
            .padding(20)
        }
    }

    // MARK: - System

    private var systemContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("System")

                settingsCard("System HUD Replacement") {
                    toggleRow("Replace system volume/brightness HUD", value: $replaceSystemHUD)
                        .onChange(of: replaceSystemHUD) { _, nv in DataStore.shared.set(key: .replaceSystemHUD, value: nv) }
                    dividerRow
                    Text("When enabled, Aura will suppress the native macOS volume and brightness bezel overlays and show compact sliders in the notch instead.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .lineSpacing(3)
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
                    toggleRow("Show battery in notch", value: $showBatteryInNotch)
                        .onChange(of: showBatteryInNotch) { _, nv in
                            DataStore.shared.set(key: .showBatteryInNotch, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show percentage", value: $showBatteryPercentage)
                        .onChange(of: showBatteryPercentage) { _, nv in
                            DataStore.shared.set(key: .showBatteryPercentage, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                }
                settingsCard("Battery Information") {
                    toggleRow("Show charging indicator", value: $showChargingIndicator)
                        .onChange(of: showChargingIndicator) { _, nv in
                            DataStore.shared.set(key: .showChargingIndicator, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                    dividerRow
                    toggleRow("Show time remaining", value: $showTimeRemaining)
                        .onChange(of: showTimeRemaining) { _, nv in
                            DataStore.shared.set(key: .showTimeRemaining, value: nv)
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
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
            .background(RoundedRectangle(cornerRadius: 6).stroke(settingsBorder))
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
            VStack(spacing: 0) { content() }
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

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(settingsSecondaryText)
            .lineSpacing(3)
            .padding(.top, 4)
    }
}
