import EventKit
import Foundation

public enum MeetingParticipationStatus: String, Codable, Equatable, Sendable {
    case accepted
    case tentative
    case pending
    case declined
    case unknown
}

public struct EventSnapshot: Equatable, Sendable {
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var status: MeetingParticipationStatus
    public var calendarTitle: String
    public var eventURL: URL?
    public var notes: String?
    public var occurrenceID: String

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        status: MeetingParticipationStatus,
        calendarTitle: String,
        eventURL: URL?,
        notes: String?,
        occurrenceID: String
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.status = status
        self.calendarTitle = calendarTitle
        self.eventURL = eventURL
        self.notes = notes
        self.occurrenceID = occurrenceID
    }
}

public struct MeetingCandidate: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let meetURL: URL
    public let calendarTitle: String
    public let occurrenceID: String

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        meetURL: URL,
        calendarTitle: String,
        occurrenceID: String
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.meetURL = meetURL
        self.calendarTitle = calendarTitle
        self.occurrenceID = occurrenceID
    }
}

extension EventSnapshot {
    init(event: EKEvent) {
        self.init(
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? event.title! : "Untitled Meeting",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            status: Self.currentUserStatus(for: event),
            calendarTitle: event.calendar.title,
            eventURL: event.url,
            notes: event.notes,
            occurrenceID: Self.occurrenceID(for: event)
        )
    }

    private static func currentUserStatus(for event: EKEvent) -> MeetingParticipationStatus {
        if let attendees = event.attendees,
           let currentUser = attendees.first(where: { $0.isCurrentUser })
        {
            switch currentUser.participantStatus {
            case .accepted:
                return .accepted
            case .tentative:
                return .tentative
            case .pending:
                return .pending
            case .declined:
                return .declined
            default:
                return .unknown
            }
        }

        if event.status == .canceled {
            return .declined
        }

        return .unknown
    }

    private static func occurrenceID(for event: EKEvent) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startComponent = formatter.string(from: event.startDate)
        return "\(event.calendarItemIdentifier)|\(startComponent)"
    }
}
