# Phase 27: Accessibility - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI Accessibility — VoiceOver labels, values, hints für iOS 17+
**Confidence:** HIGH

---

## Summary

Die App hat bisher fast keine Accessibility-Annotationen. Einzige Ausnahme: ein
`accessibilityLabel` auf dem HTTP-Schloss-Icon in `RobotStatusHeaderView`. Alle anderen
interaktiven Elemente — ControlButton, DockActionButton, Toolbar-Buttons, Reset-Buttons
in ConsumablesView — sind für VoiceOver blind oder werden mit ihrer SF-Symbol-Kennung
vorgelesen, was keinen Kontext liefert.

Die fünf Requirements verteilen sich auf exakt sechs Swift-Dateien. Keine neue Struktur
ist nötig — alle Änderungen sind reine Modifier-Ergänzungen in bestehenden Views.

**Primary recommendation:** Modifier `.accessibilityLabel(_:)` und `.accessibilityValue(_:)`
direkt in die betroffenen Structs eintragen; den Canvas der `InteractiveMapView` mit einem
einzigen `.accessibilityElement(children: .ignore)` plus `.accessibilityLabel` versehen.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| A11Y-01 | Alle ControlButtons und DockActionButtons haben `.accessibilityLabel` mit Aktionsbeschreibung | `ControlButton` in `RobotDetailSections.swift`, `DockActionButton` ebenda; beide haben `title`-Parameter der exakt als Label dient |
| A11Y-02 | Status-Header zeigt Batterie und Reinigungsstatus als `.accessibilityValue` | `RobotStatusHeaderView` — Battery-Pill und Status-Text sind separate HStack-Elemente; das Header-HStack braucht ein kombiniertes `.accessibilityElement(children: .combine)` oder ein explizites `.accessibilityValue` auf dem Status-Text |
| A11Y-03 | Consumable-Fortschrittsbalken haben `.accessibilityValue` mit Prozent | `ConsumableRow` in `ConsumablesView.swift` und `ConsumablesPreviewSectionView.swift` — beide nutzen `GeometryReader`-ZStack als Custom-ProgressBar ohne jede Accessibility-Annotation |
| A11Y-04 | Alle Icon-only-Buttons haben beschreibende Labels | Gefunden in: `TimersView` (+), `RobotListView` (+), `MapView.swift` (tag.fill / arrow.counterclockwise.circle.fill / xmark), `MapControlBarsView` (splitRoomBar reset-Button), `ConsumablesView` (arrow.counterclockwise.circle.fill) |
| A11Y-05 | Map-Canvas hat `.accessibilityElement` Summary-Label | `InteractiveMapView` — Canvas in `MapInteractiveView.swift`; kein Accessibility-Modifier vorhanden |
</phase_requirements>

---

## Betroffene Dateien — vollständige Übersicht

### 1. `Views/RobotDetailSections.swift` — ControlButton + DockActionButton

**ControlButton** (Zeilen 26–92):
- Struct hat `title: String` und `icon: String`
- Der Button-Body rendert `Image(systemName: icon)` + `Text(title)` — hat also sichtbaren Text
- VoiceOver liest beide, aber als "Pause, Taste" statt "Reinigung pausieren, Taste"
- **Fix:** `.accessibilityLabel(title)` auf den Button, damit der title die Aktion klar benennt.
  Da `title` bereits lokalisiert übergeben wird (z. B. `String(localized: "action.pause")`),
  braucht es nur den Modifier auf die Button-Ebene.

**DockActionButton** (Zeilen 300–326):
- Identische Struktur: `title` + `icon`, rendert Text sichtbar
- **Fix:** identisch — `.accessibilityLabel(title)` auf den Button

**Verwendung in `RobotControlSectionView.swift`:**
```swift
// Zeile 12–53: ControlButton Pause/Start/Resume/Stop/Home
// Zeile 172–186: DockActionButton Empty/Clean/Dry
```
Keine Änderung in der Verwendungsstelle nötig — Fix gehört in den Struct selbst.

### 2. `Views/Detail/RobotStatusHeaderView.swift` — A11Y-02

**Betroffene Elemente:**
- Status-Text (Zeile 15–24): `localizedStatus(statusValue)` — wird als `"Cleaning, Text"` vorgelesen
- Battery-Pill (Zeile 71–86): `Image(systemName: batteryIcon(...))` + `Text("\(battery)%")`
- Locate-Button (Zeile 55–68): `Image(systemName: "waveform")` — **Icon-only-Button ohne Label**

**Fix-Strategie:** Das gesamte Header-HStack als kombiniertes Accessibility-Element behandeln.
Alternativ: status-Text als primäres Element mit `.accessibilityValue` für Battery.

