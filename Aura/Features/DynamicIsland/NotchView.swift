import SwiftUI
import IOKit.ps
import AVFoundation

struct NotchView: View {
    let viewModel: NotchViewModel
    @State private var hoveredControl: String?
    @State private var systemTimer: Timer?
    @State private var appSettings = AppSettingsManager.shared
    @State private var eventDays: Set<Int> = []
    @State private var eventItems: [CalendarEventItem] = []
    @State private var selectedEvent: CalendarEventItem?
    @State private var showDayDetail = false
    @State private var dayDetailDate = Date()
    @State private var dragOverShelf = false
    @State private var pomodoroModel = PomodoroViewModel()
    @State private var gestureOffset: CGFloat = 0

    private let calendar = Calendar.autoupdatingCurrent
    private let weekdaySymbols = Calendar.autoupdatingCurrent.shortWeekdaySymbols

    private var hasMusicContent: Bool {
        viewModel.hasMedia || !viewModel.lastTrackTitle.isEmpty
    }

    var body: some View {
        notchContent
            .frame(width: viewModel.currentFrame.width, height: viewModel.currentFrame.height)
            .animation(animationCurve, value: viewModel.state)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .onAppear {
                viewModel.updateSystemInfo()
                systemTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    Task { @MainActor in viewModel.updateSystemInfo() }
                }
                startClipboardMonitoring()
            }
            .onDisappear {
                systemTimer?.invalidate()
                viewModel.clearAlbumArtRetry()
            }
            .task {
                let granted = await CalendarService.shared.requestAccess()
                if granted {
                    eventDays = CalendarService.shared.hasEventsForWeek()
                    eventItems = CalendarService.shared.upcomingEvents()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nowPlayingDidChange)) { _ in
                if CalendarService.shared.authorized {
                    eventDays = CalendarService.shared.hasEventsForWeek()
                    eventItems = CalendarService.shared.upcomingEvents()
                }
            }
            .popover(item: $selectedEvent) { event in
                eventPopoverContent(event).frame(width: 220)
            }
            .popover(isPresented: $showDayDetail) {
                dayDetailPopoverContent(dayDetailDate).frame(width: 220)
            }
            .overlay(alignment: .top) {
                if viewModel.systemHUDType != nil {
                    systemHUDOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
    }

    private var animationCurve: Animation {
        if DataStore.shared.bool(for: .disableOvershoot, default: false) {
            .easeInOut(duration: 0.22)
        } else {
            AnimationCurves.notchExpand
        }
    }

    private var shadowColor: Color {
        appSettings.windowShadow ? .black.opacity(0.45) : .clear
    }

    private var shadowRadius: CGFloat { appSettings.windowShadow ? 14 : 0 }
    private var shadowY: CGFloat { appSettings.windowShadow ? 6 : 0 }

    // MARK: - System HUD Overlay

    private var systemHUDOverlay: some View {
        VStack(spacing: 0) {
            if let type = viewModel.systemHUDType {
                HStack(spacing: 8) {
                    Image(systemName: type == .volume ? "speaker.wave.2.fill" : "sun.max.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.12))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(viewModel.systemHUDProgress), height: 4)
                                .animation(.spring(response: 0.2), value: viewModel.systemHUDProgress)
                        }
                    }
                    .frame(height: 4)
                    Text(type == .volume ? "\(Int(viewModel.systemHUDVolume * 100))%" : "\(Int(viewModel.systemHUDBrightness * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32)
                }
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.systemHUDType)
            }
        }
    }

    // MARK: - Notch Container

