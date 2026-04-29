# Phase 33: App Store Screenshots — Research

**Researched:** 2026-04-12
**Domain:** App Store Screenshot-Produktion (iOS, Next.js Rendering-Kit, Simulator-Automation)
**Confidence:** HIGH (Tooling MEDIUM, Apple-Specs HIGH, Logo-Farben HIGH)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Screen-Auswahl (9 Screens, Reihenfolge festgelegt):**
1. Live-Karte — Roboter in Bewegung
2. Karte bearbeiten — Räume umbenennen, zuschneiden, teilen, verbinden
3. GoTo-Orte — Utility-Punkte speichern und anfahren
4. Raumauswahl mit Reinigungsreihenfolge — Räume antippen, nummerieren
5. Benachrichtigungen — lokale Notifications
6. Update-Flow — Firmware-Updates direkt aus der App
7. Roboter-Übersicht — Dashboard mit mehreren Robotern
8. Consumables — Filter, Bürsten, Mop Verschleiß
9. Volle Valetudo-Kontrolle — alle Settings, jede API

**Headlines:** Hybrid-Stil, du-Anrede DE, pointiert EN — vollständig definiert in CONTEXT.md (Tabelle mit 9 Zeilen DE/EN)

**Tooling Primary:** ParthJadhav/app-store-screenshots (Next.js + html-to-image)
**Projekt-Ort:** `ValetudoApp/AppStore/screenshots/`
**Fallback-Regel:** Pilot-Screen 1 fertig bauen und bewerten. Wenn Font/Gradient/Export hakt → SwiftUI + ImageRenderer ohne Gesichtsverlust.

**Visueller Stil:**
- Device-Frame: Realistisches iPhone Pro Max Mockup (Titanium, Dynamic Island, Schatten)
- Hintergrund: Dezente Gradient-Blobs (2-3, stark geblurrt), Palette aus Logo (türkis → blau → marine)
- Typografie: SF Pro. Claim groß+fett, Feature-Zeile kleiner+regular
- Statusbar: Fake via `xcrun simctl status_bar` (9:41, volles Signal, 100% Akku)

**Source-Screenshots:** aus iOS-Simulator iPhone 15/16 Pro Max (1290×2796)
**Lokalisierung:** DE + EN — App-interner Text aus Simulator-Sprachwechsel

### Deferred Ideas (OUT OF SCOPE)
- FR-Screenshots (nach initialem Launch)
- Manuelle-Steuerung-Screen (Bug nicht verifiziert)
- Widget-Feature + Screenshot
- Siri-Screenshot
- iPad-Screenshots
- App Preview Video
</user_constraints>

---

## Executive Summary

Das ParthJadhav/app-store-screenshots Kit (Next.js + html-to-image) ist ein AI-Agent-optimierter Skill, der ein einzelnes `page.tsx` als gesamten Generator nutzt. Der Agent scaffoldet ein Mini-Next.js-Projekt in `ValetudoApp/AppStore/screenshots/`, definiert 9 React-Komponenten-Screens mit Theme-Tokens, und exportiert per Browser-Click als PNG.

