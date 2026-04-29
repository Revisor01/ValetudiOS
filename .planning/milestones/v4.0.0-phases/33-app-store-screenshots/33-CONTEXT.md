---
phase: 33
name: App Store Screenshots
milestone: v4.0.0
status: context_complete
created: 2026-04-13
updated: 2026-04-13
---

# Phase 33: App Store Screenshots — Context

## Domain

Produktionsreife App-Store-Screenshot-Assets für ValetudiOS — Sprachen Deutsch und Englisch, visueller Stil im Logo-Branding (blaue Gradient-Blobs, schlicht-dynamisch). Design-Kanvas: iPhone 6.9" (1320×2868); Export durch das Kit automatisch zusätzlich für 6.5" (1284×2778), 6.3" (1206×2622) und 6.1" (1125×2436). Output: bis zu 72 PNGs (9 Screens × 2 Sprachen × 4 Größen), minimal-upload-pflichtig sind die 9×2 6.9"-Assets; kleinere Größen als Bonus.

## Scope

**In:** Screen-Konzept, Tooling-Scaffold, Mock-Up-Template, Screenshot-Produktion aus iOS-Simulator, Rendering-Pipeline DE+EN, finale PNGs.

**Out:** iPad-Screenshots (App ist iPhone-only), FR-Screenshots (nachreichbar falls später relevant), App-Text-Listing (Phase 32), neue App-Features.

## Abgrenzung zu Phase 32

Phase 32 = Text (Titel, Untertitel, Keywords, Beschreibung, Review Notes).
Phase 33 = Visuelle Assets (die Screenshots selbst).

## Decisions

### Screen-Auswahl (9 Screens, Reihenfolge festgelegt)

1. **Live-Karte** — Roboter in Bewegung auf Live-Karte
2. **Karte bearbeiten** — Räume umbenennen, zuschneiden, teilen, verbinden (Hammer-Feature, differenzierend)
3. **GoTo-Orte** — Utility-Punkte (Mülleimer, Essbereich) speichern und anfahren — NICHT als "Lieblingsorte" framen
4. **Raumauswahl mit Reinigungsreihenfolge** — Räume antippen, nummerieren, losschicken
5. **Benachrichtigungen** — lokale Notifications (fertig, Hilfe gebraucht, Material knapp)
6. **Update-Flow** — Firmware-Updates direkt aus der App
7. **Roboter-Übersicht** — Dashboard mit mehreren Robotern
8. **Consumables** — Filter, Bürsten, Mop — Verschleiß tracken
9. **Volle Valetudo-Kontrolle** — "alle Settings, jede API, nativ als iOS"

**Ausgeschlossen (bewusst):**
- Manuelle Steuerung — Bug in aktiver Debug-Session, nicht vermarktbar bis verifiziert
- Siri-Integration — nicht sauber genug integriert
- Widget — existiert nicht in ValetudiOS

### Headlines (Hybrid-Stil: Claim + Feature-Zeile, du-Anrede, sprachspezifisch)

Tonalität: du-Anrede in DE, direkter/pointierter Stil in EN (keine 1:1-Übersetzung). Roboter als "er/he" — bewusst personalisiert, kumpelhaft-warm.

| # | Screen | DE Claim / Feature-Zeile | EN Claim / Feature-Zeile |
|---|--------|--------------------------|--------------------------|
| 1 | Live-Karte | "Live dabei." / Karte in Echtzeit — du siehst jeden Meter. | "Watch live." / Real-time map. Every move, as it happens. |
| 2 | Karte bearbeiten | "Deine Karte, deine Ordnung." / Räume umbenennen, zuschneiden, teilen, verbinden. | "Your map, your rules." / Rename, split, merge and reshape rooms. |
| 3 | GoTo-Orte | "Einmal tippen. Roboter fährt hin." / Orte wie Mülleimer oder Essbereich speichern und gezielt ansteuern. | "Tap a spot. He's there." / Save places like the trash bin or dining area and send him anytime. |
| 4 | Raumauswahl | "Reihenfolge? Du bestimmst." / Räume antippen, nummerieren, losschicken. | "You pick the order." / Tap rooms in sequence — he cleans them that way. |
| 5 | Benachrichtigungen | "Bleibt sauber, bleibt informiert." / Meldung wenn fertig, wenn Hilfe gebraucht wird, wenn Material knapp wird. | "Quiet until it matters." / Get notified when he's done, stuck, or running low. |
| 6 | Update-Flow | "Firmware frisch, ohne Cloud." / Updates sehen, prüfen, einspielen — direkt aus der App. | "Fresh firmware, no cloud." / See, check, and install updates — straight from the app. |
| 7 | Roboter-Übersicht | "Mehrere Roboter? Kein Problem." / Alle Geräte auf einen Blick, jeder mit eigenem Status. | "More than one? No problem." / All your robots, status at a glance. |
| 8 | Consumables | "Verschleiß im Blick." / Filter, Bürsten, Mop — sehen, was bald dran ist. | "Know what's wearing out." / Filters, brushes, mop — see what needs care. |
| 9 | Volle Valetudo-Kontrolle | "Alles was Valetudo kann. In deiner Hand." / Jede Einstellung, jede API — nativ als iOS-App. | "Everything Valetudo does. In your pocket." / Every setting, every API — native iOS. |

### Tooling

**Primary:** ParthJadhav/app-store-screenshots Kit (Next.js + Tailwind + html-to-image).
**Projekt-Ort:** `ValetudoApp/AppStore/screenshots/`
**Installation:** `npx skills add ParthJadhav/app-store-screenshots -a claude-code` (oder `-g` für global). Nicht manuell klonen.
**Mitgelieferte Assets:** `mockup.png` (vor-gemessener iPhone-Frame mit transparenter Screen-Area) — kein externes Device-Mockup nötig.
**Rationale:** 3.9k Stars, aktiv, auf Claude-Code-Agents optimiert, MIT-Lizenz. Agent scaffoldet Next.js-Projekt mit einer `page.tsx`, Export als PNG via html-to-image im Browser-Click. Bulk-Export über alle Locale/Device-Matrizen eingebaut.

