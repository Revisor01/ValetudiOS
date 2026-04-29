---
phase: 33
name: App Store Screenshots — Overview
milestone: v4.0.0
created: 2026-04-12
updated: 2026-04-13
---

# Phase 33 — Plan-Übersicht

**Ziel:** Mindestens 18 Upload-fertige PNGs (9 Screens × DE+EN) im Design-Kanvas **1320×2868** (iPhone 6.9" Pro Max) für App Store Connect. Bonus: das Kit exportiert automatisch zusätzliche 6.5"/6.3"/6.1"-Größen aus demselben Design.

**Tooling:** ParthJadhav/app-store-screenshots Kit (Next.js + html-to-image). Pilot-Gate in Plan 01 entscheidet über Fortsetzung oder Fallback auf SwiftUI/ImageRenderer.

## Auflösungs-Konvention (KRITISCH — bitte nicht verwechseln)

| Was | Auflösung | Wo aufgenommen / verwendet |
|-----|-----------|----------------------------|
| **Design-Kanvas (Kit-Container, finale Asset-Größe)** | **1320×2868** (6.9") | Im Kit als Container-Dimension; finaler PNG-Export |
| **Source-Screenshot aus dem Simulator** | **1125×2436 (6.1"-Klasse)** | iPhone-16-Simulator (NICHT Pro Max) → `public/screenshots/{de,en}/NN-slug.png` |

**Begründung:** Das Kit designt bei 6.9" und skaliert intern auf kleinere Größen. Wenn wir 6.9"-Source-Screenshots reingeben, würden sie im Kit-Mockup nochmal skaliert (Doppelskalierung, Qualitätsverlust). Die Kit-README empfiehlt 6.1"-Capture explizit. Die in der Kit-RESEARCH genannte 6.9"-Source-Variante ist überholt.

**Hinweis:** Die exakte Pixelzahl des iPhone-16-Simulators kann je nach Xcode-Version 1170×2532 oder 1179×2556 betragen — alle 6.1"-Klassen-Auflösungen sind im Kit unproblematisch. 1125×2436 ist die nominelle Zielgröße aus CONTEXT.md.

## Plan-Reihenfolge

| Plan | Name | Abhängigkeit | Wave | Kern |
|------|------|--------------|------|------|
| 33-01 | Kit-Scaffold + Pilot-Screen + Go/No-Go-Gate | — | 1 | Setup, ein Pilot-Screen (Live-Karte) in DE+EN, Tooling-Entscheidung |
| 33-02 | Template + Lokalisierung + Slide-Definitionen | 33-01 | 2 | Reusable Template, alle 9 Screens als Definition (mit Placeholder-Screenshots für 2-9) |
| 33-03 | Source-Screenshots aus Simulator (18 PNGs) | 33-01 | 2 | App-Zustände, xcrun simctl Aufnahmen DE+EN, 9×2 = 18 Source-PNGs |
| 33-04 | Compose + Export aller 9 Screens | 33-02, 33-03 | 3 | Echte Source-Shots in Template einsetzen, alle Größen exportieren, Naming-Convention |
| 33-05 | Upload-Preparation + Handover | 33-04 | 4 | Validierung, Übergabe-Doc für App Store Connect |

**Wave-Erklärung:**
- **Wave 1:** 33-01 (Pilot-Gate — blockiert alles andere)
- **Wave 2:** 33-02 (Template-Architektur) und 33-03 (Simulator-Aufnahmen) parallel — sie modifizieren disjunkte Files
- **Wave 3:** 33-04 kombiniert beide Outputs (Template + Source-Shots)
- **Wave 4:** 33-05 finale Upload-Vorbereitung

## Deliverable-Map (Goal-Backward)

Das Phasen-Deliverable ist: **Mindestens 18 PNGs in `ValetudoApp/AppStore/screenshots/export/{de,en}/NN-slug.png`, jedes exakt 1320×2868, RGB, hochlade-fertig für App Store Connect.**

| Must-Have | Erzeugt in Plan |
|-----------|-----------------|
| Kit-Projekt existiert (`ValetudoApp/AppStore/screenshots/`) | 33-01 |
| Tooling-Entscheidung dokumentiert (Kit ODER SwiftUI-Fallback) | 33-01 |
| Pilot-Screen 1 als Proof-of-Concept in DE+EN gerendert (1320×2868) | 33-01 |
| Reusable Template + Slide-Definitionen für alle 9 Screens (inkl. Locale-Switch) | 33-02 |
| 18 Source-Screenshots aus Simulator (9 Screens × DE+EN, 1125×2436-Klasse) | 33-03 |
| 18 finale komponierte PNGs (1320×2868, sRGB) — optional zusätzliche Bonus-Größen | 33-04 |
| Upload-Ordner `export/de/` und `export/en/` mit konsistenter Naming-Convention | 33-04 |
| Validierungs-Pass + Handover-Dokument für App Store Connect | 33-05 |

## Pilot-Gate (Plan 01 Entscheidung)

Bewertungskriterien für Kit vs. SwiftUI-Fallback nach Pilot-Screen 1:
- SF-Pro-Rendering korrekt (keine Helvetica-Fallbacks)
- Gradient-Blobs mit sauberem Blur (keine Banding/Artefakte)
- Dynamic Island im Device-Mockup vorhanden
- Export-Qualität 1320×2868 ohne Skalierungsprobleme
- Headline-Typografie: Claim fett + Feature-Zeile regular klar lesbar

Wenn ≥2 Kriterien versagen → SwiftUI/ImageRenderer-Fallback aktivieren (Plans 02 und 04 müssen vor Ausführung umgeschrieben werden).

## Constraints

- **Source-Capture:** iPhone 16 Simulator (UDID: `D421F591-7696-411F-BFB1-C164C31163D3`), 6.1"-Klasse — NICHT Pro Max
- **Design-Kanvas:** 1320×2868 (Kit-Container)
- **App Bundle:** `de.simonluthe.ValetudiOS`
- **Statusbar:** via `xcrun simctl status_bar` auf 9:41, volles Signal, 100% Akku — vor JEDEM Shot
- **Logo-Farben:** `#56BDE3` (türkis), `#3B87F6` (blau), `#CEE7F6` (hellblau)
- **Kit-Installation:** `npx skills add ParthJadhav/app-store-screenshots -a claude-code` (NICHT git clone)
- **Sprachen:** DE + EN — FR explizit deferred
- **Devices:** iPhone-only — iPad explizit deferred
- **Keine neuen App-Features** — nur Asset-Produktion
- **Keine Screens zu deferred Features** — Manuelle Steuerung, Siri, Widget bleiben aus
