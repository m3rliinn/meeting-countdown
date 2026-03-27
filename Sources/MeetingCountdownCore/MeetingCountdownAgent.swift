import AppKit
import EventKit
import Foundation

@MainActor
public final class MeetingCountdownAgent: NSObject {
    public var onStatusChanged: ((AgentStatus) -> Void)?

    private let logger: AppLogger
    private let configurationStore: ConfigurationStore
    private let stateStore: StateStore
    private let accessManager: CalendarAccessManager
    private let candidateFinder: MeetingCandidateFinder
    private let browserOpener: BrowserOpener
    private let notificationManager: NotificationManager
    private let overlayController: CountdownOverlayController
    private let audioPlayer: CountdownAudioPlayer?

    private var configuration: AppConfiguration
    private var state: AppState
    private var fireTimer: Timer?
    private var nextMeeting: MeetingCandidate?
    private var eventStoreChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    public init(
        logger: AppLogger,
        configurationStore: ConfigurationStore = ConfigurationStore(),
        stateStore: StateStore = StateStore(),
        accessManager: CalendarAccessManager = CalendarAccessManager(),
        browserOpener: BrowserOpener = BrowserOpener(),
        notificationManager: NotificationManager = NotificationManager(),
        overlayController: CountdownOverlayController = CountdownOverlayController()
    ) {
        self.logger = logger
        self.configurationStore = configurationStore
        self.stateStore = stateStore
        self.accessManager = accessManager
        self.candidateFinder = MeetingCandidateFinder(eventStore: accessManager.eventStore)
        self.browserOpener = browserOpener
        self.notificationManager = notificationManager
        self.overlayController = overlayController
        self.configuration = (try? configurationStore.loadOrCreateDefault()) ?? AppConfiguration()
        self.state = (try? stateStore.load()) ?? AppState()
        self.audioPlayer = try? CountdownAudioPlayer()
        super.init()
    }

    public func start() {
        logger.log("MeetingCountdown agent starting")
        observeSystemChanges()
        refreshSchedule(reason: "startup")
    }

    public func togglePause() {
        state.isPaused.toggle()
        persistState()
        logger.log(state.isPaused ? "Agent paused by user" : "Agent resumed by user")
        refreshSchedule(reason: state.isPaused ? "pause" : "resume")
    }

    public func reload() {
        logger.log("Manual reload requested")
        refreshSchedule(reason: "manual reload")
    }

    public func runTestCountdown(seconds: Int) {
        logger.log("Running manual countdown test for \(seconds) seconds")
        overlayController.present(title: "Test Countdown", seconds: seconds)
        if configuration.soundEnabled {
            do {
                try audioPlayer?.play(seconds: seconds, volume: configuration.soundVolume)
            } catch {
                logger.log("Audio test playback failed: \(error.localizedDescription)")
            }
        }
    }

    private func observeSystemChanges() {
        eventStoreChangeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: accessManager.eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSchedule(reason: "event store changed")
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSchedule(reason: "wake from sleep")
            }
        }
    }

    private func refreshSchedule(reason: String) {
        fireTimer?.invalidate()
        fireTimer = nil

        do {
            configuration = try configurationStore.loadOrCreateDefault()
            state = try stateStore.load()
        } catch {
            logger.log("Failed to load persisted settings: \(error.localizedDescription)")
        }

        guard accessManager.hasReadableAccess() else {
            logger.log("Calendar access missing during \(reason)")
            nextMeeting = nil
            publishStatus(message: "Calendar access required")
            return
        }

        let now = Date()
        let meetings = candidateFinder.upcomingEligibleMeetings(configuration: configuration, now: now)
        nextMeeting = meetings.first(where: { $0.occurrenceID != state.lastTriggeredOccurrenceID }) ?? meetings.first

        switch TriggerPlanner.decide(meetings: meetings, state: state, configuration: configuration, now: now) {
        case .noMeeting:
            logger.log("No eligible meetings to schedule during \(reason)")
            publishStatus(message: state.isPaused ? "Paused" : nil)
        case .wait(let meeting, let fireDate):
            let interval = max(0.1, fireDate.timeIntervalSince(now))
            logger.log("Scheduled \(meeting.title) for \(Formatters.consoleDateTimeString(from: fireDate)) during \(reason)")
            publishStatus(message: nil)
            fireTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.trigger(meeting: meeting, reason: "scheduled fire")
                }
            }
        case .fireNow(let meeting):
            logger.log("Firing \(meeting.title) immediately during \(reason)")
            publishStatus(message: nil)
            trigger(meeting: meeting, reason: "immediate fire")
        }
    }

    private func trigger(meeting: MeetingCandidate, reason: String) {
        state.lastTriggeredOccurrenceID = meeting.occurrenceID
        persistState()

        let countdownSeconds = TriggerPlanner.countdownSeconds(
            until: meeting,
            leadTimeSeconds: configuration.leadTimeSeconds,
            now: Date()
        )

        do {
            try browserOpener.open(meetingURL: meeting.meetURL, configuration: configuration)
            logger.log("Opened Chrome for \(meeting.title) (\(meeting.meetURL.absoluteString)) during \(reason)")
        } catch {
            logger.log("Failed to open Chrome for \(meeting.title): \(error.localizedDescription)")
            notificationManager.notifyError(
                title: "Meeting Countdown",
                body: "Could not open Google Chrome for \(meeting.title)."
            )
        }

        overlayController.present(title: meeting.title, seconds: countdownSeconds)

        if configuration.soundEnabled {
            do {
                try audioPlayer?.play(seconds: countdownSeconds, volume: configuration.soundVolume)
            } catch {
                logger.log("Audio playback failed for \(meeting.title): \(error.localizedDescription)")
            }
        }

        refreshSchedule(reason: "post-trigger")
    }

    private func persistState() {
        do {
            try stateStore.save(state)
        } catch {
            logger.log("Failed to save state: \(error.localizedDescription)")
        }
    }

    private func publishStatus(message: String?) {
        let status = AgentStatus(
            nextMeeting: nextMeeting,
            isPaused: state.isPaused,
            message: message
        )
        onStatusChanged?(status)
    }
}
