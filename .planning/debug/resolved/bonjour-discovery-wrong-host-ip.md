---
slug: bonjour-discovery-wrong-host-ip
status: resolved
trigger: Automatic network scan finds Valetudo robots via Bonjour but uses wrong host format (space instead of hyphen) and IP scan returns wrong addresses (.36/.38 instead of actual .35/.40)
created: 2026-04-29T10:19:02Z
updated: 2026-04-29T12:35:00Z
---

# Bonjour Discovery — Wrong Host & IPs

## Symptoms

### Bug 1 — Hostname mit Leerzeichen statt Bindestrich
- `dns-sd -B _valetudo._tcp local.` zeigt Service-Instanznamen wie `Valetudo CriticalMetallicMole` und `Valetudo DigitalSlowEchidna` (mit LEERZEICHEN)
- Code in `NWBrowserService.swift:86` macht: `let host = "\(name).local"` → ergibt `Valetudo CriticalMetallicMole.local`
- Das ist als URL unbrauchbar (Leerzeichen!) und auch im UI hässlich
- Valetudo's tatsächlicher mDNS-Hostname ist `valetudo-<robotid-lowercased>.local` mit BINDESTRICH

### Bug 2 — Falsche IPs beim IP-Scan
- Tatsächliche Roboter laufen auf 192.168.0.35 und 192.168.0.40
- Scan findet stattdessen .36 (und .38 ggf. via DHCP-Drift)
- Code: `NetworkScanner.swift:167` filtert auf HTTP 200, aber Valetudo gibt mit aktiver Basic Auth HTTP 401 zurück

## Reproduction

- Lokales Netz mit zwei Valetudo-Robotern auf .35 und .40 (beide mit Basic Auth)
- `dns-sd -B _valetudo._tcp local.` listet beide mit "Valetudo <Id>" Format
- App-Scan zeigt .36 (false positive, anderes Gerät) und/oder kaputte Hostnames

## Hypotheses

1. ~~NWBrowserService nutzt Service-Instanznamen statt TXT-Record `id`~~ → **bestätigt**
2. ~~IP-Scan-Diskrepanz unklar~~ → **bestätigt: 200-only Filter, echte Roboter geben 401 (Basic Auth)**
3. ~~Beide Bugs verbunden via DNS-Resolution-Failure~~ → **falsch — sind unabhängige Code-Bugs in beiden Discovery-Pfaden**

## Files Involved

- `ValetudoApp/ValetudoApp/Services/NWBrowserService.swift` — mDNS-Browser (Bug 1)
- `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift` — IP-Scan (Bug 2)
- `ValetudoApp/ValetudoApp/Views/AddRobotView.swift` — UI (kosmetisch ok, zeigt einfach das was die Services liefern)

## Current Focus

- hypothesis: Beide Bugs haben separate Root Causes in den Discovery-Services. Fix erfordert (a) korrekte mDNS-Hostname-Konstruktion aus TXT-`id` und (b) Valetudo-Identifikation per Header statt Status-Code.
- test: Live-`dns-sd` und `curl`-Probes durchgeführt, beide Ursachen verifiziert.
- expecting: Fix in beiden Services schließt beide Bugs.
- next_action: Apply fix
- reasoning_checkpoint: 
- tdd_checkpoint: 

## Evidence

- timestamp: 2026-04-29T12:25:55Z
  - `dns-sd -B _valetudo._tcp local.` zeigt zwei Services: `Valetudo CriticalMetallicMole`, `Valetudo DigitalSlowEchidna`
- timestamp: 2026-04-29T12:26:04Z
  - `dns-sd -L "Valetudo CriticalMetallicMole" _valetudo._tcp local.` →
    - Target: `valetudo-criticalmetallicmole.local.:80` (interface 11)
    - TXT: `id=CriticalMetallicMole model=S5\ Max manufacturer=Roborock version=2026.02.0`
- timestamp: 2026-04-29T12:26:08Z
  - `dns-sd -L "Valetudo DigitalSlowEchidna" _valetudo._tcp local.` →
    - Target: `valetudo-digitalslowechidna.local.:80`
    - TXT: `id=DigitalSlowEchidna model=S5\ Max manufacturer=Roborock version=2026.02.0 name=S5\ Max`
- timestamp: 2026-04-29T12:26:19Z
  - `dns-sd -G v4 valetudo-criticalmetallicmole.local.` → 192.168.0.40
- timestamp: 2026-04-29T12:26:27Z
  - `dns-sd -G v4 valetudo-digitalslowechidna.local.` → 192.168.0.35
- timestamp: 2026-04-29T12:26:42Z
  - `curl http://192.168.0.35/api/v2/robot` → HTTP 401, Header `X-Valetudo-Version: 2026.02.0`, `WWW-Authenticate: Basic`
  - `curl http://192.168.0.36/api/v2/robot` → HTTP 200, Content-Length: 0, **kein** `X-Valetudo-Version` Header (false positive)
  - `curl http://192.168.0.38/api/v2/robot` → Timeout
  - `curl http://192.168.0.40/api/v2/robot` → HTTP 401, Header `X-Valetudo-Version: 2026.02.0`, `WWW-Authenticate: Basic`
- timestamp: 2026-04-29T12:28:00Z
  - Code-Inspektion `NWBrowserService.swift:81` liest TXT-Key `"friendlyName"` — existiert nicht; Valetudo nutzt `name`
  - Code-Inspektion `NWBrowserService.swift:86` baut Host aus Service-Instanznamen statt TXT-`id`
  - Code-Inspektion `NetworkScanner.swift:167` filtert nur auf `statusCode == 200`

## Eliminated

- Hypothese 3 (gemeinsame Root Cause via DNS-Resolution-Failure) → die Bugs sind unabhängig.
- Off-by-one Range / `getLocalIPAddress` Bug → `NetworkScanner.swift:110 (1...254)` ist korrekt.

## Resolution

### Root Cause

**Bug 1 (mDNS-Hostname):** `NWBrowserService.swift` benutzt das Bonjour-Service-Instanznamen-Feld als Hostname. Der echte mDNS-Hostname von Valetudo ist `valetudo-<id-lowercased>.local`, ableitbar aus dem TXT-Record `id`. Zusätzlich liest der Code `friendlyName` aus dem TXT-Record, aber Valetudo emittiert `name`.

**Bug 2 (IP-Scan):** `NetworkScanner.swift:checkHost` akzeptiert nur HTTP 200. Valetudo-Roboter mit aktiver Basic Auth antworten mit HTTP 401. Der zuverlässige Identifikator ist der Antwort-Header `X-Valetudo-Version`, den jede Valetudo-Antwort (auch 401) enthält.

### Fix

**Bug 1 — `NWBrowserService.swift`:**
- TXT-Record-Schlüssel `id` lesen, mit `.lowercased()` zu `valetudo-<id>.local` zusammenbauen
- TXT-Record-Schlüssel `friendlyName` → `name` korrigieren
- Fallback auf bisherigen Service-Namen falls `id` fehlt

**Bug 2 — `NetworkScanner.swift:checkHost`:**
- Akzeptiere HTTP 200 ODER 401
- Verifiziere Identität über `X-Valetudo-Version` Header (case-insensitive)
- Bei 401 Header-Match: das ist ein echter Valetudo-Roboter
