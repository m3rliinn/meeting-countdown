import Foundation

public struct SetupCommand {
    public init() {}

    public func execute(executableURL: URL) throws {
        try AppPaths.ensureDirectories()

        let logger = try AppLogger()
        logger.log("Running setup using executable \(executableURL.path)")

        let configurationStore = ConfigurationStore()
        _ = try configurationStore.loadOrCreateDefault()

        let accessManager = CalendarAccessManager()
        do {
            _ = try accessManager.requestAccessSync()
            logger.log("Calendar access confirmed during setup")
        } catch {
            logger.log("Calendar access unavailable during setup: \(error.localizedDescription)")
            print("Warning: \(error.localizedDescription)")
            print("The agent will install, but it will not monitor meetings until Calendar access is granted.")
        }

        let installer = LaunchAgentInstaller(logger: logger)
        try installer.migrateLegacyInstallations()
        try installer.install(executableURL: executableURL)
        try installer.bootstrap()

        print("Setup complete.")
        print("Config: \(AppPaths.displayPath(for: AppPaths.configURL))")
        print("LaunchAgent: \(AppPaths.displayPath(for: AppPaths.launchAgentURL))")
        print("Logs: \(AppPaths.displayPath(for: AppPaths.logFileURL))")
    }
}
