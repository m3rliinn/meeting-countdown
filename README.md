# Meeting Countdown

Native macOS background utility that watches Apple Calendar for Google Meet links, opens Meet in Chrome 10 seconds before start time, and shows a floating countdown with an original broadcast-style stinger.

## Build

```bash
swift build -c release
```

## Commands

```bash
.build/release/meeting-countdown setup
.build/release/meeting-countdown run
.build/release/meeting-countdown test --seconds 10
.build/release/meeting-countdown status
```

## What `setup` does

- Creates `~/Library/Application Support/MeetingCountdown/config.json` if it does not exist.
- Requests Calendar access.
- Installs `~/Library/LaunchAgents/dev.meetingcountdown.agent.plist`.
- Bootstraps the launch agent so it starts at login.

## Notes

- This app reads Google Meet events through macOS Calendar. Make sure your Google Calendar is already synced to Apple Calendar.
- The app opens the Meet tab in Google Chrome 10 seconds early, but it does not press `Join now`.
- Logs are written to `~/Library/Logs/MeetingCountdown/agent.log`.
