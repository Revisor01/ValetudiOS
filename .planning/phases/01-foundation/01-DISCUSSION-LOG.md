# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 01-foundation
**Areas discussed:** Error-Feedback, Keychain-Migration, Logger-Kategorien, Error-State-Architektur
**Mode:** Auto (recommended defaults selected)

---

## Error-Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| SwiftUI .alert Modifier | Nativer iOS-Pattern, konsistent mit System-Dialogen | ✓ |
| Toast/Banner (custom) | Nicht-blockierend, aber kein Standard-SwiftUI-Component |  |
| Inline Error-Text | Direkt in der View, aber schwer global zu koordinieren |  |

**User's choice:** [auto] SwiftUI .alert Modifier (recommended default)
**Notes:** Nativer Ansatz, keine Custom-UI nötig, Retry-Button möglich

---

## Keychain-Migration

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy beim ersten Zugriff | Pro Robot migrieren wenn geladen, Verify-back vor Delete | ✓ |
| Global beim App-Start | Alle Robots auf einmal migrieren, blockiert Start |  |
| Manuell via Settings | User löst Migration aus |  |

**User's choice:** [auto] Lazy beim ersten Zugriff (recommended default)
**Notes:** Aus Pitfalls-Research: Read-back-Verifikation vor UserDefaults-Löschung ist Pflicht

---

## Logger-Kategorien

| Option | Description | Selected |
|--------|-------------|----------|
| Pro Service-Schicht | API, RobotManager, NetworkScanner, Notifications, Views | ✓ |
| Pro Feature | Cleaning, Map, Settings, Timer |  |
| Einheitlich | Ein Logger für alles |  |

**User's choice:** [auto] Pro Service-Schicht (recommended default)
**Notes:** Korreliert mit bestehendem Code-Layout

---

## Error-State-Architektur

| Option | Description | Selected |
|--------|-------------|----------|
| Zentraler ErrorRouter | ObservableObject als EnvironmentObject, Views subscriben | ✓ |
| Lokale @State per View | Jede View managed eigene Fehler |  |
| Notification-basiert | NotificationCenter Posts |  |

**User's choice:** [auto] Zentraler ErrorRouter (recommended default)
**Notes:** Konsistent mit RobotManager-Pattern, ermöglicht globale Error-Anzeige

---

## Claude's Discretion

- Implementierungsreihenfolge innerhalb der Phase
- Konkrete os.Logger-Instanziierung
- ErrorRouter-API-Design

## Deferred Ideas

None
