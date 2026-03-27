import Foundation

public struct AppState: Codable, Equatable, Sendable {
    public var lastTriggeredOccurrenceID: String?
    public var isPaused: Bool

    public init(lastTriggeredOccurrenceID: String? = nil, isPaused: Bool = false) {
        self.lastTriggeredOccurrenceID = lastTriggeredOccurrenceID
        self.isPaused = isPaused
    }
}

public final class StateStore {
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public init() {}

    public func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: AppPaths.stateURL.path) else {
            return AppState()
        }

        let data = try Data(contentsOf: AppPaths.stateURL)
        return try decoder.decode(AppState.self, from: data)
    }

    public func save(_ state: AppState) throws {
        try AppPaths.ensureDirectories()
        let data = try encoder.encode(state)
        try data.write(to: AppPaths.stateURL, options: .atomic)
    }
}
