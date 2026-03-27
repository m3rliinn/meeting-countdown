#if canImport(XCTest)
import Foundation
import XCTest
@testable import MeetingCountdownCore

final class MeetingCountdownCoreTests: XCTestCase {
    func testExtractsMeetLinkFromEventURL() {
        let url = URL(string: "https://meet.google.com/abc-defg-hij?authuser=0")!
        XCTAssertEqual(MeetLinkExtractor.extract(eventURL: url, notes: nil), url)
    }

    func testExtractsMeetLinkFromNotes() {
        let notes = """
        Agenda:
        https://meet.google.com/abc-defg-hij
        """

        XCTAssertEqual(
            MeetLinkExtractor.extract(eventURL: nil, notes: notes),
            URL(string: "https://meet.google.com/abc-defg-hij")
        )
    }

    func testCandidateFinderIgnoresAllDayDeclinedAndNonMeetEvents() {
        let configuration = AppConfiguration()
        let finder = MeetingCandidateFinder(eventStore: .init())
        let baseDate = Date(timeIntervalSince1970: 1_000_000)

        let snapshots = [
            EventSnapshot(
                title: "All day",
                startDate: baseDate,
                endDate: baseDate.addingTimeInterval(3600),
                isAllDay: true,
                status: .accepted,
                calendarTitle: "Work",
                eventURL: URL(string: "https://meet.google.com/a"),
                notes: nil,
                occurrenceID: "1"
            ),
            EventSnapshot(
                title: "Declined",
                startDate: baseDate,
                endDate: baseDate.addingTimeInterval(3600),
                isAllDay: false,
                status: .declined,
                calendarTitle: "Work",
                eventURL: URL(string: "https://meet.google.com/b"),
                notes: nil,
                occurrenceID: "2"
            ),
            EventSnapshot(
                title: "Zoom",
                startDate: baseDate,
                endDate: baseDate.addingTimeInterval(3600),
                isAllDay: false,
                status: .accepted,
                calendarTitle: "Work",
                eventURL: URL(string: "https://zoom.us/j/123"),
                notes: nil,
                occurrenceID: "3"
            ),
            EventSnapshot(
                title: "Meet",
                startDate: baseDate,
                endDate: baseDate.addingTimeInterval(3600),
                isAllDay: false,
                status: .accepted,
                calendarTitle: "Work",
                eventURL: nil,
                notes: "Join here https://meet.google.com/abc-defg-hij",
                occurrenceID: "4"
            ),
        ]

        let meetings = finder.upcomingEligibleMeetings(from: snapshots, configuration: configuration)
        XCTAssertEqual(meetings.map(\.title), ["Meet"])
    }

    func testPlannerWaitsAtTMinusEleven() {
        let meeting = makeMeeting(startOffset: 11)
        let config = AppConfiguration(leadTimeSeconds: 10, lateGraceSeconds: 60)
        let now = Date()

        let decision = TriggerPlanner.decide(
            meetings: [meeting],
            state: AppState(),
            configuration: config,
            now: now
        )

        guard case .wait(let scheduledMeeting, let fireDate) = decision else {
            return XCTFail("Expected wait decision")
        }
        XCTAssertEqual(scheduledMeeting.occurrenceID, meeting.occurrenceID)
        XCTAssertEqual(fireDate.timeIntervalSince1970, meeting.startDate.addingTimeInterval(-10).timeIntervalSince1970, accuracy: 0.001)
    }

    func testPlannerFiresAtTMinusTen() {
        let meeting = makeMeeting(startOffset: 10)
        let config = AppConfiguration(leadTimeSeconds: 10, lateGraceSeconds: 60)

        let decision = TriggerPlanner.decide(
            meetings: [meeting],
            state: AppState(),
            configuration: config,
            now: Date()
        )

        XCTAssertEqual(decision, .fireNow(meeting: meeting))
    }

    func testPlannerFiresAtTMinusOneAndTPlusOne() {
        let config = AppConfiguration(leadTimeSeconds: 10, lateGraceSeconds: 60)
        let minusOneMeeting = makeMeeting(startOffset: 1, id: "minus-one")
        let plusOneMeeting = makeMeeting(startOffset: -1, id: "plus-one")

        let minusOneDecision = TriggerPlanner.decide(
            meetings: [minusOneMeeting],
            state: AppState(),
            configuration: config,
            now: Date()
        )

        let plusOneDecision = TriggerPlanner.decide(
            meetings: [plusOneMeeting],
            state: AppState(),
            configuration: config,
            now: Date()
        )

        XCTAssertEqual(minusOneDecision, .fireNow(meeting: minusOneMeeting))
        XCTAssertEqual(plusOneDecision, .fireNow(meeting: plusOneMeeting))
    }

    func testPlannerSkipsAlreadyTriggeredOccurrenceAndUsesNextRecurringInstance() {
        let config = AppConfiguration(leadTimeSeconds: 10, lateGraceSeconds: 60)
        let first = makeMeeting(startOffset: 10, id: "series|1")
        let second = makeMeeting(startOffset: 3_600, id: "series|2")
        let state = AppState(lastTriggeredOccurrenceID: "series|1", isPaused: false)

        let decision = TriggerPlanner.decide(
            meetings: [first, second],
            state: state,
            configuration: config,
            now: Date()
        )

        guard case .wait(let meeting, _) = decision else {
            return XCTFail("Expected second recurrence to be scheduled")
        }
        XCTAssertEqual(meeting.occurrenceID, "series|2")
    }

    func testPlannerReturnsNoMeetingAfterGraceWindow() {
        let config = AppConfiguration(leadTimeSeconds: 10, lateGraceSeconds: 60)
        let meeting = makeMeeting(startOffset: -61)

        let decision = TriggerPlanner.decide(
            meetings: [meeting],
            state: AppState(),
            configuration: config,
            now: Date()
        )

        XCTAssertEqual(decision, .noMeeting)
    }

    private func makeMeeting(startOffset: TimeInterval, id: String = UUID().uuidString) -> MeetingCandidate {
        let now = Date()
        return MeetingCandidate(
            title: "Standup",
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(startOffset + 1_800),
            meetURL: URL(string: "https://meet.google.com/abc-defg-hij")!,
            calendarTitle: "Work",
            occurrenceID: id
        )
    }
}
#endif
