import Foundation

public final class NotificationManager {
    public init() {}

    public func notifyError(title: String, body: String) {
        let script = #"display notification "\#(escape(body))" with title "\#(escape(title))""#
        _ = try? ProcessRunner.run("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
