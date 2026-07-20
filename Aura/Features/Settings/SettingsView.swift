import SwiftUI
import AppKit

private let settingsSidebarBG = Color(nsColor: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1))
private let settingsContentBG = Color(nsColor: NSColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1))
private let settingsCardBG = Color(nsColor: NSColor(red: 0.173, green: 0.173, blue: 0.173, alpha: 1))
private let settingsBorder = Color.white.opacity(0.06)
private let settingsCyan = Color(red: 0.196, green: 0.678, blue: 0.902)
private let settingsBlue = Color(red: 0, green: 0.478, blue: 1)
private let settingsSecondaryText = Color(red: 0.6, green: 0.6, blue: 0.6)

struct SettingsView: View {
    @State private var selectedSection: Section = .general
    @State private var appSettings = AppSettingsManager.shared

    // General
    @State private var openNotchOnHover = DataStore.shared.bool(for: .openNotchOnHover, default: true)
    @State private var extendHoverArea = DataStore.shared.bool(for: .extendHoverArea, default: true)
    @State private var notchEnabled = DataStore.shared.bool(for: .notchEnabled, default: true)
    @State private var rememberLastTab = DataStore.shared.bool(for: .rememberLastTab, default: false)
    @State private var minHoverDuration: Double = DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    @State private var hoverExpandDelay: Double = DataStore.shared.double(for: .hoverExpandDelay, default: 0.15)
    @State private var disableOvershoot = DataStore.shared.bool(for: .disableOvershoot, default: false)
    @State private var windowShadow = DataStore.shared.bool(for: .windowShadow, default: true)
    @State private var dockVisible = DataStore.shared.bool(for: .dockVisible, default: false)
    @State private var menuBarVisible = DataStore.shared.bool(for: .menuBarIconVisible, default: true)
    @State private var simpleCloseAnim = DataStore.shared.bool(for: .simpleCloseAnim, default: true)
    @State private var cornerRadiusScaling = DataStore.shared.bool(for: .cornerRadiusScaling, default: true)
    @State private var closeGesture = DataStore.shared.bool(for: .closeGesture, default: true)
    @State private var notchHeightOption = DataStore.shared.string(for: .notchHeightOption) ?? "Match real notch size"
    @State private var coloredSpectrograms = DataStore.shared.bool(for: .coloredSpectrograms, default: true)

    // Display / Appearance
    @State private var duoModeEnabled = DataStore.shared.bool(for: .duoModeEnabled, default: true)
    @State private var notchWidth: Double = DataStore.shared.double(for: .notchWidth, default: 620)
    @State private var simulatedNotch = DataStore.shared.bool(for: .simulatedNotch, default: false)
    @State private var duoModeSplit: Double = DataStore.shared.double(for: .duoModeSplit, default: 60)
    @State private var notchStyle = DataStore.shared.string(for: .notchStyle) ?? "melted"
    @State private var glassVariant = DataStore.shared.string(for: .glassVariant) ?? "ios"
    @State private var appearanceMode = DataStore.shared.string(for: .appearanceMode) ?? "dark"
    @State private var glassEnabled = DataStore.shared.bool(for: .glassmorphismEnabled, default: true)
    @State private var settingsIconInNotch = DataStore.shared.bool(for: .settingsIconInNotch, default: true)
    @State private var borderWidth: Double = DataStore.shared.double(for: .borderWidth, default: 0.5)

    // Interactions
    @State private var enableGestures = DataStore.shared.bool(for: .enableGestures, default: true)
    @State private var mediaHorizontalGestures = DataStore.shared.bool(for: .mediaHorizontalGestures, default: true)
    @State private var middleClickAction = DataStore.shared.string(for: .middleClickAction) ?? "Cycle states"
    @State private var replaceSystemHUD = DataStore.shared.bool(for: .replaceSystemHUD, default: false)

    // Media
    @State private var showMediaControls = DataStore.shared.bool(for: .showMediaControls, default: true)
    @State private var showVisualizer = DataStore.shared.bool(for: .showVisualizer, default: true)
    @State private var skipIncrement = DataStore.shared.string(for: .skipIncrement) ?? "15s"
    @State private var playerTinting = DataStore.shared.bool(for: .playerTinting, default: true)
    @State private var blurBehindAlbum = DataStore.shared.bool(for: .blurBehindAlbum, default: true)
    @State private var spotifyConnected = DataStore.shared.bool(for: .spotifyEnabled, default: true)
    @State private var appleMusicConnected = DataStore.shared.bool(for: .appleMusicEnabled, default: true)

