import Foundation

public enum MeetLinkExtractor {
    private static let regex = try! NSRegularExpression(
        pattern: #"https://meet\.google\.com/[A-Za-z0-9\-?=&_%/]+"#,
        options: [.caseInsensitive]
    )

    public static func extract(eventURL: URL?, notes: String?) -> URL? {
        if let eventURL, isMeetURL(eventURL) {
            return eventURL
        }

        guard let notes else {
            return nil
        }

        let nsRange = NSRange(notes.startIndex..<notes.endIndex, in: notes)
        guard let match = regex.firstMatch(in: notes, options: [], range: nsRange),
              let range = Range(match.range, in: notes)
        else {
            return nil
        }

        let raw = String(notes[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]>\"'"))
        guard let url = URL(string: raw), isMeetURL(url) else {
            return nil
        }
        return url
    }

    public static func isMeetURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return host == "meet.google.com"
    }
}
