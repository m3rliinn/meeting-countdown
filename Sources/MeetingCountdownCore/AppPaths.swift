import Foundation

public enum AppPaths {
    public static let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MeetingCountdown", isDirectory: true)

    public static let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MeetingCountdown", isDirectory: true)

    public static let configURL = appSupportDirectory.appendingPathComponent("config.json")
    public static let stateURL = appSupportDirectory.appendingPathComponent("state.json")

    public static let launchAgentLabel = "dev.meetingcountdown.agent"

    public static let launchAgentURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")

    public static let logFileURL = logsDirectory.appendingPathComponent("agent.log")

    public static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static func launchAgentURL(for label: String) -> URL {
        homeDirectory.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static func displayPath(for url: URL) -> String {
        let homePath = homeDirectory.path
        guard url.path.hasPrefix(homePath) else {
            return url.path
        }

        let suffix = url.path.dropFirst(homePath.count)
        return "~" + suffix
    }

    public static func ensureDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
