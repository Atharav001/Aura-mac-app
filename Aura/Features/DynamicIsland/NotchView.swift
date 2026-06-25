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
            .animation(appSettings.simpleCloseAnim ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2), value: viewModel.state)
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
    }

    @ViewBuilder
    private var notchContent: some View {
        if appSettings.notchStyle == "pill" {
            innerContent
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 0.5))
        } else {
            let s = UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 1, style: .continuous)
            innerContent
                .clipShape(s)
                .overlay(s.stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var innerContent: some View {
        ZStack {
            Color.black

            if viewModel.state == .expanded {
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    .opacity(0.45)
                    .transition(.opacity)

                expandedContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }

    // MARK: - Dashboard

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            topBar
            divider

            if hasMusicContent && appSettings.showMediaControls {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        musicSection
                            .frame(width: geo.size.width * 0.55)
                            .frame(maxHeight: .infinity)
                        divider
                        calendarSection
                            .frame(width: geo.size.width * 0.45)
                            .frame(maxHeight: .infinity)
                    }
                }
            } else {
                calendarSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            responsiveIcon("house", id: "home", size: 11)
            responsiveIcon("tray", id: "inbox", size: 11)
            if appSettings.settingsIconInNotch {
                responsiveIcon("gearshape", id: "settings", size: 11)
                    .onTapGesture {
                        PanelManager.shared.openSettingsWindow()
                    }
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
        } else if !viewModel.lastTrackTitle.isEmpty {
            lastTrackView
        } else {
            noMusicPlaceholder
        }
    }

    private var currentTrackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                albumArtView(icon: viewModel.displayArt)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.nowPlayingTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer().frame(height: 6)

            customProgressBar(value: viewModel.progress)

            Spacer().frame(height: 6)

            HStack(spacing: 14) {
                responsiveButton("backward.fill", id: "back", size: 11) {
                    viewModel.previousTrack()
                }
                responsiveButton(
                    viewModel.isPlaying ? "pause.fill" : "play.fill",
                    id: "playpause",
                    size: 16,
                    isPrimary: true
                ) {
                    viewModel.togglePlayPause()
                }
                responsiveButton("forward.fill", id: "forward", size: 11) {
                    viewModel.nextTrack()
                }
                Spacer()
                if !viewModel.sourceAppName.isEmpty {
                    Text(viewModel.sourceAppName)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.25))
                        .lineLimit(1)
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .frame(maxHeight: .infinity, alignment: .top)
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

    // MARK: - Responsive Buttons

    private func responsiveButton(_ icon: String, id: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredControl == id
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .bold : .regular))
                .foregroundColor(isPrimary ? .white : .white.opacity(isHovered ? 0.9 : 0.45))
                .scaleEffect(isHovered ? (isPrimary ? 1.15 : 1.1) : 1.0)
                .shadow(color: isHovered && isPrimary ? .white.opacity(0.25) : .clear, radius: 4)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredControl = h ? id : (hoveredControl == id ? nil : hoveredControl) }
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

    // MARK: - Upcoming 3-Day Calendar

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

            if !eventItems.isEmpty {
                VStack(spacing: 3) {
                    ForEach(Array(eventItems.prefix(3).enumerated()), id: \.element.id) { _, item in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(item.calendarColor.map { Color(cgColor: $0) } ?? .red)
                                .frame(width: 6, height: 6)
                            Text(item.title)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if !item.isAllDay {
                                Text(formatTime(item.startDate))
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
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

    // MARK: - Full Week Calendar
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
                        .onTapGesture { CalendarService.openCalendarApp() }
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
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

    // MARK: - Progress Bar

    @ViewBuilder
    private func customProgressBar(value: Double) -> some View {
        let isHovered = hoveredControl == "progress"
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.1))
                    .frame(height: isHovered ? 5 : 3)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(isHovered ? 0.8 : 0.6))
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)), height: isHovered ? 5 : 3)
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .frame(height: 5)
        .onHover { h in hoveredControl = h ? "progress" : (hoveredControl == "progress" ? nil : hoveredControl) }
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
