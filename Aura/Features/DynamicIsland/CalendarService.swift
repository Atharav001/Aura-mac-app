import EventKit
import AppKit

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
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

    func hasEventsForWeek() -> Set<Int> {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let today = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        let predicate = store.predicateForEvents(withStart: weekStart, end: weekEnd, calendars: nil)
        let events = store.events(matching: predicate)

        var daysWithEvents = Set<Int>()
        for event in events {
            let day = cal.component(.day, from: event.startDate)
            daysWithEvents.insert(day)
        }
        return daysWithEvents
    }

    func upcomingEvents(for days: Int = 3) -> [CalendarEventItem] {
        guard authorized else { return [] }
        let cal = Calendar.autoupdatingCurrent
        let today = Date()
        guard let endDate = cal.date(byAdding: .day, value: days, to: today) else { return [] }

        let predicate = store.predicateForEvents(withStart: today, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.startDate >= today.addingTimeInterval(-3600) }

        return events
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { event in
                CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay
                )
            }
    }

    func fetchCalendars() -> [EKCalendar] {
        guard authorized else { return [] }
        return store.calendars(for: .event)
    }

    static func openCalendarApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.open(url)
    }
}
