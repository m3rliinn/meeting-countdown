import Foundation

public enum TriggerDecision: Equatable, Sendable {
    case noMeeting
    case wait(meeting: MeetingCandidate, fireDate: Date)
    case fireNow(meeting: MeetingCandidate)
}

public enum TriggerPlanner {
    public static func decide(
        meetings: [MeetingCandidate],
        state: AppState,
        configuration: AppConfiguration,
        now: Date = Date()
    ) -> TriggerDecision {
        guard !state.isPaused else {
            return .noMeeting
        }

        for meeting in meetings {
            if state.lastTriggeredOccurrenceID == meeting.occurrenceID {
                continue
            }

            let fireDate = meeting.startDate.addingTimeInterval(TimeInterval(-configuration.leadTimeSeconds))
            let lateCutoff = meeting.startDate.addingTimeInterval(TimeInterval(configuration.lateGraceSeconds))

            if now < fireDate {
                return .wait(meeting: meeting, fireDate: fireDate)
            }

            if now <= lateCutoff {
                return .fireNow(meeting: meeting)
            }
        }

        return .noMeeting
    }

    public static func countdownSeconds(
        until meeting: MeetingCandidate,
        leadTimeSeconds: Int,
        now: Date = Date()
    ) -> Int {
        let remaining = Int(ceil(meeting.startDate.timeIntervalSince(now)))
        return min(leadTimeSeconds, max(1, remaining))
    }
}
