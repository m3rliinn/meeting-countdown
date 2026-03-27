import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
}

public enum ProcessRunnerError: LocalizedError {
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return message
        }
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func run(_ launchPath: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed("Failed to launch \(launchPath): \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
