import Foundation
import MeetingCountdownCore

enum Main {
    @MainActor
    static func run() -> Int32 {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            return 1
        }

        do {
            switch command {
            case "setup":
                try SetupCommand().execute(executableURL: URL(fileURLWithPath: CommandLine.arguments[0]))
                return 0
            case "run":
                MeetingCountdownApplication.runAgent()
                return 0
            case "test":
                let seconds = try parseTestSeconds(from: Array(arguments.dropFirst()))
                MeetingCountdownApplication.runTest(seconds: seconds)
                return 0
            case "status":
                try StatusCommand().execute()
                return 0
            case "help", "--help", "-h":
                printUsage()
                return 0
            default:
                fputs("Unknown command: \(command)\n", stderr)
                printUsage()
                return 1
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func parseTestSeconds(from arguments: [String]) throws -> Int {
        var index = 0
        var seconds = 10

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--seconds":
                let nextIndex = index + 1
                guard arguments.indices.contains(nextIndex), let parsed = Int(arguments[nextIndex]), parsed > 0 else {
                    throw CommandLineError.invalidValue("--seconds requires a positive integer")
                }
                seconds = parsed
                index += 2
            default:
                throw CommandLineError.invalidValue("Unknown option: \(argument)")
            }
        }

        return seconds
    }

    private static func printUsage() {
        let usage = """
        Usage:
          meeting-countdown setup
          meeting-countdown run
          meeting-countdown test --seconds 10
          meeting-countdown status
        """
        print(usage)
    }
}

enum CommandLineError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        }
    }
}

exit(Main.run())
