# Phase 18: Map Caching - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Letzte Karte jedes Roboters wird auf Disk persistiert. Bei nicht-erreichbarem Roboter wird die gecachte Karte mit Offline-Indikator angezeigt. Automatische Aktualisierung sobald Verbindung wieder steht.

</domain>

<decisions>
## Implementation Decisions

### Cache-Strategie
- Speicherort: Documents/MapCache/{robotId}.json — eine Datei pro Roboter via FileManager
- Caching-Zeitpunkt: nach jedem erfolgreichen getMap() — im MapViewModel Polling-Loop
- Format: JSON via Codable — RobotMap ist bereits Codable, einfachste Lösung
- Cache-Invalidierung: Überschreiben bei jedem Update — immer die neueste Karte, kein TTL

### Offline-Verhalten
- Offline-Indikator: Overlay-Banner "Offline" auf der Karte — dezent, nicht-blockierend
- Offline-Erkennung: wenn getMap() fehlschlägt UND gecachte Karte vorhanden — ersetzt ContentUnavailableView
- Live-Wiederherstellung: automatisch beim nächsten erfolgreichen getMap() — Polling läuft weiter, Banner verschwindet
- Ohne Cache + offline: bestehende ContentUnavailableView bleibt (kein Cache vorhanden, nichts zu zeigen)

### Code-Architektur
- Neuer MapCacheService — klare Trennung, wiederverwendbar
- Async Disk-I/O (Background-Thread) — Disk-I/O soll nicht das UI blockieren
- Offline-Banner als Overlay in MapView.swift — ZStack über der Karte
- Cache-Cleanup bei Roboter-Löschung — RobotManager.removeRobot() löscht auch den Cache automatisch

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- RobotMap (RobotMap.swift) — bereits Codable, direkt serialisierbar
- MapLayerCache — in-memory Pixel-Decompression (bleibt erhalten, orthogonal zum Disk-Cache)
- MapViewModel.startMapRefresh() — Polling-Loop wo Cache-Writes eingefügt werden
- ContentUnavailableView (MapView.swift:336-340) — bestehender Offline-Fallback

### Established Patterns
- GoToPresetStore nutzt UserDefaults für Persistenz (Referenz für Codable-Serialisierung)
- MapViewModel lädt Daten async in Task-Closures
- os.Logger für strukturiertes Logging in Services
- Singleton-Pattern bei Services (NotificationService.shared, BackgroundMonitorService.shared)

### Integration Points
- MapViewModel: nach getMap()-Erfolg → MapCacheService.save(); bei getMap()-Fehler → MapCacheService.load()
- MapView.swift: Overlay-Banner wenn viewModel.isOffline == true
- RobotManager.removeRobot(): MapCacheService.deleteCache(for: robotId)
- MapViewModel: neue @Published var isOffline: Bool

</code_context>

<specifics>
## Specific Ideas

- Overlay-Banner ähnlich dem Update-Banner in RobotDetailView — dezent, am oberen Rand der Karte
- Cache-Pfad: FileManager.default.urls(for: .documentDirectory).first!/MapCache/{robotId}.json

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