Konkret empfohlen:
```swift
// Auf dem Status-Text:
.accessibilityLabel(String(localized: "robot.status"))
.accessibilityValue(localizedStatus(statusValue))

// Auf der Battery-Pill:
.accessibilityLabel(String(localized: "robot.battery"))
.accessibilityValue("\(battery)%")

// Locate-Button:
.accessibilityLabel(String(localized: "action.locate"))
```

### 3. `Views/ConsumablesView.swift` — A11Y-03 + A11Y-04

**ConsumableRow** (Zeilen 92–152):
- Custom-ProgressBar (GeometryReader-ZStack) hat kein Accessibility-Attribut
- Reset-Button (Zeile 134–141): `Image(systemName: "arrow.counterclockwise.circle.fill")` — Icon-only

**Fix:**
```swift
// Auf dem GeometryReader/ZStack (die ProgressBar):
.accessibilityLabel(consumable.displayName)
.accessibilityValue(String(format: "%d%%", Int(consumable.remainingPercent)))

// Auf dem Reset-Button:
.accessibilityLabel(String(localized: "consumables.reset_button \(consumable.displayName)"))
```

### 4. `Views/Detail/ConsumablesPreviewSectionView.swift` — A11Y-03 + A11Y-04

**Identisches Problem:** GeometryReader-ZStack (Zeile 27–34) ohne Accessibility.
Reset-Button (Zeile 47–57): `Image(systemName: "arrow.counterclockwise")` — Icon-only.

**Fix:** analog zu ConsumableRow.

### 5. `Views/MapInteractiveView.swift` — A11Y-05

**Canvas** (Zeilen 38–132):
- `Canvas { context, size in ... }` — ein SwiftUI Canvas rendert ausschließlich via Core Graphics,
  VoiceOver sieht ihn als ein leeres, nicht interaktives Element
- Tap-Targets-Overlay (Zeile 151–195): Diese SwiftUI-Buttons (Raum-Label-Chips) SIND bereits
  als Button erkennbar, aber ohne `.accessibilityLabel`

**Fix für den Canvas selbst:**
```swift
Canvas { ... }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(String(localized: "map.accessibility_label"))
    .accessibilityHint(String(localized: "map.accessibility_hint"))
```

**Fix für Tap-Target-Buttons (Room-Chips):**
```swift
Button { toggleSegment(info.id) } label: { ... }
    .accessibilityLabel(info.name)
    .accessibilityHint(isSelected
        ? String(localized: "map.room_deselect_hint")
        : String(localized: "map.room_select_hint"))
```

### 6. Icon-only-Buttons ohne Label — A11Y-04

Vollständige Fundstellen:

| Datei | Zeile | Icon | Aktion |
|-------|-------|------|--------|
| `RobotStatusHeaderView.swift` | 56–68 | `waveform` | Roboter lokalisieren |
| `ConsumablesView.swift` | 134–141 | `arrow.counterclockwise.circle.fill` | Verbrauchsmaterial zurücksetzen |
| `ConsumablesPreviewSectionView.swift` | 47–57 | `arrow.counterclockwise` | Verbrauchsmaterial zurücksetzen |
| `TimersView.swift` | 46–50 | `plus` | Timer hinzufügen |
| `RobotListView.swift` | 46–51 | `plus` | Roboter hinzufügen |
| `MapView.swift` | 309–316 | `tag` / `tag.fill` | Raumlabels ein-/ausblenden |
| `MapView.swift` | 318–327 | `arrow.counterclockwise.circle.fill` | Kartenansicht zurücksetzen |
| `MapView.swift` | 363–369 | `xmark` | Karte schließen |
| `MapControlBarsView.swift` | 493–500 | `arrow.counterclockwise` | Splitlinie zurücksetzen |
| `MapOverlayViews.swift` | 102–118 | `xmark` | Virtuelle Wand löschen |
| `MapOverlayViews.swift` | 127–143 | `xmark` | No-Go-Zone löschen |
| `MapOverlayViews.swift` | 152–168 | `xmark` | No-Mop-Zone löschen |

**Hinweis zu MapOverlayViews:** Die drei `xmark`-Delete-Buttons befinden sich in
`restrictionDeleteOverlay` und sind kontextuell unterschiedlich — jeder braucht ein
spezifisches Label (z. B. "Virtuelle Wand löschen", "No-Go-Zone löschen").

---

## Architecture Patterns

### SwiftUI Accessibility — relevante Modifier

**`.accessibilityLabel(_:)`**
Ersetzt den automatisch generierten Namen. Pflicht für alle Icon-only-Buttons.
```swift
// Source: Apple Developer Documentation — Accessibility in SwiftUI
Image(systemName: "plus")
    .accessibilityLabel(String(localized: "timers.add"))
```
Confidence: HIGH

