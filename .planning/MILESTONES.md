# Milestones

## v2.0.0 Update Process Hardening (Shipped: 2026-04-01)

**Phases completed:** 15 phases, 38 plans, 51 tasks

**Key accomplishments:**

- One-liner:
- ErrorRouter as @MainActor ObservableObject with alert modifier injected app-wide, plus NavigationLink(value:) replacing Button for fully clickable robot list rows
- 6 print() calls across 3 Service files replaced with structured os.Logger using privacy annotations — zero print() remaining in Services
- One-liner:
- NWBrowserService mit _valetudo._tcp Bonjour-Discovery, TXT-Record-Parsing (friendlyName/model), NetworkScanner-Parallelstrategie (mDNS sofort + IP-Fallback nach 3s), und AddRobotView mit Bonjour-Badge und Sortierung
- MapLayerCache final class caches RLE-decompressed pixels per MapLayer instance; MapContentView replaces 2s polling with SSE stream (auto-fallback to polling on failure)
- One-liner:
- One-liner:
- One-liner:
- XCTest target ValetudoAppTests established via XcodeGen with 29 tests covering Timer UTC conversion, Consumable remainingPercent, MapLayer RLE decompression, and KeychainStore round-trip — all green
- One-liner:
- One-liner:
- MapViewModel.swift
- Events-Section, CleanRoute-Picker und Obstacle-Photos in RobotDetailView verdrahtet — Phase-3 API-Methoden jetzt ueber Phase-4 ViewModel-Layer fuer Benutzer erreichbar
- Capability-gated Map Snapshots list with Restore and Pending Map Change Accept/Reject wired from Phase-3 API into Phase-4 RobotSettingsViewModel/View layer
- VoicePackManagementCapability vollstaendig integriert: API-Methoden, ViewModel-State und capability-gated Picker-UI in RobotSettingsView
- AutoEmptyDockAutoEmptyDurationControlCapability mit API-Methoden, lokalem State und Preset-Picker in der Auto-Empty-Section integriert
- Three silent catch blocks in MapViewModel and RobotManager replaced with os.Logger calls and a @Published errorMessage for user-facing clean failures
- One-liner:
- Float-zu-Int-Truncation bei Pixel-Koordinaten-Umrechnung durch `.rounded()` behoben — Zone-Cleaning, GoTo-Marker und Room-Split landen jetzt auf der korrekten API-Position
- Found during:
- 12 URLProtocol-free unit tests covering APIError errorDescriptions, RobotConfig.baseURL HTTP/HTTPS construction, and JSONDecoder on Consumable, Capabilities, RobotInfo, and RobotAttribute models
- 11 print()-Aufrufe in 4 View-Dateien durch os.Logger ersetzt — jede View hat jetzt import os + private let logger = Logger(subsystem:category:) und nutzt logger.error(..., privacy: .public) fur alle Fehlerausgaben
- os.Logger ersetzt alle 17 print()-Aufrufe in ManualControlView (5), RoomsManagementView (8) und TimersView (4) mit privacy: .public
- SupportManager vollstaendig auf os.Logger migriert; SupportReminderView DispatchQueue.main.asyncAfter durch Swift Structured Concurrency (Task.sleep + MainActor.run) ersetzt
- Force-Unwrap in SettingsView eliminiert, Keychain-Fehler via os.Logger sichtbar gemacht, alle Magic-Strings (GitHub-API-URL, Valetudo-Links, StoreKit-ProductIDs) in neuer Constants.swift zentralisiert
- 1. [Rule 4-adjacent - Design] Control Bars als Extension statt eigenständige Structs
- RobotSettingsView.swift split from 1801 to 502 lines — 7 standalone sub-views (AutoEmptyDock, Quirks, Wifi, MQTT, NTP, ValetudoInfo, Station) extracted into RobotSettingsSections.swift
- One-liner:
- UpdatePhase-Enum (8 Cases) und UpdateService als @MainActor ObservableObject mit Re-Entrancy-Guards, Error-State-Propagation und Polling-Loop mit Pitfall-6-Erkennung
- UpdateService als Single Source of Truth verdrahtet — RobotDetailViewModel delegiert, ValetudoInfoView liest dieselbe Instanz (STATE-04 erfüllt)
- One-liner:
- UIKit-basierte Absicherung des Apply-Moments: Idle Timer, 120s Reboot-Polling mit Netzwerkfehler-Ignorierung und UIBackgroundTask-Schutz gegen iOS-Abbruch
- Nicht-schliessbares Fullscreen-Overlay in RobotDetailView, das bei .applying und .rebooting erscheint und Back-Button sowie Swipe-Dismiss sperrt
- One-liner:

---
