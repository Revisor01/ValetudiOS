# Phase 2: Network Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.

**Date:** 2026-03-27
**Phase:** 02-network-layer
**Areas discussed:** SSE-Verbindung, Polling-Fallback, mDNS-Integration, Map-Cache
**Mode:** Auto (recommended defaults selected)

---

## SSE-Verbindungsstrategie

| Option | Description | Selected |
|--------|-------------|----------|
| Eine attributes-SSE, map-SSE nur bei MapView | Spart Verbindungen, respektiert 5-Client-Limit | ✓ |
| Beide SSE-Streams immer aktiv | Echtzeit-Map-Updates auch ohne MapView |  |
| Nur attributes-SSE, Map weiterhin polled | Einfachste Implementierung |  |

**User's choice:** [auto] Eine attributes-SSE + conditional map-SSE
**Notes:** 5-Client-Limit bei Valetudo macht sparsame Nutzung wichtig

---

## Polling-Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Automatischer Fallback + 30s Reconnect | Nahtlos, kein User-Eingriff | ✓ |
| Manueller Wechsel via Settings | User entscheidet |  |
| Kein Fallback, nur SSE | Simpel aber fragil |  |

**User's choice:** [auto] Automatischer Fallback
**Notes:** SSE und Polling nie gleichzeitig aktiv (Race-Condition-Pitfall)

---

## mDNS-Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel: mDNS sofort, IP-Scan nach 3s | Schnellste Erkennung mit Fallback | ✓ |
| Sequentiell: erst mDNS, dann IP | Einfacher, aber langsamer |  |
| Nur mDNS, IP-Scan entfernen | Moderner, aber kein Fallback |  |

**User's choice:** [auto] Parallel mit 3s Timeout
**Notes:** NSBonjourServices muss in project.yml vor Code-Änderung eingetragen werden

---

## Map-Cache-Strategie

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy stored property pro MapLayer | Granular, memory-effizient | ✓ |
| NSCache-basiert | Automatische Memory-Eviction |  |
| Vorberechnung beim Map-Empfang | Eager, aber blockiert Main-Thread |  |

**User's choice:** [auto] Lazy stored property (class-basierte Referenz wegen Struct)

## Claude's Discretion

- SSE-Parsing-Details, NWBrowser Lifecycle, Cache-Implementierung

## Deferred Ideas

None