    // Modules
    @State private var shelfEnabled = DataStore.shared.bool(for: .shelfEnabled, default: true)
    @State private var shelfAutoRemove = DataStore.shared.bool(for: .shelfAutoRemove, default: true)
    @State private var clipboardEnabled = DataStore.shared.bool(for: .clipboardEnabled, default: true)
    @State private var clipboardHistorySize: Double = DataStore.shared.double(for: .clipboardHistorySize, default: 48)

    // Calendar / Battery
    @State private var hideAllDayEvents = DataStore.shared.bool(for: .hideAllDayEvents, default: false)
    @State private var calendarTitleTruncation = DataStore.shared.bool(for: .calendarTitleTruncation, default: true)
    @State private var showBatteryInNotch = DataStore.shared.bool(for: .showBatteryInNotch, default: true)
    @State private var showBatteryPercentage = DataStore.shared.bool(for: .showBatteryPercentage, default: true)

    // Timers / Widgets
    @State private var focusDuration = Int(DataStore.shared.double(for: .pomodoroFocusDuration, default: 25))
    @State private var shortBreakDuration = Int(DataStore.shared.double(for: .pomodoroShortBreakDuration, default: 5))
    @State private var longBreakDuration = Int(DataStore.shared.double(for: .pomodoroLongBreakDuration, default: 15))
    @State private var cyclesBeforeLongBreak = Int(DataStore.shared.double(for: .pomodoroCyclesBeforeLongBreak, default: 4))
    @State private var defaultOpacity = DataStore.shared.double(for: .defaultOpacity, default: 1.0)
    @State private var defaultBlur = DataStore.shared.double(for: .defaultBlur, default: 0.55)
    @State private var defaultPin = DataStore.shared.bool(for: .defaultPin, default: true)

    @State private var hoveredSection: Section?

