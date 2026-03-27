import EventKit
import Foundation

public enum CalendarAccessError: LocalizedError {
    case denied
    case restricted
    case unknownStatus

    public var errorDescription: String? {
        switch self {
        case .denied:
            return "Calendar access was denied."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .unknownStatus:
            return "Calendar permission could not be determined."
        }
    }
}

public final class CalendarAccessManager {
    public let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func hasReadableAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }

    public func requestAccessSync() throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            return true
        case .restricted:
            throw CalendarAccessError.restricted
        case .denied, .writeOnly:
            throw CalendarAccessError.denied
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            let resultBox = AccessRequestResult()

            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { isGranted, error in
                    resultBox.granted = isGranted
                    resultBox.error = error
                    semaphore.signal()
                }
            } else {
                eventStore.requestAccess(to: .event) { isGranted, error in
                    resultBox.granted = isGranted
                    resultBox.error = error
                    semaphore.signal()
                }
            }

            semaphore.wait()

            if let requestError = resultBox.error {
                throw requestError
            }
            if !resultBox.granted {
                throw CalendarAccessError.denied
            }
            return resultBox.granted
        @unknown default:
            throw CalendarAccessError.unknownStatus
        }
    }
}

private final class AccessRequestResult: @unchecked Sendable {
    var granted = false
    var error: Error?
}