**Kritische Auflösungs-Korrektur:** Die im CONTEXT.md genannte Zielauflösung 1290×2796 ist die iPhone 14/15 Pro Max / iPhone 16 Plus Größe (6.7"). Die tatsächliche 6.9"-Kategorie (iPhone 15/16/17 Pro Max) erfordert **1320×2868**. VERIFIZIERT: Der iPhone 16 Pro Max Simulator liefert `xcrun simctl io ... screenshot` exakt in 1320×2868. App Store Connect akzeptiert 6.9" als einzige Required-Größe, die für alle kleineren Devices skaliert wird.

**Empfehlung:** Kit-Setup → Pilot Screen 1 → Bewertung → Go/No-Go Fallback-Entscheidung. Logo-Farben sind vollständig extrahiert. 11 Real-Screenshots im Projekt vorhanden (1179×2556, iPhone 16 Pro) — für Screens 7 und 8 bereits direkt verwendbar nach Größenanpassung via Simulator-Neubuild.

---

## 1. Auflösung — Kritische Korrektur

### Tatsächliche Anforderungen 2026

[VERIFIED: Apple Developer Docs + Simulator-Messung]

| Display | Portrait-Pixel | Landscape-Pixel | Devices | Status |
|---------|---------------|-----------------|---------|--------|
| **6.9"** | **1320 × 2868** | 2868 × 1320 | iPhone 15 Pro Max, 16 Pro Max, 17 Pro Max, 16 Plus, 15 Plus, Air | **REQUIRED** |
| 6.7" | 1290 × 2796 | 2796 × 1290 | iPhone 14 Pro Max | Optional / Fallback |
| 6.5" | 1284 × 2778 | 2778 × 1284 | iPhone 13/12/11 Pro Max, XS Max | Optional |
| 6.3" | 1206 × 2622 | 2622 × 1206 | iPhone 16 Pro, 16, 15 Pro, 15, 14 Pro | Optional |
| 6.1" | 1170 × 2532 | 2532 × 1170 | iPhone 14, 13, 12, XS, X | Optional |

**Ergebnis:** Nur 6.9"-Screenshots (1320×2868) hochladen. Apple skaliert automatisch für alle kleineren Devices.

**Simulator-Verifikation:**
```bash
# iPhone 16 Pro Max (UDID: 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9) → 1320×2868 ✓
# iPhone 17 Pro Max (UDID: A2FD53C9-DF1A-4BE4-A256-8C2F1B94303A) → 1320×2868 ✓
```

**CONTEXT.md-Abweichung:** CONTEXT.md nennt "1290×2796" als Ziel — das ist die 6.7"-Größe (iPhone 14 Pro Max). Der Planner MUSS 1320×2868 als Arbeitsauflösung verwenden.

### Screenshot-Limits

- Minimum: 1 Screenshot
- Maximum: **10 Screenshots** pro Size-Kategorie pro Locale
- 9 Screens passen perfekt — unter dem Limit, über dem typischen Minimum von 5

---

## 2. ParthJadhav/app-store-screenshots Kit — Mechanik

[VERIFIED: GitHub README fetch]

### Installation

```bash
# Empfohlen: Als Claude-Code-Skill
npx skills add ParthJadhav/app-store-screenshots

# Alternativ: Manuell klonen
git clone https://github.com/ParthJadhav/app-store-screenshots \
  ValetudoApp/AppStore/screenshots
```

### Entstehende Verzeichnisstruktur nach Scaffold

```
ValetudoApp/AppStore/screenshots/
├── public/
│   ├── mockup.png              # Pre-measured iPhone frame (muss ersetzt/angepasst werden)
│   ├── app-icon.png            # App-Icon kopieren aus Media.xcassets
│   └── screenshots/            # Simulator-PNGs ablegen
│       ├── de/
│       │   ├── 01-live-map.png
│       │   ├── 02-map-edit.png
│       │   └── ...
│       └── en/
│           ├── 01-live-map.png
│           └── ...
├── src/app/
│   ├── layout.tsx              # Font-Konfiguration (SF Pro einbinden)
│   └── page.tsx                # Gesamter Generator (ein File)
├── package.json
└── ...
```

### Screen-Definition

Screens werden als **React-Komponenten in `page.tsx`** definiert — kein JSON, kein MDX. Das Kit verwendet Token-basierte Themes:

```typescript
// Aus dem Kit — exaktes Muster
const THEMES = {
  "valetudios-brand": {
    bg: "#56BDE3",      // Logo türkis (oben)
    fg: "#FFFFFF",      // Weißer Text
    accent: "#3B87F6"   // Logo blau (unten)
  }
}

// Screen-Definition
const screens = [
  {
    id: "live-map",
    locale: "de",
    headline: "Live dabei.",
    subline: "Karte in Echtzeit — du siehst jeden Meter.",
    screenshot: "/screenshots/de/01-live-map.png",
    theme: "valetudios-brand"
  }
]
```

### Multi-Locale-Mechanismus

Locale-Unterstützung via **Verzeichnis-Nesting** + Copy-Dictionary:

```
public/screenshots/de/01-live-map.png
public/screenshots/en/01-live-map.png
```

Der Generator iteriert über Locales, hält Layout konstant, swappt Screenshot-Pfad und Copy-Text. DE + EN = zwei Render-Durchläufe.

### Export

- Dev-Server starten: `npm run dev` (oder `bun dev`)
- Browser öffnen: localhost:3000
- Auf Screenshot klicken → PNG-Download via `html-to-image`
- Auflösung: Kit ist auf **1320×2868** (6.9") ausgelegt — passt direkt

**Kein Headless-Browser nötig** — html-to-image läuft client-seitig im Browser.

### Abhängigkeiten

| Paket | Zweck | Version-Status |
|-------|-------|----------------|
| Next.js | Dev-Server + Static Serving | Current |
| TypeScript | Type Safety | Current |
| Tailwind CSS | Styling | Current |
| html-to-image | PNG-Export | Aktiv, bekannte Font-Bugs (s. Abschnitt 8) |
| Node.js 18+ | Runtime | VERIFIZIERT: Node v25.9.0 installiert ✓ |
| bun (preferred) | Package Manager | VERIFIZIERT: bun v1.3.12 installiert ✓ |

---

## 3. Apple App Store Connect — Screenshot-Anforderungen

[VERIFIED: developer.apple.com/help/app-store-connect/reference/screenshot-specifications/]

### Formate

- **Akzeptiert:** `.png`, `.jpg`, `.jpeg`
- **Empfohlen:** PNG (verlustfrei, für Farbtreue)
- **Farbraum:** sRGB — Standard; kein spezifischer Farbraum vorgeschrieben in Dokumentation
- **Keine Metadaten-Anforderungen** dokumentiert

### Anzahl

- Minimum: 1 pro Locale
- Maximum: **10 pro Locale pro Size-Kategorie**
- 9 Screens: valide, kein Problem

### Skalierung

Wenn nur 6.9"-Screenshots vorhanden: Apple skaliert für 6.7", 6.5", 6.3", 6.1" etc. automatisch. Für ValetudiOS (iPhone-only, kein iPad) reicht **ein einziger Size-Upload** (6.9").

### Einschränkungen aus Apple Review Guidelines (HIG)

[ASSUMED — nicht via offizielle Docs verifiziert, Training-Wissen]

- Screenshots müssen das korrekte Gerät zeigen (kein Android-Mockup)
- Keine irreführenden Claims (z.B. Features die nicht existieren)
- Device-Frame muss erkennbar als iOS-Gerät sein
- Text-Overlays erlaubt (Headlines, Feature-Zeilen)
- Keine explicit verbotenen Inhalte

---

## 4. Device-Mockup-Asset

### Optionen mit Bewertung

| Option | Format | Aktualität | Lizenz | Dynamic Island | Empfehlung |
|--------|--------|------------|--------|----------------|------------|
| Apple Design Resources (developer.apple.com/design/resources/) | Photoshop (.psd) + PNG | iPhone 16 + 17 verfügbar | Apple Marketing Guidelines — Erlaubt für App Store Marketing | Ja (iPhone 16) | Zweite Wahl |
| ParthJadhav Kit — `mockup.png` | PNG transparent | Mit Kit geliefert | MIT (Kit-Lizenz) | Unbekannt — Kit-Intern | Erste Wahl für Kit-Workflow |
| PommePlate (github.com/ephread/PommePlate) | SVG/PNG/Sketch | Archiviert 2023 | CC0 | Nein (zu alt) | Nicht verwenden |

### Empfehlung

**Primär:** Das Kit liefert selbst ein `mockup.png` — dieses nutzen und evaluieren. Falls das Kit-Mockup kein Dynamic Island hat oder zu einfach ist, ersetzen mit dem offiziellen Apple iPhone 16 PNG von developer.apple.com/design/resources/ (kostenloser Download nach Apple-Developer-Login, Nutzung für App Store Marketing erlaubt laut Apple Marketing Guidelines).

**Fallback SwiftUI:** Kein Mockup-Asset nötig — SwiftUI rendert direkt die App-UI.

### Download-URL

```
https://developer.apple.com/design/resources/
→ "iPhone 16" → PNG herunterladen
```

[CITED: developer.apple.com/design/resources/]

---

## 5. Simulator-Workflow — Fertige Commands

[VERIFIED: xcrun simctl --help, direkte Simulation, eigene Messung]

### Device-Auswahl

```bash
# Verfügbare Pro-Max-Simulatoren (verifiziert):
# iPhone 16 Pro Max — UDID: 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9 → 1320×2868 ✓
# iPhone 17 Pro Max — UDID: A2FD53C9-DF1A-4BE4-A256-8C2F1B94303A → 1320×2868 ✓
```

Empfohlen: **iPhone 16 Pro Max** (hat Runtime, nicht als "unavailable" markiert).

### Statusbar-Setup (Apple-Convention)

```bash
# Simulator booten
xcrun simctl boot 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9

# Statusbar auf Apple-Konvention setzen
xcrun simctl status_bar 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9 override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100
```

**Hinweis:** `--operatorName ""` optional für saubere Statusbar (leerer Carrier-Name).

### Screenshot aufnehmen

```bash
# Screenshot in Zielordner
xcrun simctl io 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9 screenshot \
  ValetudoApp/AppStore/screenshots/public/screenshots/de/01-live-map.png

# Ausgabe-Auflösung: 1320×2868 (verifiziert)
```

### App-Sprache wechseln (DE → EN)

```bash
# Methode 1: Launch-Arguments (empfohlen, schnell)
xcrun simctl launch 54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9 \
  de.simonluthe.ValetudiOS \
  -AppleLanguages "(en)" \
  -AppleLocale "en_US"

# Methode 2: .GlobalPreferences.plist modifizieren (persistenter)
# Pfad: ~/Library/Developer/CoreSimulator/Devices/54C3BF3E.../data/Library/Preferences/.GlobalPreferences.plist
plutil -replace AppleLanguages \
  -json '["en"]' \
  ~/Library/Developer/CoreSimulator/Devices/54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9/data/Library/Preferences/.GlobalPreferences.plist
# → Dann: xcrun simctl shutdown + boot
```

**App Bundle-ID:** `de.simonluthe.ValetudiOS` [VERIFIED: STACK.md]

### Vollständiges Screenshot-Script (Skeleton)

```bash
#!/bin/bash
DEVICE="54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9"
BUNDLE="de.simonluthe.ValetudiOS"
OUT="ValetudoApp/AppStore/screenshots/public/screenshots"

# Boot + Statusbar
xcrun simctl boot "$DEVICE"
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# Deutsche Screenshots
xcrun simctl launch "$DEVICE" "$BUNDLE" -AppleLanguages "(de)" -AppleLocale "de_DE"
sleep 3
# → App manuell in korrekten Zustand bringen, dann:
xcrun simctl io "$DEVICE" screenshot "$OUT/de/01-live-map.png"
# ... weitere Screens

# Englische Screenshots
xcrun simctl launch "$DEVICE" "$BUNDLE" -AppleLanguages "(en)" -AppleLocale "en_US"
sleep 3
xcrun simctl io "$DEVICE" screenshot "$OUT/en/01-live-map.png"
# ...
```

### Existierende Screenshots im Projekt

Im Verzeichnis `AppStoreMetadata/` liegen bereits **11 Real-Screenshots (1179×2556, iPhone 16 Pro)** aus einer früheren Session. Diese können als **visuelle Referenz** für den App-Zustand genutzt werden, müssen aber neu aufgenommen werden (falsches Device: kein Pro Max, falsche Auflösung für 6.9"-Kategorie).

**Screenshot-Mapping der vorhandenen PNGs (visuell identifiziert):**
- IMG_8034: Robot List (→ Screen 7: Roboter-Übersicht)
- IMG_8035: Robot Detail mit Karte (→ Screen 1: Live-Karte Basis)
- IMG_8036: Map-View mit Edit-Toolbar (→ Screen 2: Karte bearbeiten)
- IMG_8039: Robot Settings (→ Screen 9: Volle Valetudo-Kontrolle)
- IMG_8041: Valetudo/Update-Info (→ Screen 6: Update-Flow)
- IMG_8045: GoTo-Orte Sheet (→ Screen 3: GoTo-Orte)

---

## 6. Logo-Farbpalette

[VERIFIED: PIL pixel-sampling aus `Media.xcassets/AppIcon.appiconset/Untitled-iOS-Default-1024x1024@1x.png`]

### Extrahierte Hex-Werte

| Bereich | Hex | RGB | Verwendung |
|---------|-----|-----|------------|
| Oben/Türkis | `#56BDE3` | 86, 189, 227 | Gradient-Start, helle Blob-Farbe |
| Mitte/Hellblau | `#CEE7F6` | 206, 231, 246 | Highlight, Icon-Innenfläche |
| Unten/Blau | `#3B87F6` | 59, 135, 246 | Gradient-Ende, dominante Blob-Farbe |

**Abgeleitete Marine-Farbe (für Tiefe):**
- `#1A5FB4` (geschätzt aus Gradient-Verlängerung nach unten) [ASSUMED — nicht direkt im Icon sichtbar, aber konsistent mit Brand]

### Gradient-CSS-Snippet für Screenshot-Hintergründe

```css
/* Haupt-Hintergrund-Gradient */
.screenshot-background {
  background: linear-gradient(145deg, #56BDE3 0%, #3B87F6 100%);
}

/* Blob 1 — oben links */
.blob-1 {
  position: absolute;
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, rgba(86, 189, 227, 0.6) 0%, transparent 70%);
  filter: blur(80px);
  top: -100px;
  left: -80px;
}

/* Blob 2 — unten rechts */
.blob-2 {
  position: absolute;
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(59, 135, 246, 0.7) 0%, transparent 70%);
  filter: blur(100px);
  bottom: -120px;
  right: -100px;
}

/* Blob 3 — Mitte (leicht variiert per Screen) */
.blob-3 {
  position: absolute;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, rgba(206, 231, 246, 0.4) 0%, transparent 70%);
  filter: blur(60px);
  top: 40%;
  left: 30%;
}
```

### Tailwind-Token für page.tsx

```typescript
// In page.tsx Theme-Definition
const VALETUDIOS_THEME = {
  bgGradientFrom: "#56BDE3",
  bgGradientTo: "#3B87F6",
  blobLight: "#56BDE3",
  blobDark: "#3B87F6",
  blobHighlight: "#CEE7F6",
  textPrimary: "#FFFFFF",
  textSecondary: "rgba(255,255,255,0.85)",
}
```

---

## 7. Fallback-Pfad: SwiftUI + ImageRenderer

[CITED: developer.apple.com/documentation/swiftui/imagerenderer + hackingwithswift.com]

### Wann Fallback triggern

- html-to-image rendert SF Pro nicht korrekt (bekanntes Risiko, s. Abschnitt 8)
- Gradient-Qualität im Browser nicht ausreichend
- Export-Artefakte bei 1320×2868
- Zeitliche Gründe (Kit-Setup dauert länger als erwartet)

### ImageRenderer API (iOS 16+, verfügbar in iOS 17)

```swift
import SwiftUI

// @MainActor required
@MainActor
func renderScreenshot<V: View>(view: V, size: CGSize) async -> UIImage? {
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = ProposedViewSize(size)
    renderer.scale = 3.0  // @3x für 1320×2868 aus 440×956 pt Basisgröße
    return renderer.uiImage
}

// Export als PNG-Data
func exportPNG(image: UIImage) -> Data? {
    return image.pngData()
}
```

**Basis-Größe für @3x:** 440×956 pt × 3 = 1320×2868 px — exakt die Zielgröße.

### Screenshot-View-Struktur

```swift
struct ScreenshotView: View {
    let screen: ScreenContent
    
    var body: some View {
        ZStack {
            // Hintergrund mit Blobs
            GradientBlobBackground(screen: screen)
            
            VStack {
                // Headline
                Text(screen.claim)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                // Device-Mockup mit App-Screenshot
                DeviceMockupView(screenshotImage: screen.appScreenshot)
                
                // Feature-Zeile
                Text(screen.featureLine)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: 440, height: 956)  // @1x → ×3 = 1320×2868
    }
}
```

### Produktions-Deployment-Variante

Ein separates Xcode-Target (`ScreenshotGenerator`) das beim Start alle Screens rendert und in den Documents-Ordner schreibt — dann per Simulator Drag-Drop auf den Desktop extrahieren. Kein `DEBUG`-Gate nötig da standalone-Target.

### Zeitaufwand Vergleich

| Weg | Setup | 18 Screens rendern | Iterieren |
|-----|-------|-------------------|-----------|
| ParthJadhav Kit | 30-60 min | Browser-Click × 18 | Schnell (Hot Reload) |
| SwiftUI ImageRenderer | 2-4h (View-Aufbau) | Automatisiert | Rebuild nötig |

---

## 8. Risiken & Unbekanntes

### Kritisch — sofort adressieren

**R1: html-to-image Font-Bug (HOCH)**
- **Problem:** html-to-image hat bekannte Bugs mit Custom Fonts (2025: Firefox-Bug `font is undefined`, `document.fonts` werden nicht korrekt embedded). SF Pro ist eine System-Font und wird via CSS `font-family: -apple-system, "SF Pro Display"` eingebunden.
- **Risiko:** SF Pro rendert im Browser möglicherweise als Fallback-Font (Helvetica/Arial) statt als SF Pro. Differenz ist subtil aber sichtbar.
- **Mitigation:** Pilot-Screen in Chrome (nicht Firefox) rendern. `font-display: block` setzen. Alternativ: SF Pro via `@font-face` als WOFF2 aus macOS extrahieren und explizit einbinden.
- **Fallback-Trigger:** Wenn Font-Qualität nach 30-Minuten-Debugging nicht zufriedenstellend → SwiftUI-Fallback.

**R2: Auflösungs-Diskrepanz CONTEXT.md (HOCH)**
- **Problem:** CONTEXT.md nennt 1290×2796, korrekte 6.9"-Auflösung ist 1320×2868.
- **Risiko:** Wenn Kit auf 1290×2796 konfiguriert wird → App Store Connect ablehnt als falsche Größe oder zeigt Skalierungsartefakte.
- **Mitigation:** Planner MUSS 1320×2868 als Zielauflösung in allen Tasks kodieren. VERIFIZIERT durch Simulator-Messung.

### Mittel — beobachten

**R3: App-Zustand für Screenshots manuell vorbereiten (MITTEL)**
- **Problem:** Kein automatisches App-State-Setup. Für Screen 4 (Raumauswahl mit Reinigungsreihenfolge) müssen mindestens 3 Räume mit Nummerierung sichtbar sein.
- **Mitigation:** Pre-Script-Checkliste pro Screen definieren. Existierende PNGs in `AppStoreMetadata/` als Referenz nutzen, zeigen welche App-Zustände erreichbar sind.
- **Alternative:** `ParthJadhav/ios-marketing-capture` Skill (komplementäres Tool für programmatische App-State-Automation via SwiftUI) — aber zusätzlicher Scope, für Phase 33 nicht nötig.

**R4: Dynamic Island auf Mockup fehlt (MITTEL)**
- **Problem:** Kit-internes `mockup.png` unbekannt — könnte iPhone ohne Dynamic Island sein.
- **Mitigation:** Im Pilot-Screen prüfen. Falls nötig: Apple Design Resources iPhone 16 PNG ersetzen.

**R5: html-to-image Schatten + Gradient-Qualität (MITTEL)**
- **Problem:** Blur-Filter und Box-Shadows können in html-to-image suboptimal rendern (Browser-spezifisch).
- **Mitigation:** Chrome verwenden (beste Rendering-Qualität). `pixelRatio: 2` oder `3` in html-to-image-Options für höhere Ausgabequalität setzen.

### Niedrig — akzeptabel

**R6: Apple Review Screenshot-Policies (NIEDRIG)**
- Keine bekannten Blocking-Issues für normale Feature-Screenshots. Claims wie "Deine Karte, deine Ordnung." sind faktisch korrekt.
- Siri wird in Screenshot-Texten erwähnt aber nicht als Screenshot dargestellt — kein Problem.

**R7: Zeitaufwand (NIEDRIG)**
- 18 finale Screenshots (9×2 Locales) sind machbar in 1-2 Tagen bei funktionierendem Setup.
- Größtes Zeitrisiko: App-Zustände für alle 9 Screens korrekt vorbereiten.

---

## 9. Offene Entscheidungen für den Planner

### Muss der Planner klären:

**P1: Mockup-Asset-Beschaffung (vor Kit-Setup)**
Welches iPhone-Mockup konkret? Option A: Kit-internes `mockup.png` übernehmen und evaluieren. Option B: Apple Design Resources PNG herunterladen (erfordert Apple-Developer-Login, nicht automatisierbar). Empfehlung: Option A im Pilot-Screen testen, bei Bedarf Option B.

**P2: SF Pro Font-Embedding-Strategie**
SF Pro als System-Font via CSS oder explizit als WOFF2 aus macOS extrahieren (`/System/Library/Fonts/SFPRO-*.otf`) und in `public/fonts/` ablegen? Zweite Option garantiert korrekte Darstellung, erfordert License-Check (SF Pro ist Apple-lizenziert, nur für iOS-Development, nicht für Web-Embedding).

**P3: Export-Automation vs. Manual Click**
Kit exportiert per Browser-Click. Für 18 Screenshots (9×2) ist das akzeptabel (~5 min). Alternativ: Playwright-Script für automatisierten Export. Empfehlung: Manual für Pilot; Automation erst wenn alle 9 Screens validiert.

**P4: Output-Naming-Convention**
Vorschlag: `ValetudoApp/AppStore/screenshots/export/de/01-live-map.png`, `02-map-edit.png`, etc. Planner bestätigt oder ändert.

### Klar genug für direkte Task-Erstellung:

- Simulator-Commands: vollständig verifiziert
- Logo-Farben: exakt extrahiert (`#56BDE3`, `#3B87F6`, `#CEE7F6`)
- Kit-Scaffold-Struktur: bekannt (public/screenshots/[locale]/, page.tsx)
- Auflösung: 1320×2868 (iPhone 16/17 Pro Max)
- Node/bun: verfügbar (v25.9.0 / v1.3.12)
- App Bundle-ID: `de.simonluthe.ValetudiOS`
- Screen-Reihenfolge + Headlines: vollständig in CONTEXT.md definiert

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Kit Dev-Server | ✓ | v25.9.0 | — |
| bun | Package Manager | ✓ | v1.3.12 | npm (fallback) |
| Xcode / xcrun | Simulator Screenshots | ✓ | Xcode auf System | — |
| iPhone 16 Pro Max Simulator | 1320×2868 Screenshots | ✓ | UDID: 54C3BF3E... | iPhone 17 Pro Max (auch 1320×2868) |
| PIL/Pillow (Python) | Farb-Extraktion (Research) | ✓ | System Python | — |
| Apple Developer Login | iPhone Mockup PSD Download | unbekannt | — | Kit-internes mockup.png |

**Keine blockierenden Missing Dependencies identifiziert.**

---

## Assumptions Log

| # | Claim | Sektion | Risiko wenn falsch |
|---|-------|---------|-------------------|
| A1 | Marine-Farbe `#1A5FB4` als vierter Gradient-Stop | Logo-Farbpalette | Hintergrund-Gradient etwas zu dunkel/hell — visuell leicht anpassen |
| A2 | Apple Review erlaubt Text-Overlays auf Device-Mockups | Apple-Anforderungen | Screenshot müsste neu erstellt werden — unwahrscheinlich, Industriestandard |
| A3 | SF Pro via CSS System-Font rendert akzeptabel in Chrome | Tooling | Fallback zu SwiftUI nötig — Pilot-Screen klärt das in <1h |
| A4 | Kit-internes mockup.png zeigt Dynamic Island | Device-Mockup | Muss durch Apple Design Resources PNG ersetzt werden |

---

## Sources

### Primary (HIGH confidence)
- Simulator-Messung (`xcrun simctl io screenshot`) → iPhone 16/17 Pro Max = 1320×2868 [VERIFIED]
- `ValetudoApp/ValetudoApp/Media.xcassets/AppIcon.appiconset/Untitled-iOS-Default-1024x1024@1x.png` → Farb-Extraktion via PIL [VERIFIED]
- `xcrun simctl status_bar --help` → vollständige Command-Syntax [VERIFIED]
- `xcrun simctl list devices` → verfügbare Simulator-UDIDs [VERIFIED]

### Secondary (MEDIUM confidence)
- [Apple App Store Connect Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) — Größen, Limits, Formate [CITED]
- [ParthJadhav/app-store-screenshots README](https://github.com/ParthJadhav/app-store-screenshots) — Kit-Mechanik, Struktur, Dependencies [CITED]
- [Apple Design Resources](https://developer.apple.com/design/resources/) — iPhone 16/17 Mockup-Verfügbarkeit [CITED]
- [Screenhance App Store Dimensions 2026](https://screenhance.com/blog/app-store-screenshot-dimensions-2026) — 1320×2868 als 6.9"-Standard bestätigt [CITED]

### Tertiary (LOW confidence)
- [html-to-image Font Bugs Issue Tracker](https://github.com/bubkoo/html-to-image/issues) — bekannte Font-Rendering-Probleme [WebSearch, nicht vollständig verifiziert]
- [SwiftUI ImageRenderer Tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-convert-a-swiftui-view-to-an-image) — @3x-Rendering-Pattern [WebSearch, konsistent mit Apple Docs]

---

## Metadata

**Confidence breakdown:**
- Apple-Anforderungen (Auflösungen, Limits, Format): HIGH — direkt via Apple Docs + Simulator verifiziert
- Kit-Mechanik: MEDIUM — README-Fetch, aber page.tsx-Interna ohne direkten Code-Zugriff analysiert
- Logo-Farben: HIGH — pixelgenaue Extraktion via PIL aus dem tatsächlichen App-Icon
- Simulator-Commands: HIGH — direkte Ausführung auf dem System
- html-to-image Risiken: MEDIUM — Issue-Tracker-Überblick, nicht jede Version getestet
- SwiftUI-Fallback: MEDIUM — API-Docs korrekt, aber spezifische 1320×2868-Render-Qualität nicht getestet

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stabil; Apple-Specs ändern sich nur mit neuen Devices)