    @ViewBuilder
    private var notchContent: some View {
        if appSettings.notchStyle == "pill" {
            innerContent
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(notchBorderOverlay(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
        } else {
            let s = UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 1, style: .continuous)
            innerContent
                .clipShape(s)
                .overlay(notchBorderOverlay(shape: s))
        }
    }

    @ViewBuilder
    private func notchBorderOverlay<S: InsettableShape>(shape: S) -> some View {
        if appSettings.settingsIconInNotch {
            shape.stroke(borderColor, lineWidth: borderWidth)
        }
    }

    private var borderColor: Color {
        let saved = DataStore.shared.string(for: .borderColor) ?? ""
        if saved.isEmpty { return .white.opacity(0.06) }
        return Color(hex: saved) ?? .white.opacity(0.06)
    }

    private var borderWidth: CGFloat {
        DataStore.shared.double(for: .borderWidth, default: 0.5)
    }

    private var innerContent: some View {
        ZStack(alignment: .top) {
            Color.black

            if viewModel.state == .expanded {
                VStack(spacing: 0) {
                    notchSpacer
                    ZStack {
                        materialOverlay
                        expandedContent
                    }
                    .frame(maxHeight: .infinity)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }

    private var notchSpacer: some View {
        Color.black
            .frame(height: max(notchHeight, 0))
    }

    private var notchHeight: CGFloat {
        viewModel.notchRect.height
    }

    @ViewBuilder
    private var materialOverlay: some View {
        let variant = DataStore.shared.string(for: .glassVariant) ?? "ios"
        // Alcove-inspired liquid glass: deep black + progressive blur
        LinearGradient(
            colors: [
                Color.black.opacity(0.92),
                Color.black.opacity(0.78)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        if variant == "clear" {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 0)
                .opacity(0.35)
        } else if variant == "ios" {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, cornerRadius: 0)
                .opacity(0.55)
            // Subtle album-art bleed when media is playing
            if DataStore.shared.bool(for: .playerTinting, default: true),
               let color = viewModel.dominantColors.first {
                Color(nsColor: color).opacity(0.12)
                    .blendMode(.plusLighter)
            }
        } else {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow, cornerRadius: 0)
                .opacity(0.42)
        }
    }

    // MARK: - Expanded Layout

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            topBar
            divider

            if viewModel.duoModeEnabled && hasMusicContent {
                duoModeContent
            } else {
                tabContent
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var duoModeContent: some View {
        let split = DataStore.shared.double(for: .duoModeSplit, default: 60)
        GeometryReader { geo in
            HStack(spacing: 6) {
                tabView(for: viewModel.duoLeftContent)
                    .frame(width: geo.size.width * CGFloat(split / 100) - 3)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )

                tabView(for: viewModel.duoRightContent)
                    .frame(width: geo.size.width * CGFloat((100 - split) / 100) - 3)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.duoModeEnabled)
    }

    @ViewBuilder
    private var tabContent: some View {
        VStack(spacing: 0) {
            if viewModel.availableTabs.count > 1 && DataStore.shared.bool(for: .showTabs, default: true) {
                tabBar
                divider
            }
            tabView(for: viewModel.activeTab)
                .id(viewModel.activeTab)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(AnimationCurves.hudSlide, value: viewModel.activeTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.availableTabs, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 20)
    }

    private func tabItem(_ tab: NotchViewModel.NotchTab) -> some View {
        let isActive = viewModel.activeTab == tab
        let isHovered = hoveredControl == "tab-\(tab.rawValue)"
        return Button {
            withAnimation(AnimationCurves.hudSlide) {
                viewModel.activeTab = tab
            }
            if DataStore.shared.bool(for: .rememberLastTab, default: false) {
                DataStore.shared.set(key: .lastActiveTab, value: tab.rawValue)
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .white : .white.opacity(isHovered ? 0.75 : 0.38))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isActive ? Color.white.opacity(0.14) : (isHovered ? Color.white.opacity(0.06) : .clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredControl = h ? "tab-\(tab.rawValue)" : nil }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Views

    @ViewBuilder
    private func tabView(for tab: NotchViewModel.NotchTab) -> some View {
        switch tab {
        case .media: musicSection
        case .calendar: calendarSection
        case .clipboard: clipboardView
        case .shelf: shelfView
        case .pomodoro: pomodoroView
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            if appSettings.settingsIconInNotch {
                responsiveIcon("gearshape", id: "settings", size: 11)
                    .onTapGesture { PanelManager.shared.openSettingsWindow() }
            }

            if viewModel.isDraggingToNotch {
                Label("Drop to Shelf", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            if appSettings.showBatteryInNotch && viewModel.batteryLevel > 0 {
                HStack(spacing: 3) {
                    Image(systemName: batteryIconName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(batteryColor)
                    if appSettings.showBatteryPercentage {
                        Text("\(Int(viewModel.batteryLevel * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
        .animation(AnimationCurves.hudSlide, value: viewModel.isDraggingToNotch)
    }

    private func responsiveIcon(_ systemName: String, id: String, size: CGFloat) -> some View {
        let isHovered = hoveredControl == id
        return Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(.white.opacity(isHovered ? 0.95 : 0.5))
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
            .onHover { h in hoveredControl = h ? id : (hoveredControl == id ? nil : hoveredControl) }
    }

    // MARK: - Music Section

    @ViewBuilder
    private var musicSection: some View {
        if viewModel.hasMedia {
            currentTrackView
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { val in
                            gestureOffset = val.translation.width
                        }
                        .onEnded { val in
                            let threshold: CGFloat = 50
                            if val.translation.width < -threshold {
                                viewModel.handleSwipeLeft()
                            } else if val.translation.width > threshold {
                                viewModel.handleSwipeRight()
                            }
                            gestureOffset = 0
                        }
                )
                .offset(x: gestureOffset)
                .animation(.interactiveSpring(), value: gestureOffset)
        } else if !viewModel.lastTrackTitle.isEmpty {
            lastTrackView
        } else {
            noMusicPlaceholder
        }
    }

    private var currentTrackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                albumArtView(icon: viewModel.displayArt)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.nowPlayingTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                    if !viewModel.sourceAppName.isEmpty {
                        Text(viewModel.sourceAppName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.28))
                    }
                }

                Spacer(minLength: 4)

                if viewModel.hasLossless || viewModel.hasDolbyAtmos {
                    VStack(alignment: .trailing, spacing: 2) {
                        if viewModel.hasLossless {
                            qualityBadge("Lossless", color: .orange)
                        }
                        if viewModel.hasDolbyAtmos {
                            qualityBadge("Dolby Atmos", color: .cyan)
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            if DataStore.shared.bool(for: .showVisualizer, default: false) && viewModel.isPlaying {
                spectrogramView
                    .frame(height: 16)
            } else {
                customProgressBar(value: viewModel.progress)
                HStack {
                    Text(viewModel.formattedElapsed)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.top, 3)
            }

            Spacer().frame(height: 8)

            if DataStore.shared.bool(for: .showMediaControls, default: true) {
                HStack(spacing: 18) {
                    responsiveButton("gobackward.10", id: "skipback", size: 11) {
                        MediaTracker.shared.skipBackward()
                    }
                    responsiveButton("backward.fill", id: "back", size: 12) {
                        viewModel.previousTrack()
                    }
                    responsiveButton(
                        viewModel.isPlaying ? "pause.fill" : "play.fill",
                        id: "playpause", size: 18, isPrimary: true
                    ) { viewModel.togglePlayPause() }
                    responsiveButton("forward.fill", id: "forward", size: 12) {
                        viewModel.nextTrack()
                    }
                    responsiveButton("goforward.10", id: "skipfwd", size: 11) {
                        MediaTracker.shared.skipForward()
                    }
                    Spacer()
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }

    private func qualityBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private var spectrogramView: some View {
        let colors = viewModel.dominantColors.isEmpty
            ? [Color.white, Color.blue, Color.purple]
            : viewModel.dominantColors.map { Color(nsColor: $0) }
        HStack(spacing: 2) {
            ForEach(0..<28, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[i % colors.count])
                    .frame(width: 3, height: CGFloat.random(in: 4...18))
                    .animation(.spring(response: 0.25).delay(Double(i) * 0.015), value: viewModel.isPlaying)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 4)
    }

    private var lastTrackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                albumArtView(icon: viewModel.lastTrackIcon)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.lastTrackTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.lastTrackArtist)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer().frame(height: 6)
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.25))
                Text("Last played")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var noMusicPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.15))
            Text("No music playing")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func albumArtView(icon: NSImage?) -> some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    DataStore.shared.bool(for: .blurBehindAlbum, default: true)
                        ? AnyView(RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5))
                        : AnyView(EmptyView())
                )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.08))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.2))
                )
        }
    }

    // MARK: - Buttons

    private func responsiveButton(_ icon: String, id: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredControl == id
        let colors = viewModel.dominantColors.map { Color(nsColor: $0) }
        let tint = DataStore.shared.bool(for: .playerTinting, default: true) && !colors.isEmpty ? colors[0] : Color.white
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .bold : .regular))
                .foregroundColor(isPrimary ? tint : .white.opacity(isHovered ? 0.9 : 0.45))
                .scaleEffect(isHovered ? (isPrimary ? 1.15 : 1.1) : 1.0)
                .shadow(color: isHovered && isPrimary ? tint.opacity(0.25) : .clear, radius: 4)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredControl = h ? id : (hoveredControl == id ? nil : hoveredControl) }
    }

    // MARK: - Clipboard View

    private var clipboardView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clipboard")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.clipboardHistory.count) · 7 days")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.3))
                Toggle("", isOn: Binding(
                    get: { DataStore.shared.bool(for: .clipboardEnabled, default: true) },
                    set: { DataStore.shared.set(key: .clipboardEnabled, value: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Spacer().frame(height: 4)

            if viewModel.clipboardHistory.isEmpty {
                Spacer()
                Text("No copied items")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 2) {
                        ForEach(viewModel.clipboardHistory.prefix(20)) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 7))
                                    .foregroundColor(item.isPinned ? .yellow : .white.opacity(0.2))
                                    .onTapGesture { viewModel.toggleClipboardPinned(item.id) }

                                if item.hasImage, let data = item.imageData, let img = NSImage(data: data) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 22, height: 22)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                Text(item.hasImage ? "Image" : item.text)
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(item.sourceApp)
                                    .font(.system(size: 6))
                                    .foregroundColor(.white.opacity(0.25))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.isPinned ? Color.yellow.opacity(0.07) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                if let data = item.imageData, let img = NSImage(data: data) {
                                    pb.writeObjects([img])
                                } else {
                                    pb.setString(item.text, forType: .string)
                                }
                            }
                            .contextMenu {
                                Button(item.isPinned ? "Unpin" : "Pin forever") {
                                    viewModel.toggleClipboardPinned(item.id)
                                }
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteClipboardItem(item.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Shelf View (Enhanced with drag-to-expand feedback)

    private var shelfView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Shelf")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if !viewModel.shelfItems.isEmpty {
                    Text("\(viewModel.shelfItems.count) item\(viewModel.shelfItems.count == 1 ? "" : "s")")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.3))
                    Image(systemName: "xmark")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.3))
                        .onTapGesture { viewModel.clearShelf() }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Spacer().frame(height: 4)

            if viewModel.shelfItems.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: dragOverShelf ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                        .font(.system(size: 14))
                        .foregroundColor(dragOverShelf ? .white : .white.opacity(0.15))
                        .scaleEffect(dragOverShelf ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2), value: dragOverShelf)
                    Text("Drag files here")
                        .font(.system(size: 8))
                        .foregroundColor(dragOverShelf ? .white.opacity(0.7) : .white.opacity(0.2))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(dragOverShelf ? Color.white.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: dragOverShelf ? [6, 3] : [4]))
                        .fill(dragOverShelf ? .white.opacity(0.4) : .white.opacity(0.08))
                        .animation(.spring(response: 0.2), value: dragOverShelf)
                )
                .padding(.horizontal, 6)
                .onDrop(of: [.fileURL], isTargeted: $dragOverShelf) { providers in
                    guard DataStore.shared.bool(for: .shelfEnabled, default: true) else { return false }
                    for provider in providers {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url { Task { @MainActor in viewModel.addShelfItem(url) } }
                        }
                    }
                    return true
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.shelfItems, id: \.self) { url in
                            shelfItemView(url)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onDrop(of: [.fileURL], isTargeted: $dragOverShelf) { providers in
                    guard DataStore.shared.bool(for: .shelfEnabled, default: true) else { return false }
                    for provider in providers {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url { Task { @MainActor in viewModel.addShelfItem(url) } }
                        }
                    }
                    return true
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func shelfItemView(_ url: URL) -> some View {
        VStack(spacing: 2) {
            if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            Text(url.lastPathComponent)
                .font(.system(size: 6))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .frame(width: 40)
            Image(systemName: "xmark")
                .font(.system(size: 5))
                .foregroundColor(.white.opacity(0.2))
                .onTapGesture { viewModel.removeShelfItem(url) }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))
        .onDrag {
            viewModel.dragOutShelfItem(url)
            return NSItemProvider(object: url as NSURL)
        }
    }

    // MARK: - Pomodoro View

    private var pomodoroView: some View {
        HStack(spacing: 0) {
            leftTimerColumn
            divider
                .padding(.vertical, 12)
            rightControlColumn
        }
        .overlay(alignment: .top) {
            pomodoroProgressBar
                .padding(.horizontal, 8)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pomodoroProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.06))
                    .frame(height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        pomodoroModel.state == .finished
                            ? Color.green.opacity(0.7)
                            : pomodoroPhaseColor(pomodoroModel.phase).opacity(0.7)
                    )
                    .frame(width: geo.size.width * CGFloat(pomodoroModel.progress), height: 2)
                    .animation(.linear(duration: 0.3), value: pomodoroModel.progress)
            }
        }
        .frame(height: 2)
    }

    private var leftTimerColumn: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: pomodoroModel.progress)
                    .stroke(
                        AngularGradient(
                            colors: [pomodoroPhaseColor(pomodoroModel.phase).opacity(0.4), pomodoroPhaseColor(pomodoroModel.phase)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: pomodoroModel.progress)

                VStack(spacing: 4) {
                    Text(pomodoroModel.formattedTime)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.15), value: pomodoroModel.timeRemaining)
                        .onTapGesture {
                            // Cycle common durations with a click; long sessions via Settings
                            let next = [15, 20, 25, 30, 45, 50, 60]
                            let current = max(1, Int(pomodoroModel.timeRemaining / 60))
                            let idx = next.firstIndex(of: current).map { ($0 + 1) % next.count } ?? 0
                            pomodoroModel.applyEditedMinutes(next[idx])
                            if pomodoroModel.state == .idle {
                                pomodoroModel.timeRemaining = pomodoroModel.totalTime
                            }
                        }
                        .help("Click to change duration")
                    HStack(spacing: 4) {
                        Image(systemName: pomodoroStateIcon)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(pomodoroStateColor)
                        Text(pomodoroModel.state.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(pomodoroStateColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pomodoroStateColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .frame(width: 96, height: 96)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var pomodoroStateIcon: String {
        switch pomodoroModel.state {
        case .idle: return "play"
        case .running: return "play.fill"
        case .paused: return "pause.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }

    private var pomodoroStateColor: Color {
        switch pomodoroModel.state {
        case .idle: return .white.opacity(0.4)
        case .running: return pomodoroPhaseColor(pomodoroModel.phase)
        case .paused: return .white.opacity(0.6)
        case .finished: return .green
        }
    }

    private var rightControlColumn: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                stepperRow(label: "Focus", dataStoreKey: .pomodoroFocusDuration, defaultMinutes: 25)
                stepperRow(label: "Break", dataStoreKey: .pomodoroShortBreakDuration, defaultMinutes: 5)
                stepperRow(label: "Long", dataStoreKey: .pomodoroLongBreakDuration, defaultMinutes: 15)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if pomodoroModel.state == .idle || pomodoroModel.state == .finished {
                    premiumPlayButton(action: { pomodoroModel.start() })
                } else {
                    premiumPlayButton(
                        icon: pomodoroModel.state == .running ? "pause.fill" : "play.fill",
                        action: { pomodoroModel.togglePause() }
                    )
                    resetIconButton(action: { pomodoroModel.reset() })
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepperRow(label: String, dataStoreKey: DataStore.SettingKey, defaultMinutes: Int) -> some View {
        let duration = DataStore.shared.double(for: dataStoreKey, default: Double(defaultMinutes))
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 32, alignment: .trailing)

            HStack(spacing: 0) {
                Button {
                    let current = DataStore.shared.double(for: dataStoreKey, default: Double(defaultMinutes))
                    let new = max(1, current - 1)
                    DataStore.shared.set(key: dataStoreKey, value: new)
                    if pomodoroModel.state == .idle {
                        pomodoroModel.switchToPhase(pomodoroModel.phase)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Text("\(Int(duration))m")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(minWidth: 30, alignment: .center)

                Button {
                    let current = DataStore.shared.double(for: dataStoreKey, default: Double(defaultMinutes))
                    let new = min(120, current + 1)
                    DataStore.shared.set(key: dataStoreKey, value: new)
                    if pomodoroModel.state == .idle {
                        pomodoroModel.switchToPhase(pomodoroModel.phase)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func premiumPlayButton(icon: String = "play.fill", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(pomodoroPhaseColor(pomodoroModel.phase).opacity(0.2))
                    .frame(width: 40, height: 40)
                Circle()
                    .stroke(pomodoroPhaseColor(pomodoroModel.phase).opacity(0.3), lineWidth: 1)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: icon == "play.fill" ? 1.5 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func resetIconButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }

    private func pomodoroPhaseColor(_ phase: PomodoroViewModel.Phase) -> Color {
        switch phase {
        case .focus: return .blue
        case .shortBreak: return .green
        case .longBreak: return .cyan
        }
    }

    // MARK: - Calendar Section

    private var now: Date { Date() }
    private var dayNumber: Int { calendar.component(.day, from: now) }
    private var monthName: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df.string(from: now)
    }
    private var yearNumber: Int { calendar.component(.year, from: now) }
    private var dayOfWeek: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df.string(from: now)
    }
    private var weekDayIndex: Int {
        (calendar.component(.weekday, from: now) - 1 + 7) % 7
    }
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: now)?.count ?? 30
    }
    private var firstWeekdayOfMonth: Int {
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let first = calendar.date(from: comps) else { return 0 }
        return (calendar.component(.weekday, from: first) - 1 + 7) % 7
    }

    private var showingUpcoming: Bool {
        viewModel.hasMedia || !viewModel.lastTrackTitle.isEmpty
    }

    @ViewBuilder
    private var calendarSection: some View {
        if showingUpcoming && appSettings.showMediaControls {
            upcomingCalendarView
        } else {
            fullWeekCalendarView
        }
    }

    private var upcomingCalendarView: some View {
        VStack(spacing: 0) {
            Text("\(monthName.prefix(3)) \(dayNumber)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 6)

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
                    let day = calendar.component(.day, from: date)
                    let weekday = weekdaySymbols[calendar.component(.weekday, from: date) - 1]
                    let isToday = offset == 0

                    VStack(spacing: 2) {
                        Text(String(weekday.prefix(2)))
                            .font(.system(size: 8, weight: isToday ? .bold : .regular))
                            .foregroundColor(.white.opacity(isToday ? 0.9 : 0.4))
                        Text("\(day)")
                            .font(.system(size: 12, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .black : .white.opacity(0.6))
                            .frame(width: 30, height: 24)
                            .background(isToday ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture { CalendarService.openCalendarApp() }
                }
            }

            Spacer().frame(height: 8)

            let filteredEvents = DataStore.shared.bool(for: .hideAllDayEvents, default: false)
                ? eventItems.filter { !$0.isAllDay }
                : eventItems
            let truncate = DataStore.shared.bool(for: .calendarTitleTruncation, default: true)

            if !filteredEvents.isEmpty {
                VStack(spacing: 3) {
                    ForEach(Array(filteredEvents.prefix(3).enumerated()), id: \.element.id) { _, item in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(item.calendarColor.map { Color(cgColor: $0) } ?? .red)
                                .frame(width: 6, height: 6)
                            Text(item.title)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(truncate ? 1 : 2)
                            Spacer(minLength: 0)
                            if !item.isAllDay {
                                Text(formatTime(item.startDate))
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEvent = item }
                    }
                }
            } else {
                Text("No Events")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .frame(maxHeight: .infinity, alignment: .top)
        .onTapGesture { CalendarService.openCalendarApp() }
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm"
        return df.string(from: date)
    }

    private var fullWeekCalendarView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(dayNumber)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(dayOfWeek.prefix(3))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
                Spacer()
                Text(monthName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer().frame(height: 10)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(String(weekdaySymbols[i].prefix(2)))
                        .font(.system(size: 8, weight: i == weekDayIndex ? .bold : .regular))
                        .foregroundColor(i == weekDayIndex ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer().frame(height: 6)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let day = i - firstWeekdayOfMonth + 1
                    if day > 0 && day <= daysInMonth {
                        VStack(spacing: 2) {
                            Text("\(day)")
                                .font(.system(size: 9, weight: day == dayNumber ? .bold : .regular))
                                .foregroundColor(day == dayNumber ? .black : .white.opacity(0.5))
                                .frame(width: 22, height: 20)
                                .background(day == dayNumber ? Color.white : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(alignment: .bottom) {
                                    if eventDays.contains(day) {
                                        Circle()
                                            .fill(.red.opacity(0.8))
                                            .frame(width: 3, height: 3)
                                            .offset(y: -1)
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let date = calendar.date(from: DateComponents(year: yearNumber, month: calendar.component(.month, from: now), day: day)) {
                                dayDetailDate = date
                                showDayDetail = true
                            }
                        }
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer().frame(height: 10)

            HStack(spacing: 4) {
                if !eventDays.isEmpty {
                    let todayHas = eventDays.contains(dayNumber)
                    if todayHas {
                        Circle().fill(.red).frame(width: 4, height: 4)
                        Text("Events today")
                            .font(.system(size: 9))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    Text("\(eventDays.count) day\(eventDays.count == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    Text("No Events")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxHeight: .infinity, alignment: .top)
        .onTapGesture { CalendarService.openCalendarApp() }
    }

    // MARK: - Camera Mirror Preview

    @ViewBuilder
    private var cameraMirrorView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Camera")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if viewModel.cameraActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Spacer()

            if viewModel.cameraActive {
                Text("Camera feed placeholder")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.15))
                    Text("Camera off")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.25))
                }
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private func customProgressBar(value: Double) -> some View {
        let isHovered = hoveredControl == "progress"
        let colors = viewModel.dominantColors.map { Color(nsColor: $0) }
        let tint = !colors.isEmpty && DataStore.shared.bool(for: .playerTinting, default: true) ? colors[0] : Color.white
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.1))
                    .frame(height: isHovered ? 5 : 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tint.opacity(isHovered ? 0.8 : 0.6))
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)), height: isHovered ? 5 : 3)
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .frame(height: 5)
        .onHover { h in hoveredControl = h ? "progress" : (hoveredControl == "progress" ? nil : hoveredControl) }
    }

    // MARK: - Event Popover

    @ViewBuilder
    private func eventPopoverContent(_ event: CalendarEventItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(event.calendarColor.map { Color(cgColor: $0) } ?? .gray)
                    .frame(width: 8, height: 8)
                Text(event.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
            }
            if !event.isAllDay {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            } else {
                Text("All Day").font(.system(size: 11)).foregroundColor(.secondary)
            }
            Text(event.startDate, style: .date).font(.system(size: 10)).foregroundColor(.secondary)
            Divider()
            Button("Open in Calendar") {
                selectedEvent = nil
                CalendarService.openCalendarApp()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
    }

    @ViewBuilder
    private func dayDetailPopoverContent(_ date: Date) -> some View {
        let events = CalendarService.shared.eventsForDay(date)
        VStack(alignment: .leading, spacing: 10) {
            Text(date, style: .date).font(.system(size: 12, weight: .semibold))
            if events.isEmpty {
                Text("No events").font(.system(size: 11)).foregroundColor(.secondary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(event.calendarColor.map { Color(cgColor: $0) } ?? .gray)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                            if !event.isAllDay {
                                Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                                    .font(.system(size: 9)).foregroundColor(.secondary)
                            } else {
                                Text("All Day").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Open Calendar") {
                showDayDetail = false
                CalendarService.openCalendarApp()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
    }

    // MARK: - Clipboard Monitoring

    private func startClipboardMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            Task { @MainActor in
                viewModel.pollClipboard()
            }
        }
    }

    // MARK: - Battery Helpers

    private var batteryIconName: String {
        if viewModel.batteryCharging { return "battery.100.bolt" }
        let pct = viewModel.batteryLevel
        if pct > 0.75 { return "battery.100" }
        if pct > 0.5 { return "battery.75" }
        if pct > 0.25 { return "battery.50" }
        if pct > 0.15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryColor: Color {
        let pct = viewModel.batteryLevel
        if viewModel.batteryCharging { return .green }
        if pct > 0.2 { return .white.opacity(0.6) }
        return .orange
    }
}
