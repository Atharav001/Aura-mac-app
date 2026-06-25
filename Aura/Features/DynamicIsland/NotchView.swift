import SwiftUI
import IOKit.ps

struct NotchView: View {
    let viewModel: NotchViewModel
    @State private var hoveredControl: String?
    @State private var systemTimer: Timer?
    @State private var appSettings = AppSettingsManager.shared
    @State private var eventDays: Set<Int> = []
    @State private var eventItems: [CalendarEventItem] = []

    private let calendar = Calendar.autoupdatingCurrent
    private let weekdaySymbols = Calendar.autoupdatingCurrent.shortWeekdaySymbols

    private var hasMusicContent: Bool {
        viewModel.hasMedia || !viewModel.lastTrackTitle.isEmpty
    }

    var body: some View {
        notchContent
            .frame(width: viewModel.currentFrame.width, height: viewModel.currentFrame.height)
            .animation(appSettings.simpleCloseAnim ? .easeInOut(duration: 0.25) : .spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0.3), value: viewModel.state)
            .shadow(color: appSettings.windowShadow ? .black.opacity(0.3) : .clear, radius: appSettings.windowShadow ? 8 : 0, x: 0, y: appSettings.windowShadow ? 4 : 0)
            .onAppear {
                viewModel.updateSystemInfo()
                systemTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    Task { @MainActor in
                        viewModel.updateSystemInfo()
                    }
                }
            }
            .onDisappear {
                systemTimer?.invalidate()
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
    }

    @ViewBuilder
    private var notchContent: some View {
        if appSettings.notchStyle == "pill" {
            innerContent
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
        } else {
            let s = UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 2, style: .continuous)
            innerContent
                .clipShape(s)
                .overlay(s.stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    private var innerContent: some View {
        ZStack {
            // Always pitch black to blend with the camera notch cutout
            Color.black

            Group {
                if viewModel.state == .expanded {
                    expandedContent
                }
            }
            .opacity(viewModel.state == .collapsed ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }

    // MARK: - Boring Notch Dashboard

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.15)

            if hasMusicContent && appSettings.showMediaControls {
                HStack(spacing: 0) {
                    musicSection
                        .frame(maxWidth: .infinity)
                    Divider().opacity(0.15)
                    calendarSection
                        .frame(maxWidth: .infinity)
                }
            } else {
                calendarSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 14) {
            topBarButton(icon: "house", id: "home")
            topBarButton(icon: "tray", id: "inbox")
            if appSettings.settingsIconInNotch {
                topBarButton(icon: "gearshape", id: "settings")
            }

            Spacer()

            if appSettings.showBatteryInNotch && viewModel.batteryLevel > 0 {
                HStack(spacing: 4) {
                    Image(systemName: batteryIconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(batteryColor)
                    if appSettings.showBatteryPercentage {
                        Text("\(Int(viewModel.batteryLevel * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private func topBarButton(icon: String, id: String) -> some View {
        let isHovered = hoveredControl == id
        return Button {
            if id == "settings" {
                PanelManager.shared.openSettingsWindow()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.55))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredControl = hovering ? id : nil
        }
    }

    // MARK: - Music Section

    @ViewBuilder
    private var musicSection: some View {
        if viewModel.hasMedia {
            currentTrackView
        } else if !viewModel.lastTrackTitle.isEmpty {
            lastTrackView
        } else {
            noMusicPlaceholder
        }
    }

    private var currentTrackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                albumArtView(icon: viewModel.displayArt, source: viewModel.mediaSource)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.nowPlayingTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer().frame(height: 8)

            customProgressBar(value: viewModel.progress, width: nil)

            Spacer().frame(height: 8)

            HStack(spacing: 16) {
                transportButton(icon: "backward.fill", id: "back", size: 10)
                transportButton(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", id: "playpause", size: 14, isPrimary: true)
                transportButton(icon: "forward.fill", id: "forward", size: 10)
                Spacer()
                sourceAppLabel(viewModel.sourceAppName)
            }
        }
        .padding(12)
    }

    private var lastTrackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                albumArtView(icon: viewModel.lastTrackIcon, source: viewModel.lastTrackSource)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.lastTrackTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.lastTrackArtist)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer().frame(height: 8)

            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.3))
                Text("Last played")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
        }
        .padding(12)
    }

    private var noMusicPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.2))
            Text("No music playing")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func albumArtView(icon: NSImage?, source: NotchViewModel.MediaSource) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }

            if source.bundleID == "com.spotify.client" {
                Circle()
                    .fill(Color(red: 0.13, green: 0.78, blue: 0.33))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 4, weight: .black))
                            .foregroundColor(.white)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func sourceAppLabel(_ name: String) -> some View {
        if !name.isEmpty {
            Text(name)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.25))
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
        let idx = calendar.component(.weekday, from: now) - 1
        return idx
    }
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: now)?.count ?? 30
    }
    private var firstWeekdayOfMonth: Int {
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let first = calendar.date(from: comps) else { return 0 }
        return calendar.component(.weekday, from: first) - 1
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

    // Three-day calendar (today, tomorrow, day after) with event titles
    private var upcomingCalendarView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(dayNumber)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(dayOfWeek.prefix(3))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }

            Text("\(monthName) \(yearNumber)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.35))

            Spacer().frame(height: 2)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
                    let day = calendar.component(.day, from: date)
                    let weekday = weekdaySymbols[calendar.component(.weekday, from: date) - 1]
                    let isToday = offset == 0

                    VStack(spacing: 2) {
                        Text(String(weekday.prefix(3)))
                            .font(.system(size: 7, weight: isToday ? .semibold : .regular))
                            .foregroundColor(.white.opacity(isToday ? 0.9 : 0.3))
                        Text("\(day)")
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .black : .white.opacity(0.6))
                            .frame(width: 28, height: 22)
                            .background(isToday ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(alignment: .bottom) {
                                if eventDays.contains(day) {
                                    Circle()
                                        .fill(Color.red.opacity(0.8))
                                        .frame(width: 3, height: 3)
                                        .offset(y: 1)
                                }
                            }
                    }
                    .frame(width: 38)
                    .onTapGesture {
                        CalendarService.openCalendarApp()
                    }
                }
            }

            // Upcoming event titles
            if !eventItems.isEmpty {
                VStack(spacing: 2) {
                    ForEach(eventItems.prefix(3)) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red.opacity(0.8))
                                .frame(width: 4, height: 4)
                            Text(item.title)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            if !item.isAllDay {
                                Text(formatTime(item.startDate))
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.top, 2)
            } else {
                HStack(spacing: 4) {
                    Text("No Events Today")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.top, 2)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .onTapGesture {
            CalendarService.openCalendarApp()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: date)
    }

    // Full week calendar when no music is showing
    private var fullWeekCalendarView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(dayNumber)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(dayOfWeek.prefix(3))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }

            Text("\(monthName) \(yearNumber)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.35))

            Spacer().frame(height: 2)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(String(weekdaySymbols[i].prefix(2)))
                        .font(.system(size: 7, weight: i == weekDayIndex ? .semibold : .regular))
                        .foregroundColor(i == weekDayIndex ? .white : .white.opacity(0.3))
                        .frame(width: 16)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let day = i - firstWeekdayOfMonth + 1
                    if day > 0 && day <= daysInMonth {
                        VStack(spacing: 1) {
                            Text("\(day)")
                                .font(.system(size: 7, weight: day == dayNumber ? .bold : .regular))
                                .foregroundColor(day == dayNumber ? .black : .white.opacity(0.45))
                                .frame(width: 16, height: 16)
                                .background(day == dayNumber ? Color.white : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .onTapGesture {
                                    CalendarService.openCalendarApp()
                                }

                            if eventDays.contains(day) {
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 3, height: 3)
                            }
                        }
                        .frame(width: 16)
                        .onHover { hovering in
                            if hovering {
                                hoveredControl = "cal-\(day)"
                            } else if hoveredControl == "cal-\(day)" {
                                hoveredControl = nil
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(width: 16, height: 16)
                    }
                }
            }

            HStack(spacing: 4) {
                if !eventDays.isEmpty {
                    let todayEvents = eventDays.contains(dayNumber)
                    if todayEvents {
                        Text("Events today")
                            .font(.system(size: 8))
                            .foregroundColor(.red.opacity(0.7))
                        Circle()
                            .fill(.red.opacity(0.8))
                            .frame(width: 4, height: 4)
                    }
                    Text("\(eventDays.count) day\(eventDays.count == 1 ? "" : "s") with events this week")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.25))
                } else {
                    Text("No Events Today")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .padding(.top, 2)
            .onTapGesture {
                CalendarService.openCalendarApp()
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
    }

    // MARK: - Custom Progress Bar

    @ViewBuilder
    private func customProgressBar(value: Double, width: CGFloat?) -> some View {
        GeometryReader { geo in
            let w = width ?? geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.12))
                    .frame(width: w, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.65))
                    .frame(width: w * CGFloat(min(max(value, 0), 1)), height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Transport Controls

    private func transportButton(icon: String, id: String, size: CGFloat, isPrimary: Bool = false) -> some View {
        let isHovered = hoveredControl == id
        return Button {
            if id == "playpause" {
                viewModel.togglePlayPause()
            } else if id == "back" {
                viewModel.previousTrack()
            } else if id == "forward" {
                viewModel.nextTrack()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .semibold : .regular))
                .foregroundColor(isPrimary ? .white : .white.opacity(isHovered ? 0.8 : 0.45))
                .scaleEffect(isHovered && isPrimary ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredControl = hovering ? id : nil
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
        if pct > 0.2 { return .white.opacity(0.7) }
        return .orange
    }
}
