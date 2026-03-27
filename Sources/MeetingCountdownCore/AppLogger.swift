import Foundation

public final class AppLogger {
    private let queue = DispatchQueue(label: "MeetingCountdown.logger")
    private let logURL: URL

    public init(logURL: URL = AppPaths.logFileURL) throws {
        self.logURL = logURL
        try AppPaths.ensureDirectories()
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    public func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async { [logURL] in
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                fputs("Logging failed: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}
