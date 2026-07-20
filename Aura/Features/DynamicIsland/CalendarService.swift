import EventKit
import AppKit

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: CGColor?
    let calendarName: String

    static func == (lhs: CalendarEventItem, rhs: CalendarEventItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private(set) var authorized = false

    private init() {}

    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            let result = try? await store.requestFullAccessToEvents()
            authorized = result == true
        } else {
            let result = try? await store.requestAccess(to: .event)
            authorized = result == true
        }
        return authorized
    }

    /// All calendars the user has enabled in Calendar.app
    func fetchCalendars() -> [EKCalendar] {
        guard authorized else { return [] }
        return store.calendars(for: .event)
    }

    func hasEventsForWeek() -> Set<Int> {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let today = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        let predicate = store.predicateForEvents(withStart: weekStart, end: weekEnd, calendars: nil)
        var days = Set<Int>()
        for event in store.events(matching: predicate) {
            days.insert(cal.component(.day, from: event.startDate))
        }
        return days
    }

    /// Upcoming events across every calendar (scrollable — no tiny prefix cap)
    func upcomingEvents(for days: Int = 14) -> [CalendarEventItem] {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: days, to: start) else { return [] }
        return events(from: start, to: end)
    }

    func eventsForDay(_ date: Date) -> [CalendarEventItem] {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events(from: dayStart, to: dayEnd)
    }

    func eventsForWeek(containing date: Date = Date()) -> [CalendarEventItem] {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let weekday = cal.component(.weekday, from: date)
        guard let weekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: date)),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        return events(from: weekStart, to: weekEnd)
    }

    private func events(from start: Date, to end: Date) -> [CalendarEventItem] {
        // calendars: nil → every calendar in Calendar.app
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let hideAllDay = DataStore.shared.bool(for: .hideAllDayEvents, default: false)
        return store.events(matching: predicate)
            .filter { !hideAllDay || !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarColor: event.calendar.cgColor,
                    calendarName: event.calendar.title
                )
            }
    }

    static func openCalendarApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.open(url)
    }
}
