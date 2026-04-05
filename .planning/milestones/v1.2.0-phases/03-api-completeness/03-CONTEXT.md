# Phase 3: API Completeness - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 integriert fehlende Valetudo API-Capabilities in die App: Map-Snapshot-Management, Map-Reset-Bestätigung, Reinigungsrouten-Auswahl, Obstacle-Fotos, Valetudo Events-Ansicht und Notification-Actions (GO_HOME, LOCATE). Keine View-Refactorings, keine neuen Infrastruktur-Services.

</domain>

<decisions>
## Implementation Decisions

### API-Capabilities UI-Pattern
- **D-01:** Map-Snapshot und Map-Reset Aktionen werden in RobotSettingsView platziert — dort sind bereits Karten-Einstellungen (PersistentMap, VirtualRestrictions)
- **D-02:** Reinigungsrouten werden als Picker in RobotDetailView angezeigt — analog zu bestehendem Fan-Speed/Water-Usage Picker mit Capability-Check
- **D-03:** Obstacle-Fotos werden in einer neuen ObstaclePhotoView angezeigt — accessible via Event-Liste, Lazy-Loading der Bilder
- **D-04:** Valetudo Events als neue EventsView Section in RobotDetailView — chronologische Liste mit Event-Typ-Icons (DustBinFull, MopReminder etc.)

### Notification-Actions
- **D-05:** UNNotificationResponse-Handler wird in NotificationService implementiert — dort sind bereits die Actions registriert
- **D-06:** Handler greift über RobotManager auf ValetudoAPI zu — bestehender Pattern via apis Dictionary und selectedRobotId
- **D-07:** Wenn kein Roboter ausgewählt: Aktion auf ersten verfügbaren Roboter ausführen (User hat meist nur einen)

### Capability-Gating
- **D-08:** UI-Elemente werden ausgeblendet wenn Capability fehlt — bestehendes Pattern mit capabilities Check (hasManualControl etc.)
- **D-09:** Capabilities werden einmal beim Robot-Connect gecheckt (getCapabilities) — bereits in RobotManager implementiert, in RobotStatus.capabilities gecacht
- **D-10:** Graceful Degradation für Obstacle-Fotos: Events ohne Fotos zeigen nur Text, Foto-Button nur wenn ObstacleImagesCapability vorhanden

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- ValetudoAPI actor mit ~50 API-Methoden (getCapabilities, getAttributes, getMap etc.)
- RobotManager mit apis Dictionary und robotStates Publisher
- NotificationService mit bereits registrierten GO_HOME/LOCATE UNNotificationActions
- Capabilities struct mit boolean Properties (hasManualControl, hasMissingAttachments etc.)
- Picker-Pattern in RobotDetailView für Fan-Speed, Water-Usage, OperationMode
- ErrorRouter für Alert-basierte Fehleranzeige

### Established Patterns
- SwiftUI Views mit @EnvironmentObject RobotManager
- Async/await API-Calls in Task {} closures
- Capability-gated UI: `if capabilities.hasXYZ { ... }`
- Sections in RobotDetailView und RobotSettingsView für Feature-Gruppen
- os.Logger mit Service-spezifischer Kategorie

### Integration Points
- RobotDetailView: neue Sections für Events und Reinigungsrouten
- RobotSettingsView: neue Section für Map-Snapshot-Management
- NotificationService: UNUserNotificationCenterDelegate Handler
- ValetudoAPI: neue Methoden für Snapshots, MapReset, Events, ObstacleImages

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches matching existing codebase patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
