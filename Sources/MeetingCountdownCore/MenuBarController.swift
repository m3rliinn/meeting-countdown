import AppKit
import Foundation

public struct AgentStatus: Sendable {
    public let nextMeeting: MeetingCandidate?
    public let isPaused: Bool
    public let message: String?

    public init(nextMeeting: MeetingCandidate?, isPaused: Bool, message: String?) {
        self.nextMeeting = nextMeeting
        self.isPaused = isPaused
        self.message = message
    }
}

@MainActor
public final class MenuBarController: NSObject {
    public var onTogglePause: (() -> Void)?
    public var onReload: (() -> Void)?
    public var onRunTest: (() -> Void)?
    public var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let previewItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
    private var cachedStatus = AgentStatus(nextMeeting: nil, isPaused: false, message: "Starting…")
    private var refreshTimer: Timer?

    public override init() {
        super.init()
        configure()
    }

    public func update(status: AgentStatus) {
        cachedStatus = status
        render()
    }

    private func configure() {
        statusItem.button?.title = "Meet"

        previewItem.isEnabled = false
        menu.addItem(previewItem)
        menu.addItem(.separator())

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)

        let testItem = NSMenuItem(title: "Run Test Countdown", action: #selector(runTest), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let reloadItem = NSMenuItem(title: "Reload Calendar", action: #selector(reloadCalendar), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.render()
            }
        }
        render()
    }

    private func render() {
        statusItem.button?.title = cachedStatus.isPaused ? "Meet Off" : "Meet"
        pauseItem.title = cachedStatus.isPaused ? "Resume" : "Pause"

        if let message = cachedStatus.message {
            previewItem.title = message
            return
        }

        if let nextMeeting = cachedStatus.nextMeeting {
            let relative = Formatters.relativeString(for: nextMeeting.startDate, relativeTo: Date())
            previewItem.title = "Next: \(nextMeeting.title) at \(Formatters.shortTimeString(from: nextMeeting.startDate)) (\(relative))"
        } else {
            previewItem.title = "No eligible Google Meet events found"
        }
    }

    @objc
    private func togglePause() {
        onTogglePause?()
    }

    @objc
    private func reloadCalendar() {
        onReload?()
    }

    @objc
    private func runTest() {
        onRunTest?()
    }

    @objc
    private func quitApp() {
        onQuit?()
    }
}
