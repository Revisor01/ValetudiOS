# Milestones

## v3.0.0 Quality, Performance & Hardening (Shipped: 2026-04-05)

**Phases completed:** 30 phases, 67 plans, 101 tasks

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
- DeviceInfoSection DisclosureGroup (Hardware/Valetudo/System) in RobotDetailView, replacing robotPropertiesSection and deleting ValetudoInfoView from Settings
- BGAppRefreshTask-Infrastruktur mit BackgroundMonitorService, UserDefaults-State-Persistenz und NotificationService-Integration fuer Hintergrund-Roboter-Monitoring
- MapCacheService Singleton mit async JSON-Persistenz in Documents/MapCache/ und isOffline-Flag-Integration in MapViewModel fuer CACHE-01/02/03
- One-liner:
- 1. [Rule 1 - Bug] @Observable + @AppStorage conflict in SupportManager
- selectedSegmentIds und selectedSegments von Set<String> zu [String] migriert, damit Auswahl-Reihenfolge als Reinigungsreihenfolge an die Valetudo API uebergeben wird
- Five duplicate calculateMapParams implementations eliminated — unified into MapGeometry.swift with MapParams struct, free functions for coordinate transforms, and padding:10 explicitly wired for MiniMapView
- RobotManager gains roomSelections and iterationSelections dicts; MapViewModel and RobotDetailViewModel sync via didSet, eliminating the view-switch deselection bug (DEBT-02)
- One-liner:
- SupportManager.loadProducts() validiert geladene Product IDs via Set-Differenz gegen Constants.supportProductIds und loggt fehlende IDs als logger.error (DEBT-07)
- MapViewModel ersetzt 2-Sekunden HTTP-Poll durch SSE-Stream mit exponentieller Reconnect-Strategie; MapCacheService schreibt nur noch bei tatsaechlicher Datenaenderung auf Disk
- O(1) room tap hit-testing via packed Set<Int> pixel lookup and per-map segmentInfos caching, eliminating O(n) linear pixel scans on every tap and every overlay render
- Floor, walls, and segments pre-rendered as a single CGImage on a background thread — Canvas draws only dynamic elements (selection, entities, restrictions) per frame
- RobotDetailView von 1210 auf 143 Zeilen reduziert durch Extraktion von 12 eigenstaendigen Section-Structs in Views/Detail/
- RobotSettingsSections.swift (1079 lines, 6 structs) split into 6 individual files under Views/Settings/ — zero behavioral changes, file-specific loggers, xcodegen + build verified
- MapContentView split from 858 to 374 lines via Swift extension files — drawing/gesture logic in MapDrawingOverlay.swift, overlay views and sheet modifiers in MapOverlayViews.swift, build verified clean
- Oranges HTTP-Lock-Icon im Status-Header und prominente SSL-Bypass-Warnbanner in Add/EditRobotView mit Bugfix fuer verlorene SSL-Einstellungen beim Speichern
- KeychainStore (SEC-03):
- VoiceOver accessibility labels on all interactive controls, status header, consumable progress bars, and map canvas via .accessibilityLabel/.accessibilityValue/.accessibilityElement modifiers
- VoiceOver-Labels fuer Map-Canvas (children: .ignore), Room-Chips (name + select/deselect hint) und 7 Icon-only-Buttons in MapView, MapControlBarsView und MapOverlayViews
- 71 new unit tests covering MapGeometry transforms, UpdateService 8-phase state machine, SSE backoff timing, and MapCacheService save/load/corrupted-cache — total test suite grows to 130 tests
- ValetudoAPIProtocol extracted from concrete actor, UpdateService refactored for DI, 15 unit tests covering all UpdatePhase transitions + error recovery via MockValetudoAPI
- HTTP fallback polling restricted to the active robot via activeRobotId property with didSet-triggered restartRefreshing(), reducing unnecessary network load and battery drain in multi-robot setups

---

## v3.0.0 Quality, Performance & Hardening (In Progress)

**Phases:** 22-29 (8 phases, 31 requirements)

**Goal:** Die App auf Produktionsqualität bringen — Tech Debt eliminieren, Map-Performance optimieren, Views dekomponieren, Security-Warnungen, VoiceOver-Accessibility, Test-Coverage für kritische Pfade, UX-Robustness.

**Dependency Graph:**

```
Phase 22 (Map Geometry) ──┬── Phase 23 (Error Handling) ──┬── Phase 28 (Tests)
                          ├── Phase 24 (Map Performance)   └── Phase 29 (UX Robustness)
                          ├── Phase 25 (View Architecture) ── Phase 27 (Accessibility)
                          └── Phase 26 (Security) [parallel]
```

---

## v2.2.0 Room Interaction & Cleaning Order (Shipped: 2026-04-04)

**Phases completed:** 22 phases, 48 plans, 63 tasks

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
- DeviceInfoSection DisclosureGroup (Hardware/Valetudo/System) in RobotDetailView, replacing robotPropertiesSection and deleting ValetudoInfoView from Settings
- BGAppRefreshTask-Infrastruktur mit BackgroundMonitorService, UserDefaults-State-Persistenz und NotificationService-Integration fuer Hintergrund-Roboter-Monitoring
- MapCacheService Singleton mit async JSON-Persistenz in Documents/MapCache/ und isOffline-Flag-Integration in MapViewModel fuer CACHE-01/02/03
- One-liner:
- 1. [Rule 1 - Bug] @Observable + @AppStorage conflict in SupportManager
- selectedSegmentIds und selectedSegments von Set<String> zu [String] migriert, damit Auswahl-Reihenfolge als Reinigungsreihenfolge an die Valetudo API uebergeben wird

---

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
