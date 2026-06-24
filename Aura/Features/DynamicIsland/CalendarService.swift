import EventKit
import AppKit

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

    static func openCalendarApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.open(url)
    }
}
