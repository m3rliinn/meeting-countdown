import Foundation

public enum LaunchAgentInstallerError: LocalizedError {
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .installFailed(let message):
            return message
        }
    }
}

public final class LaunchAgentInstaller {
    private let logger: AppLogger

    public init(logger: AppLogger) {
        self.logger = logger
    }

    public func install(executableURL: URL) throws {
        try AppPaths.ensureDirectories()

        let plist: [String: Any] = [
            "Label": AppPaths.launchAgentLabel,
            "ProgramArguments": [executableURL.path, "run"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "StandardOutPath": AppPaths.logFileURL.path,
            "StandardErrorPath": AppPaths.logFileURL.path,
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: AppPaths.launchAgentURL, options: .atomic)
        logger.log("Installed launch agent at \(AppPaths.launchAgentURL.path)")
    }

    public func migrateLegacyInstallations() throws {
        let uid = getuid()
        let fileManager = FileManager.default
        let launchAgentsDirectory = AppPaths.launchAgentURL.deletingLastPathComponent()

        let candidateURLs = try fileManager.contentsOfDirectory(
            at: launchAgentsDirectory,
            includingPropertiesForKeys: nil
        ).filter { url in
            url.pathExtension == "plist" &&
                url.lastPathComponent != AppPaths.launchAgentURL.lastPathComponent &&
                url.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains("meetingcountdown")
        }

        for legacyURL in candidateURLs {
            let legacyLabel = legacyURL.deletingPathExtension().lastPathComponent

            _ = try? ProcessRunner.run("/bin/launchctl", arguments: [
                "bootout",
                "gui/\(uid)/\(legacyLabel)",
            ])

            _ = try? ProcessRunner.run("/bin/launchctl", arguments: [
                "bootout",
                "gui/\(uid)",
                legacyURL.path,
            ])

            if fileManager.fileExists(atPath: legacyURL.path) {
                try fileManager.removeItem(at: legacyURL)
                logger.log("Removed legacy launch agent at \(legacyURL.path)")
            }
        }
    }

    public func bootstrap() throws {
        let uid = getuid()

        _ = try? ProcessRunner.run("/bin/launchctl", arguments: [
            "bootout",
            "gui/\(uid)",
            AppPaths.launchAgentURL.path,
        ])

        let bootstrapResult = try ProcessRunner.run("/bin/launchctl", arguments: [
            "bootstrap",
            "gui/\(uid)",
            AppPaths.launchAgentURL.path,
        ])

        guard bootstrapResult.status == 0 else {
            logger.log("launchctl bootstrap failed: \(bootstrapResult.stderr)")
            throw LaunchAgentInstallerError.installFailed(bootstrapResult.stderr.isEmpty ? "launchctl bootstrap failed" : bootstrapResult.stderr)
        }

        let kickstartResult = try ProcessRunner.run("/bin/launchctl", arguments: [
            "kickstart",
            "-k",
            "gui/\(uid)/\(AppPaths.launchAgentLabel)",
        ])

        guard kickstartResult.status == 0 else {
            logger.log("launchctl kickstart failed: \(kickstartResult.stderr)")
            throw LaunchAgentInstallerError.installFailed(kickstartResult.stderr.isEmpty ? "launchctl kickstart failed" : kickstartResult.stderr)
        }

        logger.log("Bootstrapped launch agent \(AppPaths.launchAgentLabel)")
    }
}
