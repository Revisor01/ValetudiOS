# Phase 1: Foundation - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning
**Source:** Auto-mode (recommended defaults selected)

<domain>
## Phase Boundary

Phase 1 liefert die Infrastruktur-Grundlagen: sicherer Credential-Speicher (Keychain), sichtbare Fehlermeldungen (ErrorRouter), strukturiertes Logging (os.Logger) und die vollständig klickbare Robot-Zeile. Keine neuen API-Capabilities, keine View-Refactorings.

</domain>

<decisions>
## Implementation Decisions

### Error-Feedback (UX-02)
- **D-01:** Fehler werden dem Benutzer via SwiftUI `.alert` Modifier angezeigt — nativer iOS-Pattern, konsistent mit System-Dialogen
- **D-02:** Ein zentraler `ErrorRouter` (ObservableObject) wird als `@EnvironmentObject` in die View-Hierarchie injiziert. Views subscriben und zeigen `.alert` an wenn `ErrorRouter.currentError` gesetzt wird
- **D-03:** ErrorRouter unterstützt optionale Retry-Action (Closure), damit der Alert einen "Erneut versuchen"-Button anbieten kann

### Keychain-Migration (NET-03)
- **D-04:** Migration von UserDefaults zu Keychain erfolgt lazy beim ersten Robot-Zugriff (nicht global beim App-Start)
- **D-05:** Migrationsstrategie: 1) Credentials aus UserDefaults lesen, 2) In Keychain schreiben, 3) Aus Keychain zurücklesen (Verify-back), 4) Nur bei erfolgreichem Verify aus UserDefaults löschen
- **D-06:** Keychain-Zugriffsklasse: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — Credentials nur auf diesem Gerät, nur wenn entsperrt
- **D-07:** Ein `KeychainStore` Service kapselt alle SecItem-Operationen. Key pro Robot: `robotId.uuidString`

### Strukturiertes Logging (DEBT-01)
- **D-08:** Alle `print()` werden durch `os.Logger` ersetzt. Logger-Kategorien pro Service-Schicht: `API`, `RobotManager`, `NetworkScanner`, `Notifications`, `Views`
- **D-09:** Subsystem ist `Bundle.main.bundleIdentifier`. Debug-Level-Nachrichten erscheinen nicht in Production-Logs — kein `#if DEBUG` nötig
- **D-10:** Sensitivity-Audit vor Migration: Jeder bestehende print()-Aufruf wird auf Credentials/sensitive Daten geprüft. Sensitive Werte verwenden `.private` Privacy-Annotation

### Robot-Zeile klickbar (UX-01)
- **D-11:** Robot-Zeile in der Liste wird vollständig klickbar durch NavigationLink wrapping des gesamten Row-Contents (nicht nur Text)

### Claude's Discretion
- Reihenfolge der Implementierung innerhalb der Phase (welche Task zuerst)
- Konkrete os.Logger-Instanziierung (statische Properties vs. lokale Instanzen)
- Exakter ErrorRouter-API-Design (Property-Namen, Methoden-Signaturen)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Services (zu modifizieren)
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` — Zentrale State-Verwaltung, Polling-Loop, Credential-Zugriff auf UserDefaults
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — API-Client mit Basic Auth, print()-Debug-Statements
- `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift` — LAN-Scanner mit print()-Statements
- `ValetudoApp/ValetudoApp/Services/NotificationService.swift` — Notification-Service mit print()-Statements

### Models (zu modifizieren)
- `ValetudoApp/ValetudoApp/Models/RobotConfig.swift` — Robot-Konfiguration mit username/password Fields

### Views (zu modifizieren)
- `ValetudoApp/ValetudoApp/Views/RobotListView.swift` — Robot-Liste mit NavigationLink (UX-01 Fix)
- `ValetudoApp/ValetudoApp/ValetudoApp.swift` — App Entry Point (ErrorRouter injection)
- `ValetudoApp/ValetudoApp/ContentView.swift` — Tab-Root (ErrorRouter injection)

### Research
- `.planning/research/ARCHITECTURE.md` — Build-Reihenfolge und Architektur-Patterns
- `.planning/research/PITFALLS.md` — Keychain-Migration Pitfall, os.Logger Privacy-Pitfall
- `.planning/codebase/CONCERNS.md` — Detaillierte Concern-Beschreibungen

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ValetudoApp.swift` bereits `@StateObject var robotManager` — Pattern für ErrorRouter-Injection identisch
- `RobotConfig` ist bereits `Codable` — non-sensitive Fields bleiben in UserDefaults

### Established Patterns
- Services als `ObservableObject` mit `@Published` Properties (RobotManager-Pattern)
- `@EnvironmentObject` Injection in der View-Hierarchie
- `ValetudoAPI` als Swift `actor` für Thread-Safety
- `do/catch` mit lokaler Error-State in Views (bestehend, aber inkonsistent)

### Integration Points
- `RobotManager.loadRobots()` / `saveRobots()` — Keychain-Migration Hook
- `ValetudoApp` WindowGroup — ErrorRouter als EnvironmentObject
- Alle Views mit `print()` — os.Logger-Ersetzung

</code_context>

<specifics>
## Specific Ideas

- Keychain-Migration: Read-back-Verifikation ist Pflicht (aus Pitfalls-Research #2)
- os.Logger: `.private` für alle Credential-nahen Werte (aus Pitfalls-Research #5)
- ErrorRouter: Retry-Closure-Support für actionable Fehler

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-27 via auto-mode*
