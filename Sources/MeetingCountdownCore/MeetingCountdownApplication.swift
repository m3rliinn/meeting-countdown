import AppKit
import Foundation

@MainActor
public enum MeetingCountdownApplication {
    public static func runAgent() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let delegate = AgentAppDelegate()
        application.delegate = delegate
        application.run()
    }

    public static func runTest(seconds: Int) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let delegate = TestAppDelegate(seconds: seconds)
        application.delegate = delegate
        application.run()
    }
}

@MainActor
final class AgentAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var agent: MeetingCountdownAgent?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let logger: AppLogger
        do {
            logger = try AppLogger()
        } catch {
            fatalError("Failed to initialize logging: \(error.localizedDescription)")
        }

        let menuBarController = MenuBarController()
        let agent = MeetingCountdownAgent(logger: logger)

        menuBarController.onTogglePause = { [weak agent] in
            agent?.togglePause()
        }
        menuBarController.onReload = { [weak agent] in
            agent?.reload()
        }
        menuBarController.onRunTest = { [weak agent] in
            agent?.runTestCountdown(seconds: 10)
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }

        agent.onStatusChanged = { [weak menuBarController] status in
            menuBarController?.update(status: status)
        }
        agent.start()

        self.menuBarController = menuBarController
        self.agent = agent
    }
}

@MainActor
final class TestAppDelegate: NSObject, NSApplicationDelegate {
    private let seconds: Int
    private let overlayController = CountdownOverlayController()
    private let audioPlayer = try? CountdownAudioPlayer()

    init(seconds: Int) {
        self.seconds = max(1, seconds)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController.present(title: "Test Countdown", seconds: seconds)
        do {
            try audioPlayer?.play(seconds: seconds, volume: 0.8)
        } catch {
            fputs("Audio playback failed: \(error.localizedDescription)\n", stderr)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds + 2)) {
            NSApp.terminate(nil)
        }
    }
}
