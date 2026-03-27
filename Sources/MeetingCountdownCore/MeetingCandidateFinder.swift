import EventKit
import Foundation

public final class MeetingCandidateFinder {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    public func upcomingEligibleMeetings(
        configuration: AppConfiguration,
        now: Date = Date(),
        horizon: TimeInterval = 24 * 60 * 60
    ) -> [MeetingCandidate] {
        let calendars = eligibleCalendars(named: configuration.eligibleCalendarNames)
        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-TimeInterval(configuration.leadTimeSeconds)),
            end: now.addingTimeInterval(horizon),
            calendars: calendars
        )

        let events = eventStore.events(matching: predicate)
        let snapshots = events.map(EventSnapshot.init(event:))
        return upcomingEligibleMeetings(from: snapshots, configuration: configuration)
    }

    public func upcomingEligibleMeetings(
        from snapshots: [EventSnapshot],
        configuration: AppConfiguration
    ) -> [MeetingCandidate] {
        snapshots
            .filter { snapshot in
                if snapshot.isAllDay {
                    return false
                }
                if snapshot.status == .declined {
                    return false
                }
                if !configuration.eligibleCalendarNames.isEmpty &&
                    !configuration.eligibleCalendarNames.contains(snapshot.calendarTitle) {
                    return false
                }
                return MeetLinkExtractor.extract(eventURL: snapshot.eventURL, notes: snapshot.notes) != nil
            }
            .compactMap { snapshot in
                guard let meetURL = MeetLinkExtractor.extract(eventURL: snapshot.eventURL, notes: snapshot.notes) else {
                    return nil
                }

                return MeetingCandidate(
                    title: snapshot.title,
                    startDate: snapshot.startDate,
                    endDate: snapshot.endDate,
                    meetURL: meetURL,
                    calendarTitle: snapshot.calendarTitle,
                    occurrenceID: snapshot.occurrenceID
                )
            }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private func eligibleCalendars(named names: [String]) -> [EKCalendar]? {
        let calendars = eventStore.calendars(for: .event)
        guard !names.isEmpty else {
            return calendars
        }
        let nameSet = Set(names)
        return calendars.filter { nameSet.contains($0.title) }
    }
}
