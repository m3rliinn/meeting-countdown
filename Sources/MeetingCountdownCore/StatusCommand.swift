import Foundation

public struct StatusCommand {
    public init() {}

    public func execute() throws {
        let configurationStore = ConfigurationStore()
        let stateStore = StateStore()
        let accessManager = CalendarAccessManager()
        let configuration = try configurationStore.loadOrCreateDefault()
        let state = try stateStore.load()

        print("Config")
        print("  leadTimeSeconds: \(configuration.leadTimeSeconds)")
        print("  eligibleCalendarNames: \(configuration.eligibleCalendarNames.isEmpty ? "all" : configuration.eligibleCalendarNames.joined(separator: ", "))")
        print("  chromeBundleID: \(configuration.chromeBundleID)")
        print("  openInForeground: \(configuration.openInForeground)")
        print("  soundEnabled: \(configuration.soundEnabled)")
        print("  soundVolume: \(configuration.soundVolume)")
        print("  lateGraceSeconds: \(configuration.lateGraceSeconds)")
        print("  paused: \(state.isPaused)")

        guard accessManager.hasReadableAccess() else {
            print("")
            print("Calendar access: missing")
            return
        }

        let finder = MeetingCandidateFinder(eventStore: accessManager.eventStore)
        let meetings = finder.upcomingEligibleMeetings(configuration: configuration)
        let nextMeeting = meetings.first(where: { $0.occurrenceID != state.lastTriggeredOccurrenceID }) ?? meetings.first

        print("")
        if let nextMeeting {
            print("Next eligible meeting")
            print("  title: \(nextMeeting.title)")
            print("  start: \(Formatters.consoleDateTimeString(from: nextMeeting.startDate))")
            print("  meetURL: \(nextMeeting.meetURL.absoluteString)")
            print("  calendar: \(nextMeeting.calendarTitle)")
        } else {
            print("Next eligible meeting")
            print("  none found")
        }
    }
}
