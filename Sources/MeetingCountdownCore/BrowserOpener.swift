import AppKit
import Foundation

public enum BrowserOpenerError: LocalizedError {
    case browserMissing(String)
    case openFailed(String)

    public var errorDescription: String? {
        switch self {
        case .browserMissing(let bundleID):
            return "Could not find a browser with bundle identifier \(bundleID)."
        case .openFailed(let message):
            return message
        }
    }
}

public final class BrowserOpener {
    public init() {}

    public func open(meetingURL: URL, configuration: AppConfiguration) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: configuration.chromeBundleID) != nil else {
            throw BrowserOpenerError.browserMissing(configuration.chromeBundleID)
        }

        let result = try ProcessRunner.run("/usr/bin/open", arguments: [
            "-b",
            configuration.chromeBundleID,
            meetingURL.absoluteString,
        ])

        guard result.status == 0 else {
            let message = result.stderr.isEmpty ? "Failed to open \(meetingURL.absoluteString)" : result.stderr
            throw BrowserOpenerError.openFailed(message)
        }

        if configuration.openInForeground {
            let activateScript = #"tell application id "\#(configuration.chromeBundleID)" to activate"#
            _ = try? ProcessRunner.run("/usr/bin/osascript", arguments: ["-e", activateScript])
        }
    }
}