**`.accessibilityValue(_:)`**
Liefert den aktuellen Zustand/Wert eines Elements (z. B. Prozent, Status).
```swift
progressBar
    .accessibilityValue("\(Int(percent))%")
```
Confidence: HIGH

**`.accessibilityElement(children: .ignore)`**
Macht einen Container zu einem einzigen Accessibility-Element. Kinder werden
von VoiceOver nicht einzeln traversiert. Richtig für Canvas, da keine Kinder
existieren die sinnvoll vorgelesen werden könnten.
```swift
Canvas { ... }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Karte")
```
Confidence: HIGH

**`.accessibilityElement(children: .combine)`**
Fasst alle Child-Texte zu einem einzigen Element zusammen. Gut für einfache
HStack-Kombinationen (z. B. Battery-Pill: Icon + Prozentzahl).
Confidence: HIGH

**Auf Button-Ebene vs. Label-Ebene**
`.accessibilityLabel` auf dem `Button` selbst — nicht auf dem `Image` innerhalb des Labels.
VoiceOver liest "Button, [label]" wenn der Modifier auf Button sitzt.
Confidence: HIGH

### ControlButton / DockActionButton — Empfohlenes Muster

Da beide Structs bereits `title: String` haben und der title die Aktion beschreibt,
ist der Fix minimal: einen einzigen Modifier auf den Button, der den title verwendet.

```swift
// In ControlButton.body:
Button {
    Task { await action() }
} label: {
    VStack { ... }
}
.accessibilityLabel(title)   // NEU — title ist bereits lokalisiert
```

Dieser Ansatz ist vorzuziehen gegenüber einem Modifier an der Verwendungsstelle,
weil alle zukünftigen Verwendungen automatisch korrekt sind.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Prozent-String für accessibilityValue | Eigenen Formatter | `String(format: "%d%%", Int(percent))` reicht |
| Lokalisierte Accessibility-Strings | Separate Datei | In bestehende `.xcstrings` eintragen |
| Custom ProgressView für Accessibility | Eigenes Widget | `.accessibilityValue` auf bestehende Custom-Bar |

---

## Common Pitfalls

### Pitfall 1: Label auf Image statt auf Button
**Was passiert:** `.accessibilityLabel` auf `Image(systemName:)` inside Button label angewendet.
VoiceOver liest dann "Bild" statt "Taste".
**Vermeidung:** Modifier immer auf den `Button`, nie auf die `Image` innerhalb des Labels.
**Warnsignal:** Wenn der Button sagt "Bild, [label]" statt "[label], Taste".

### Pitfall 2: Canvas mit children: .combine
**Was passiert:** `children: .combine` auf Canvas — SwiftUI versucht Kinder zu aggregieren,
die der Canvas gar nicht hat, ergibt leeres Element.
**Vermeidung:** Für Canvas immer `children: .ignore` plus explizites Label.

### Pitfall 3: accessibilityValue ohne accessibilityLabel
**Was passiert:** VoiceOver liest den value, aber ohne Label fehlt der Kontext.
**Vermeidung:** Immer zuerst `.accessibilityLabel`, dann optional `.accessibilityValue`.

### Pitfall 4: Lokalisierungskeys vergessen
**Was passiert:** Accessibility-Strings werden hartkodiert statt lokalisiert.
**Vermeidung:** Neue Strings (z. B. `"map.accessibility_label"`, `"action.locate"`)
direkt in `Localizable.xcstrings` eintragen bevor sie im Code verwendet werden.

---

## Code Examples

### ControlButton mit accessibilityLabel (A11Y-01)
```swift
// Source: RobotDetailSections.swift — Body des Button
Button {
    Task { await action() }
} label: {
    VStack(spacing: 4) {
        Image(systemName: icon)
            .font(.title2)
        Text(title)
            .font(.caption2)
    }
    // ...
}
.accessibilityLabel(title)  // title bereits lokalisiert
```

### RobotStatusHeaderView — Status + Battery (A11Y-02)
```swift
// Status-Text
Text(localizedStatus(statusValue))
    .accessibilityLabel(String(localized: "robot.status"))
    .accessibilityValue(localizedStatus(statusValue))

// Battery-Pill
HStack(spacing: 4) { ... }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "robot.battery"))
    .accessibilityValue("\(battery)%\(isCharging ? ", \(String(localized: "battery.charging"))" : "")")
```

### ConsumableRow ProgressBar (A11Y-03)
```swift
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
        RoundedRectangle(cornerRadius: 4)
            .fill(progressColor)
            .frame(width: geometry.size.width * consumable.remainingPercent / 100)
    }
}
.frame(height: 8)
.accessibilityLabel(consumable.displayName)
.accessibilityValue(String(format: "%d%%", Int(consumable.remainingPercent)))
```

