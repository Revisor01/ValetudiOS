# Phase 17: Background Monitoring - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Die App prüft den Roboter-Status auch im Hintergrund via BGAppRefreshTask und sendet die bestehenden lokalen Notifications (Reinigung abgeschlossen, Fehler, etc.) auch bei geschlossener App.

</domain>

<decisions>
## Implementation Decisions

### Background-Strategie
- BGAppRefreshTask (nicht BGProcessingTask) — kurze Prüfung (~30s), kein schwerer Processing nötig
- System-managed Intervall (ca. 15-30 Minuten, iOS entscheidet) — kein fester Intervall konfigurierbar
- Nur getAttributes() im Hintergrund — ein einzelner leichtgewichtiger API-Call pro Roboter
- Ein BGTask für alle konfigurierten Roboter — iteriert über robotConfigs

### Notification-Verhalten
- Notification-Typen sind bereits einzeln steuerbar (5 Optionen in NotificationService) — bestehende Logik beibehalten
- "Reinigung abgeschlossen" wird über Status-Vergleich erkannt: vorheriger State in UserDefaults gespeichert, neuer State verglichen (analog zu RobotManager.checkForStateChanges())
- Kein separater Toggle für Hintergrundüberwachung — immer aktiv sobald Notifications erlaubt
- Standard-Sound + Badge-Zähler — iOS-Defaults nutzen

### Persistenz & Architektur
- Letzter bekannter Status in UserDefaults gespeichert — ein Snapshot pro Roboter (einfach, ausreichend)
- BGTask-Registrierung in AppDelegate.didFinishLaunchingWithOptions — Standard-Approach
- Neuer BackgroundMonitorService — klare Trennung von RobotManager (Foreground-only)
- NotificationService.requestAuthorization() existiert bereits — direkt nutzen

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- NotificationService (NotificationService.swift:1-189) — vollständig implementiert mit 5 Notification-Typen und Action-Handlers
- RobotManager.checkForStateChanges() — bestehende State-Vergleichslogik (cleaning→docked, stuck, error)
- ValetudoAPI.getAttributes() — leichtgewichtiger API-Call für Roboter-Status
- AppDelegate (ValetudoApp.swift:4-25) — existiert, behandelt bereits Notification-Responses

### Established Patterns
- NotificationService.shared als Singleton
- RobotManager verwaltet robotConfigs Array
- SSEConnectionManager mit exponential backoff (Referenz für Fehlerbehandlung)
- os.Logger für strukturiertes Logging in allen Services

### Integration Points
- AppDelegate: BGTaskScheduler.register() in didFinishLaunchingWithOptions
- Info.plist: UIBackgroundModes → fetch hinzufügen
- BackgroundMonitorService → ValetudoAPI für Status-Checks
- BackgroundMonitorService → NotificationService für Notification-Versand
- UserDefaults: Letzter Status pro Roboter-ID speichern/lesen

</code_context>

<specifics>
## Specific Ideas

- State-Vergleich analog zu RobotManager.checkForStateChanges() — gleiche Logik, aber mit UserDefaults-Persistenz statt In-Memory
- BGAppRefreshTask ID: "de.simonluthe.ValetudoApp.backgroundRefresh" (oder ähnlich Bundle-ID-basiert)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
