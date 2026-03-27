import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var leadTimeSeconds: Int
    public var eligibleCalendarNames: [String]
    public var chromeBundleID: String
    public var openInForeground: Bool
    public var soundEnabled: Bool
    public var soundVolume: Double
    public var lateGraceSeconds: Int

    public init(
        leadTimeSeconds: Int = 10,
        eligibleCalendarNames: [String] = [],
        chromeBundleID: String = "com.google.Chrome",
        openInForeground: Bool = true,
        soundEnabled: Bool = true,
        soundVolume: Double = 0.8,
        lateGraceSeconds: Int = 60
    ) {
        self.leadTimeSeconds = max(1, leadTimeSeconds)
        self.eligibleCalendarNames = eligibleCalendarNames
        self.chromeBundleID = chromeBundleID
        self.openInForeground = openInForeground
        self.soundEnabled = soundEnabled
        self.soundVolume = min(max(soundVolume, 0.0), 1.0)
        self.lateGraceSeconds = max(0, lateGraceSeconds)
    }

    enum CodingKeys: String, CodingKey {
        case leadTimeSeconds
        case eligibleCalendarNames
        case chromeBundleID
        case openInForeground
        case soundEnabled
        case soundVolume
        case lateGraceSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            leadTimeSeconds: try container.decodeIfPresent(Int.self, forKey: .leadTimeSeconds) ?? 10,
            eligibleCalendarNames: try container.decodeIfPresent([String].self, forKey: .eligibleCalendarNames) ?? [],
            chromeBundleID: try container.decodeIfPresent(String.self, forKey: .chromeBundleID) ?? "com.google.Chrome",
            openInForeground: try container.decodeIfPresent(Bool.self, forKey: .openInForeground) ?? true,
            soundEnabled: try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true,
            soundVolume: try container.decodeIfPresent(Double.self, forKey: .soundVolume) ?? 0.8,
            lateGraceSeconds: try container.decodeIfPresent(Int.self, forKey: .lateGraceSeconds) ?? 60
        )
    }
}

public final class ConfigurationStore {
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public init() {}

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: AppPaths.configURL.path) else {
            return AppConfiguration()
        }

        let data = try Data(contentsOf: AppPaths.configURL)
        return try decoder.decode(AppConfiguration.self, from: data)
    }

    @discardableResult
    public func loadOrCreateDefault() throws -> AppConfiguration {
        try AppPaths.ensureDirectories()
        let config = try load()
        if !FileManager.default.fileExists(atPath: AppPaths.configURL.path) {
            try save(config)
        }
        return config
    }

    public func save(_ configuration: AppConfiguration) throws {
        try AppPaths.ensureDirectories()
        let data = try encoder.encode(configuration)
        try data.write(to: AppPaths.configURL, options: .atomic)
    }
}