**Theme-Preset-System:** Statt Hardcoding nutzen wir das Kit-Token-System. Ein Theme `logo-blue` mit unseren Logo-Farben `#56BDE3` / `#3B87F6` / `#CEE7F6`. Future-proof für spätere Alternativ-Themes (z.B. Dark, Feiertage).

**Fallback-Regel (wichtig):** Pilot-Screen (Screen 1) wird zuerst gebaut und bewertet, bevor die anderen 8 nachgezogen werden. Wenn das Kit bei Font-Rendering (SF Pro), Schatten, Gradient-Qualität oder Export-Artefakten hakt, wechseln wir ohne Gesichtsverlust zu SwiftUI + ImageRenderer. Learnings aus dem Kit (Layout, Copy, Asset-Struktur) sind Tool-agnostisch und übertragbar.

### Visueller Stil

- **Device-Frame:** Kit-mitgeliefertes `mockup.png` (vor-gemessener iPhone-Frame, transparente Screen-Area). Kein externes Asset nötig. Visuell prüfen ob Dynamic Island enthalten — falls nicht, im Pilot-Screen entscheiden ob wir mit dem Default weiter machen oder ein Custom-Mockup einsetzen.
- **Hintergrund:** Dezente Gradient-Blobs (2-3 Blobs, stark geblurrt), Palette aus Logo (türkis → blau → marine). Screenshot dominiert, Hintergrund als Texturebene.
- **Hintergrund-Variation:** Gleiche Palette über alle 9 Screens, aber leicht variierende Blob-Positionen/Farbmischungen — Brand-konsistent, aber beim Durchswipen lebendig, nicht monoton.
- **Typografie:** SF Pro (Apple-System-Font). Claim groß und fett, Feature-Zeile kleiner und regular darunter.
- **Statusbar:** Fake-Statusbar via `xcrun simctl status_bar` vor Simulator-Shot (9:41, volles Signal, volles Akku — Apple-Convention-Zeit).

### Source-Screenshots

- **Aus iOS-Simulator iPhone 6.1" (z.B. iPhone 16, 1125×2436) gezogen — NICHT 6.9".** Das Kit designt bei 6.9" (1320×2868) und skaliert auf kleinere Größen. Wenn Source-Shots in 6.9" liefern, würden sie im Template nochmal skaliert werden (Doppelskalierung, Qualitätsverlust). Die Kit-README empfiehlt explizit 6.1"-Capture, um spätere Anpassungen zu vermeiden.
- Simulator-Statusbar per `xcrun simctl status_bar … override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
- App in dem Zustand gescriptet/vorbereitet, der die jeweilige Funktion am besten zeigt (z.B. für Screen 4: mindestens 3 Räume mit Nummerierung sichtbar)
- Alle Shots aus realer App mit echten Daten — keine Fake-UI
- Ordnerstruktur für Kit: `public/screenshots/de/{screen}.png` und `public/screenshots/en/{screen}.png`

### Lokalisierung

- DE + EN im initialen Release
- FR explizit deferred (App unterstützt FR-Texte, aber FR-Screenshots sind nicht kritisch für Launch — später nachreichbar)
- Kein hardcoded Text in Screenshots außer den Headlines — App-interner Text kommt aus `Localizable.xcstrings` und wird per Simulator-Sprachwechsel pro Locale neu geshootet

## Deferred Ideas

- **FR-Screenshots:** Nach initialem Launch, wenn FR-Metrics Nachfrage zeigen
- **Manuelle-Steuerung-Screen:** Sobald der Bug aus der aktiven Debug-Session verifiziert ist und das Feature stabil läuft — könnte Screen 10 werden
- **Widget-Feature + Screenshot:** Widget existiert nicht; separate Feature-Phase nötig bevor Screenshot-Aufnahme sinnvoll ist
- **Siri-Screenshot:** Sobald Siri-Integration sauber ist (separate Phase)
- **iPad-Screenshots:** Sobald iPad-Layout existiert (separate Phase)
- **App Preview Video:** 15-30s-Video ist optional in App Store Connect — könnte später als separate Phase kommen

## Open Questions für Planning

1. **Source-Screenshot-Zustände pro Screen** — wie bringen wir die App reproduzierbar in den gewünschten State für jeden der 9 Shots? Pre-populated Debug-Build mit Seed-Data oder manuelles Setup-Script vor jedem Shot? (In Plan-Phase entscheiden.)
2. **Output-Naming-Convention** — Apple verlangt kein bestimmtes Schema. Vorschlag: `NN-screen-lang-size.png` (z.B. `01-live-map-de-6.9.png`). Im Planning bestätigen.
3. **Dynamic-Island-Handling** — falls Kit-mockup.png kein Dynamic Island hat, entscheiden wir im Pilot-Screen.

## Canonical Refs

- `.planning/ROADMAP.md` — Milestone v4.0.0, Phase 33 Eintrag
- `.planning/PROJECT.md` — Core Value, Feature-Liste
- `AppStoreMetadata/AppStoreTexts.md` — Phase 32 Output, Value-Claims für Headline-Inspiration
- `https://github.com/ParthJadhav/app-store-screenshots` — Tooling-Repo
- `https://developer.apple.com/design/resources/` — Apple Design Resources (Device-Mockups)
- Apple Human Interface Guidelines / App Store Connect Specifications (Screenshot-Formate)