    enum Section: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case media = "Media"
        case modules = "Modules"
        case timers = "Timers"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .media: return "music.note"
            case .modules: return "square.3.layers.3d"
            case .timers: return "timer"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(settingsBorder).frame(width: 1)
            contentArea
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(settingsContentBG)
    }

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

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
            case .general: generalContent
            case .appearance: appearanceContent
            case .media: mediaContent
            case .modules: modulesContent
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
                headerWithQuit("General")

                settingsCard("System") {
                    toggleRow("Launch at login", value: Binding(
                        get: { LaunchAtLoginManager.isEnabled },
                        set: { LaunchAtLoginManager.isEnabled = $0 }
                    ), onChange: { _ in })
                }

                settingsCard("Notch behavior") {
                    toggleRow("Enable notch", value: $notchEnabled) {
                        DataStore.shared.set(key: .notchEnabled, value: $0)
                        notifySettings()
                        NotificationCenter.default.post(name: .notchEnabledDidChange, object: nil)
                    }
                    dividerRow
                    toggleRow("Open on hover", value: $openNotchOnHover) {
                        DataStore.shared.set(key: .openNotchOnHover, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Extend hover area", value: $extendHoverArea) {
                        DataStore.shared.set(key: .extendHoverArea, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Remember last tab", value: $rememberLastTab) {
                        DataStore.shared.set(key: .rememberLastTab, value: $0)
                        notifySettings()
                    }
                }

                settingsCard("Timings") {
                    sliderRow("Expand delay", value: $hoverExpandDelay, range: 0.0...1.0, format: { String(format: "%.1fs", $0) }) {
                        DataStore.shared.set(key: .hoverExpandDelay, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    sliderRow("Hide delay", value: $minHoverDuration, range: 0.1...1.5, format: { String(format: "%.1fs", $0) }) {
                        DataStore.shared.set(key: .notchHideDelay, value: $0)
                        notifySettings()
                    }
                }

                settingsCard("Interactions") {
                    toggleRow("Volume / brightness gestures on notch", value: $enableGestures) {
                        DataStore.shared.set(key: .enableGestures, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Swipe media tracks", value: $mediaHorizontalGestures) {
                        DataStore.shared.set(key: .mediaHorizontalGestures, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Replace system volume HUD", value: $replaceSystemHUD) {
                        DataStore.shared.set(key: .replaceSystemHUD, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    HStack {
                        Text("Middle click").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $middleClickAction) {
                            Text("Cycle notch").tag("Cycle states")
                            Text("Play / Pause").tag("Toggle play/pause")
                            Text("Off").tag("None")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .onChange(of: middleClickAction) { _, nv in
                            DataStore.shared.set(key: .middleClickAction, value: nv)
                            notifySettings()
                        }
                    }
                    .padding(.vertical, 4)
                }

                settingsCard("Menu Bar & Dock") {
                    toggleRow("Show Menu Bar icon", value: $menuBarVisible) {
                        DataStore.shared.set(key: .menuBarIconVisible, value: $0)
                        MenuBarManager.shared.toggleIconVisibility($0)
                    }
                    dividerRow
                    toggleRow("Show in Dock", value: $dockVisible) {
                        DataStore.shared.set(key: .dockVisible, value: $0)
                        if $0 {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                        } else {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
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
                        Text("Appearance").foregroundColor(.white).font(.system(size: 12))
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
                            NSApp.appearance = nv == "dark" ? NSAppearance(named: .darkAqua)
                                : nv == "light" ? NSAppearance(named: .aqua) : nil
                        }
                    }
                    dividerRow
                    toggleRow("Glassmorphism", value: $glassEnabled) {
                        AppSettingsManager.shared.saveAndNotify(glassmorphism: $0)
                    }
                    dividerRow
                    HStack {
                        Text("Glass style").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $glassVariant) {
                            Text("iOS").tag("ios")
                            Text("Clear").tag("clear")
                            Text("Sidebar").tag("sidebar")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .onChange(of: glassVariant) { _, nv in
                            DataStore.shared.set(key: .glassVariant, value: nv)
                            notifySettings()
                        }
                    }
                    .padding(.vertical, 4)
                }

                settingsCard("Notch shape") {
                    HStack {
                        Text("Style").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $notchStyle) {
                            Text("Melted").tag("melted")
                            Text("Pill").tag("pill")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        .onChange(of: notchStyle) { _, nv in
                            AppSettingsManager.shared.saveAndNotify(notchStyle: nv)
                        }
                    }
                    dividerRow
                    sliderRow("Expanded width", value: $notchWidth, range: 360...720, format: { "\(Int($0))pt" }) {
                        DataStore.shared.set(key: .notchWidth, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    HStack {
                        Text("Notch height").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $notchHeightOption) {
                            Text("Match real notch").tag("Match real notch size")
                            Text("Match menubar").tag("Match menubar height")
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: notchHeightOption) { _, nv in
                            DataStore.shared.set(key: .notchHeightOption, value: nv)
                            notifySettings()
                        }
                    }
                    .padding(.vertical, 4)
                    dividerRow
                    toggleRow("Simulate notch on non-notch displays", value: $simulatedNotch) {
                        DataStore.shared.set(key: .simulatedNotch, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    sliderRow("Border width", value: $borderWidth, range: 0...2.5, format: { String(format: "%.1fpt", $0) }) {
                        DataStore.shared.set(key: .borderWidth, value: $0)
                        notifySettings()
                    }
                }

                settingsCard("Motion & layout") {
                    toggleRow("Settings icon in notch", value: $settingsIconInNotch) {
                        DataStore.shared.set(key: .settingsIconInNotch, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Window shadow when open", value: $windowShadow) {
                        DataStore.shared.set(key: .windowShadow, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Scale corners when expanding", value: $cornerRadiusScaling) {
                        DataStore.shared.set(key: .cornerRadiusScaling, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Simple close (no bounce)", value: $simpleCloseAnim) {
                        DataStore.shared.set(key: .simpleCloseAnim, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Disable spring overshoot", value: $disableOvershoot) {
                        DataStore.shared.set(key: .disableOvershoot, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Swipe up to close", value: $closeGesture) {
                        DataStore.shared.set(key: .closeGesture, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Duo mode (media + calendar)", value: $duoModeEnabled) {
                        DataStore.shared.set(key: .duoModeEnabled, value: $0)
                        notifySettings()
                    }
                    if duoModeEnabled {
                        dividerRow
                        sliderRow("Duo split", value: $duoModeSplit, range: 50...75, format: { "\(Int($0))/\(100 - Int($0))" }) {
                            DataStore.shared.set(key: .duoModeSplit, value: $0)
                            notifySettings()
                        }
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

                settingsCard("Connect players") {
                    appConnectionRow(
                        appName: "Spotify",
                        bundleID: "com.spotify.client",
                        isConnected: $spotifyConnected,
                        onToggle: { MediaTracker.shared.setSpotifyConnected($0) }
                    )
                    dividerRow
                    appConnectionRow(
                        appName: "Apple Music",
                        bundleID: "com.apple.Music",
                        isConnected: $appleMusicConnected,
                        onToggle: { MediaTracker.shared.setAppleMusicConnected($0) }
                    )
                    Text("Turn either (or both) on. Whatever is playing shows art, title, duration, and controls in the island.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
                }

                settingsCard("Now Playing") {
                    toggleRow("Show controls", value: $showMediaControls) {
                        DataStore.shared.set(key: .showMediaControls, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Show visualizer", value: $showVisualizer) {
                        DataStore.shared.set(key: .showVisualizer, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Colored spectrogram", value: $coloredSpectrograms) {
                        DataStore.shared.set(key: .coloredSpectrograms, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    HStack {
                        Text("Skip amount").foregroundColor(.white).font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $skipIncrement) {
                            Text("5s").tag("5s")
                            Text("10s").tag("10s")
                            Text("15s").tag("15s")
                            Text("30s").tag("30s")
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: skipIncrement) { _, nv in
                            DataStore.shared.set(key: .skipIncrement, value: nv)
                            notifySettings()
                        }
                    }
                    .padding(.vertical, 4)
                }

                settingsCard("Look") {
                    toggleRow("Tint from album art", value: $playerTinting) {
                        DataStore.shared.set(key: .playerTinting, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Blur behind album art", value: $blurBehindAlbum) {
                        DataStore.shared.set(key: .blurBehindAlbum, value: $0)
                        notifySettings()
                    }
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

                settingsCard("Shelf") {
                    toggleRow("Enable shelf", value: $shelfEnabled) {
                        DataStore.shared.set(key: .shelfEnabled, value: $0)
                    }
                    dividerRow
                    toggleRow("Remove after dragging out", value: $shelfAutoRemove) {
                        DataStore.shared.set(key: .shelfAutoRemove, value: $0)
                    }
                    Text("Drag files onto the notch — Shelf opens automatically so you can stage and move them between folders.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
                }

                settingsCard("Clipboard") {
                    toggleRow("Monitor clipboard", value: $clipboardEnabled) {
                        DataStore.shared.set(key: .clipboardEnabled, value: $0)
                    }
                    dividerRow
                    sliderRow("History size", value: $clipboardHistorySize, range: 10...100, format: { "\(Int($0)) items" }) {
                        DataStore.shared.set(key: .clipboardHistorySize, value: $0)
                    }
                    Text("Keeps text & images for 7 days. Pinned items stay forever until you unpin or delete them.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
                }

                settingsCard("Calendar") {
                    toggleRow("Hide all-day events", value: $hideAllDayEvents) {
                        DataStore.shared.set(key: .hideAllDayEvents, value: $0)
                    }
                    dividerRow
                    toggleRow("Truncate long titles", value: $calendarTitleTruncation) {
                        DataStore.shared.set(key: .calendarTitleTruncation, value: $0)
                    }
                    Text("Pulls the current week and events from the Mac Calendar app.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
                }

                settingsCard("Battery") {
                    toggleRow("Show in notch", value: $showBatteryInNotch) {
                        DataStore.shared.set(key: .showBatteryInNotch, value: $0)
                        notifySettings()
                    }
                    dividerRow
                    toggleRow("Show percentage", value: $showBatteryPercentage) {
                        DataStore.shared.set(key: .showBatteryPercentage, value: $0)
                        notifySettings()
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Timers & Widgets

    private var timerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerText("Timers & Widgets")

                settingsCard("Pomodoro loop") {
                    timerPickerRow("Focus", value: $focusDuration, options: [
                        (15, "15"), (20, "20"), (25, "25"), (30, "30"), (45, "45"), (50, "50"), (60, "60")
                    ]) {
                        DataStore.shared.set(key: .pomodoroFocusDuration, value: Double($0))
                    }
                    dividerRow
                    timerPickerRow("Short break", value: $shortBreakDuration, options: [
                        (3, "3"), (5, "5"), (10, "10")
                    ]) {
                        DataStore.shared.set(key: .pomodoroShortBreakDuration, value: Double($0))
                    }
                    dividerRow
                    timerPickerRow("Long break", value: $longBreakDuration, options: [
                        (10, "10"), (15, "15"), (20, "20"), (30, "30")
                    ]) {
                        DataStore.shared.set(key: .pomodoroLongBreakDuration, value: Double($0))
                    }
                    dividerRow
                    timerPickerRow("Cycles before long break", value: $cyclesBeforeLongBreak, options: [
                        (2, "2"), (3, "3"), (4, "4"), (5, "5")
                    ]) {
                        DataStore.shared.set(key: .pomodoroCyclesBeforeLongBreak, value: Double($0))
                    }
                    Text("Focus and breaks loop automatically. Click the timer digits to type a custom length.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
                }

                settingsCard("Floating widget defaults") {
                    opacitySliderRow("Opacity", value: $defaultOpacity) {
                        DataStore.shared.set(key: .defaultOpacity, value: $0)
                    }
                    dividerRow
                    opacitySliderRow("Blur", value: $defaultBlur) {
                        DataStore.shared.set(key: .defaultBlur, value: $0)
                    }
                    dividerRow
                    toggleRow("Pin above other windows", value: $defaultPin) {
                        DataStore.shared.set(key: .defaultPin, value: $0)
                    }
                    Text("Spawned widgets stay on top. Drag edges or corners to resize · gear for opacity/blur.")
                        .font(.system(size: 10))
                        .foregroundColor(settingsSecondaryText)
                        .padding(.top, 8)
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
                    headerText("About")
                    settingsCard(nil) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aura")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Menu bar command center + Dynamic Island for Mac — media, calendar, clipboard, shelf, and focus.")
                                .font(.system(size: 12))
                                .foregroundColor(settingsSecondaryText)
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 4)
                    }
                    settingsCard("Links") {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/anomalyco/Aura-mac-app")!)
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("GitHub")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(settingsSecondaryText)
                            }
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            HStack {
                Spacer()
                Text("Designed for MacBook")
                    .font(.system(size: 10))
                    .foregroundColor(settingsSecondaryText)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(settingsCardBG)
        }
    }

    // MARK: - Helpers

    private func notifySettings() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    private func headerText(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
        }
    }

    private func headerWithQuit(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Button("Quit app") { NSApp.terminate(nil) }
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).stroke(settingsBorder))
                .buttonStyle(.plain)
        }
    }

    private func settingsCard(_ title: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(settingsSecondaryText)
                    .textCase(.uppercase)
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

    private func toggleRow(_ label: String, value: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(label).foregroundColor(.white).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(settingsBlue)
                .onChange(of: value.wrappedValue) { _, nv in onChange(nv) }
        }
        .padding(.vertical, 4)
    }

    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(label).foregroundColor(.white).font(.system(size: 12))
            Spacer()
            Text(format(value.wrappedValue)).foregroundColor(settingsSecondaryText).font(.system(size: 11))
            Slider(value: value, in: range)
                .tint(settingsBlue)
                .controlSize(.small)
                .frame(width: 100)
                .onChange(of: value.wrappedValue) { _, nv in onChange(nv) }
        }
        .padding(.vertical, 4)
    }

    private func opacitySliderRow(_ label: String, value: Binding<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).foregroundColor(.white).font(.system(size: 12))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .foregroundColor(settingsSecondaryText)
                    .font(.system(size: 11, design: .monospaced))
            }
            Slider(value: value, in: 0.25...1.0)
                .tint(settingsBlue)
                .controlSize(.small)
                .onChange(of: value.wrappedValue) { _, nv in onChange(nv) }
        }
        .padding(.vertical, 4)
    }

    private func timerPickerRow(
        _ label: String,
        value: Binding<Int>,
        options: [(Int, String)],
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).foregroundColor(.white).font(.system(size: 12))
                Spacer()
            }
            Picker("", selection: value) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: value.wrappedValue) { _, nv in onChange(nv) }
        }
        .padding(.vertical, 4)
    }

    private func appConnectionRow(
        appName: String,
        bundleID: String,
        isConnected: Binding<Bool>,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: appName == "Spotify" ? "music.note.list" : "apple.logo")
                    .frame(width: 22, height: 22)
                    .foregroundColor(settingsSecondaryText)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(appName).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                Text(isConnected.wrappedValue ? "On" : "Off")
                    .font(.system(size: 9))
                    .foregroundColor(isConnected.wrappedValue ? .green : settingsSecondaryText)
            }
            Spacer()
            Toggle("", isOn: isConnected)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(settingsBlue)
                .labelsHidden()
                .onChange(of: isConnected.wrappedValue) { _, nv in onToggle(nv) }
        }
        .padding(.vertical, 4)
    }
}
