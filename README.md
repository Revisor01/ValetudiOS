<p align="center">
  <img src="AppIcon.png" alt="VacuPilot" width="128" height="128">
</p>

<h1 align="center">VacuPilot</h1>

<p align="center">
  The native iOS app for robot vacuums running <a href="https://valetudo.cloud">Valetudo</a> firmware.<br>
  Full control. No cloud. No tracking. Just your robot, your network, your data.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B-blue?logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Version-1.0.0-green" alt="Version">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen" alt="Dependencies">
  <img src="https://img.shields.io/badge/Tests-121-blue" alt="Tests">
  <img src="https://img.shields.io/github/license/Revisor01/VacuPilot" alt="License">
</p>

## Features

### Robot Control
- **Multi-Robot Support** — Manage all your Valetudo robots in one app
- **Real-Time Status** — Battery, cleaning status, and live statistics via SSE (Server-Sent Events)
- **Full Control** — Start, stop, pause, return to dock
- **Manual Control** — Joystick-style driving with high-resolution controls
- **Fan Speed & Water Usage** — Adjust intensity presets per cleaning session
- **Do Not Disturb** — Schedule quiet hours

### Map & Cleaning
- **Live Interactive Map** — Pinch-to-zoom, pan, real-time robot position tracking
- **Room Cleaning** — Tap rooms directly on the map to select them
- **Cleaning Order** — Selected rooms get numbered badges showing the cleaning sequence
- **Multi-Pass Cleaning** — Set iteration count per cleaning session
- **Zone Cleaning** — Draw custom cleaning zones on the map
- **Virtual Restrictions** — Create no-go zones, no-mop zones, and virtual walls
- **Go-To Locations** — Save favorite spots and send the robot there
- **Map Snapshots** — Save and restore map states

### Monitoring & Notifications
- **Consumable Tracking** — Filter, brushes, and sensor wear levels with low-level alerts
- **Push Notifications** — Cleaning complete, robot stuck, error states, consumable warnings
- **Background Monitoring** — Periodic status checks even when the app is closed
- **Offline Map Cache** — Maps are cached locally and restored when connection is unavailable

### Robot Settings
- **Firmware Updates** — Check, download, and apply updates with fullscreen progress protection
- **Timer / Schedules** — Create and manage cleaning schedules
- **Voice Packs** — Browse and switch voice language packs
- **MQTT Configuration** — Full MQTT broker settings (Home Assistant / Homie)
- **NTP Configuration** — Time server settings
- **WiFi Management** — View signal strength, scan networks, configure WiFi
- **Quirks** — Robot-specific configuration options
- **Carpet Mode** — Toggle automatic carpet boost
- **Auto-Empty Dock** — Configure auto-empty duration and behavior
- **Device Info** — Hardware details, Valetudo version, system health

### App
- **Automatic Discovery** — Finds robots via Bonjour (mDNS) and IP scan
- **SSL/TLS Support** — HTTPS connections with optional self-signed certificate bypass
- **Smart Connection Management** — Skips local robots when off-WiFi, suspends unreachable robots
- **Siri Shortcuts** — Voice control for common actions
- **Dark Mode** — Full dark mode support
- **Localization** — English, German, French
- **VoiceOver** — Full accessibility support
- **Zero Dependencies** — No third-party SDKs, no supply chain risk
- **GDPR Compliant** — All data stays on your device

## Requirements

- iOS 17.0+
- Valetudo 2024.06.0+
- Robot reachable on local network (or via VPN)

## Installation

### App Store

Coming soon.

### TestFlight (Public Beta)

Try the latest beta build directly on your iPhone:

**[Join the TestFlight Beta »](https://testflight.apple.com/join/N11Ncb1D)**

You'll need Apple's [TestFlight](https://apps.apple.com/app/testflight/id899247664) app installed.

### Build from Source

```bash
git clone https://github.com/Revisor01/VacuPilot.git
cd VacuPilot
open ValetudoApp/ValetudoApp.xcodeproj
```

Build and run on your device. No external dependencies to install.

## Setup

1. Open the app
2. Tap the scan button to discover robots automatically, or add manually by IP/hostname
3. Optionally enable authentication if configured in Valetudo

## Supported Robots

VacuPilot works with all robots supported by [Valetudo](https://valetudo.cloud):

- **Roborock** — S5, S5 Max, S6, S7, Q Revo, and more
- **Dreame** — L10 Pro, Z10 Pro, L20 Ultra, X40 Ultra, and more
- **Xiaomi / Viomi** — Various models
- And many more — see [Valetudo's supported robots](https://valetudo.cloud/pages/general/supported-robots.html)

## Screenshots

*Coming soon*

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **v1.0.0** | 2026-04 | Initial App Store release — multi-robot control, live interactive map, room/zone cleaning with order, firmware updates, background monitoring, VoiceOver accessibility, EN/DE/FR localization |

## Architecture

```
VacuPilot
├── Models/          — Codable API models, RobotConfig
├── Services/        — ValetudoAPI, RobotManager, SSEConnectionManager,
│                      UpdateService, MapCacheService, BackgroundMonitorService,
│                      NotificationService, KeychainStore, NetworkScanner
├── ViewModels/      — MapViewModel, RobotDetailViewModel, RobotSettingsViewModel
├── Views/           — SwiftUI views organized by feature
│   ├── Detail/      — Robot detail sections
│   ├── Settings/    — Robot settings sections
│   └── Map/         — Map overlays, drawing, controls
└── Tests/           — 121 unit tests (models, geometry, state machines, caching)
```

**Key design decisions:**
- Pure SwiftUI + Swift 5.9, no UIKit wrappers (except update fullscreen lock)
- Zero external package dependencies
- MVVM with @Observable (iOS 17+)
- Actor-based SSE connection management
- Capability-gated UI — features only appear if the robot supports them

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Valetudo](https://valetudo.cloud) — The open-source robot vacuum firmware
- The Valetudo developers and community

## Disclaimer

This is an unofficial companion app. VacuPilot is not affiliated with or endorsed by the Valetudo project.

---

## Privacy Policy

### Controller

Simon Luthe
Suederstrasse 18
25779 Hennstedt
Germany

Email: mail@simonluthe.de
Web: [simonluthe.de](https://simonluthe.de)

### Data Processing

**VacuPilot stores and processes the following data exclusively on your device:**

- IP addresses / hostnames of your Valetudo robots
- Optional credentials (username/password) for robot authentication
- App settings and preferences
- Saved GoTo locations
- Cached map data for offline viewing

**No data is transmitted to external servers.** All communication happens exclusively between your iOS device and your Valetudo robots on your local network.

### No Tracking or Analytics

VacuPilot uses:
- No analytics or tracking tools
- No advertising
- No cloud services
- No third-party SDKs that collect data

### Network Connections

The app only connects to the Valetudo robots you configure. These connections stay entirely within your local network (unless you use a VPN).

### Data Storage

All data is stored locally in the iOS Keychain (for credentials and robot config) and app storage (for settings and map cache). Uninstalling the app removes all data completely.

### Your Rights (GDPR)

Since all data is stored exclusively on your device with no transmission to the developer or third parties, you have full control over your data. You can remove it at any time by deleting the app.

For privacy questions, contact the address above.

### Changes

This privacy policy may be updated as needed. The current version is always available in this repository.

*Last updated: April 2026*