### Canvas (A11Y-05)
```swift
Canvas { context, size in
    // ... Zeichenlogik
}
.accessibilityElement(children: .ignore)
.accessibilityLabel(String(localized: "map.canvas_label"))
// Beispiel-String: "Grundriss des Hauses mit Roboterposition"
```

### Icon-only Toolbar-Button (A11Y-04)
```swift
Button {
    viewModel.showRoomLabels.toggle()
} label: {
    Image(systemName: viewModel.showRoomLabels ? "tag.fill" : "tag")
}
.accessibilityLabel(viewModel.showRoomLabels
    ? String(localized: "map.hide_room_labels")
    : String(localized: "map.show_room_labels"))
```

---

## Lokalisierungsschlüssel die neu erstellt werden müssen

Folgende Keys existieren noch nicht in der App und müssen in `Localizable.xcstrings`
angelegt werden:

| Key | Verwendung |
|-----|-----------|
| `robot.status` | accessibilityLabel für Status-Text |
| `robot.battery` | accessibilityLabel für Battery-Pill |
| `battery.charging` | Teil des accessibilityValue bei Laden |
| `action.locate` | accessibilityLabel Locate-Button im Header |
| `consumables.reset_button` | accessibilityLabel Reset-Button (mit Parametrisierung) |
| `map.canvas_label` | accessibilityLabel für InteractiveMapView Canvas |
| `map.room_select_hint` | accessibilityHint für Raum-Tap-Targets |
| `map.room_deselect_hint` | accessibilityHint für Raum-Tap-Targets (ausgewählt) |
| `map.show_room_labels` | accessibilityLabel tag-Button (Labels ausgeblendet) |
| `map.hide_room_labels` | accessibilityLabel tag-Button (Labels sichtbar) |
| `map.reset_view` | accessibilityLabel Zurücksetzen-Button |
| `map.close` | accessibilityLabel xmark-Button in MapView |
| `map.reset_split_line` | accessibilityLabel Zurücksetzen-Button splitRoomBar |
| `timers.add` | accessibilityLabel plus-Button in TimersView |
| `robots.add_robot` | accessibilityLabel plus-Button in RobotListView |
| `map.delete_virtual_wall` | accessibilityLabel xmark für virtuelle Wand |
| `map.delete_nogo_zone` | accessibilityLabel xmark für No-Go-Zone |
| `map.delete_nomop_zone` | accessibilityLabel xmark für No-Mop-Zone |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest + XCUITest |
| Config file | `ValetudoApp.xcodeproj` |
| Quick run command | Nicht automatisiert — VoiceOver-Tests erfordern manuelles Testen auf Gerät |
| Full suite command | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated? |
|--------|----------|-----------|------------|
| A11Y-01 | ControlButton/DockActionButton haben accessibilityLabel | UI-Test (XCUITest `accessibilityLabel`) | Teilweise automatisierbar |
| A11Y-02 | Status-Header liest Status + Battery vor | VoiceOver manuell | Manuell |
| A11Y-03 | Consumable-Balken haben accessibilityValue mit "%" | UI-Test | Teilweise automatisierbar |
| A11Y-04 | Icon-only-Buttons haben Labels | UI-Test | Automatisierbar |
| A11Y-05 | Canvas hat Summary-Label | UI-Test | Automatisierbar |

**Empfehlung:** Accessibility Inspector in Xcode (Product > Accessibility Inspector) zum
Verifizieren der Labels während der Implementierung. Kein separates Test-File nötig — die
Phase ist eine reine Modifier-Ergänzung, die im Accessibility Inspector sofort sichtbar ist.

### Wave 0 Gaps
- Keine neuen Test-Files nötig
- Accessibility Inspector in Xcode als primäres Verifikationstool
- Neue Lokalisierungsschlüssel müssen vor Code-Änderungen angelegt werden

---

## Environment Availability

Schritt 2.6: SKIPPED (nur Code/Konfigurations-Änderungen, keine externen Abhängigkeiten)

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — Accessibility in SwiftUI (direkte Framework-Kenntnis, iOS 17)
- Codebase-Analyse — alle sechs betroffenen Dateien vollständig gelesen

### Secondary (MEDIUM confidence)
- SwiftUI Accessibility WWDC-Muster: `accessibilityElement(children:)` für Canvas

---

## Metadata

**Confidence breakdown:**
- Betroffene Dateien: HIGH — vollständige Codebase gelesen
- Modifier-API: HIGH — Standard SwiftUI iOS 17
- Lokalisierungsschlüssel-Liste: HIGH — aus Code abgeleitet
- VoiceOver-Verhalten des Canvas: MEDIUM — Canvas-Accessibility nicht im Simulator vollständig testbar ohne physisches Gerät

**Research date:** 2026-04-04
**Valid until:** 2026-05-04
