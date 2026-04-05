# Phase 25: View Architecture - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI View Decomposition, MVVM with @Observable, iOS 17+
**Confidence:** HIGH

## Summary

Phase 25 zielt darauf ab, alle View-Dateien unter 400 Zeilen zu halten, indem drei grosse Dateien aufgeteilt werden. Die Analyse zeigt drei klar abgegrenzte Aufgaben: (1) RobotDetailView.swift (1.210 Zeilen) muss seine inline-ViewBuilder-Properties in eigenständige Structs auslagern, (2) RobotSettingsSections.swift (1.079 Zeilen) enthält bereits eigenständige Structs, die nur noch in separate Dateien verschoben werden müssen, (3) MapContentView in MapView.swift (863 Zeilen) hat View-lokale Gesture/Layout-State-Properties, die konzeptuell gesehen view-bound bleiben sollten — die Datei muss stattdessen durch Auslagerung von Sub-Views verkleinert werden.

Die bestehende Architektur folgt bereits MVVM mit `@Observable` (iOS 17). Die Decomposition-Strategie ist damit klar: Keine ViewModel-Logik verändert sich. Es werden nur View-Structs extrahiert und Dateien umorganisiert. Alle drei Views verwenden `RobotManager` via `@Environment`, was bei Sub-Views entweder weitergeleitet oder direkt verwendet werden kann.

**Primäre Empfehlung:** Jede `@ViewBuilder private var`-Property in RobotDetailView wird ein eigenständiger Struct unter `Views/Detail/`. Die sechs Structs in RobotSettingsSections.swift werden eins-zu-eins in Dateien unter `Views/Settings/` verschoben. MapContentView wird durch Extraktion der Gesture-Handler-Overlays auf unter 400 Zeilen reduziert.

## Aktuelle Zeilenzahlen (verifiziert)

| Datei | Zeilen | Status |
|-------|--------|--------|
| RobotDetailView.swift | 1.210 | Muss aufgeteilt werden |
| RobotSettingsSections.swift | 1.079 | Muss aufgeteilt werden |
| MapView.swift (enthält MapContentView) | 863 | Muss aufgeteilt werden |
| RoomsManagementView.swift | 693 | Muss aufgeteilt werden |
| MapInteractiveView.swift | 630 | Muss aufgeteilt werden |
| MapControlBarsView.swift | 594 | Muss aufgeteilt werden |
| RobotSettingsView.swift | 507 | Muss aufgeteilt werden |
| SettingsView.swift | 394 | Knapp unter Grenze — kein Handlungsbedarf |
| TimersView.swift | 338 | OK |
| RobotDetailSections.swift | 326 | OK |

**Alle Dateien uber 400 Zeilen (7 Stück):** RobotDetailView, RobotSettingsSections, MapView, RoomsManagementView, MapInteractiveView, MapControlBarsView, RobotSettingsView.

Die Requirements VIEW-01, VIEW-02, VIEW-03 adressieren RobotDetailView, RobotSettingsSections und MapContentView (in MapView.swift). Die anderen Dateien uber 400 Zeilen (RoomsManagementView, MapInteractiveView, MapControlBarsView, RobotSettingsView) sind nicht im Scope von Phase 25.

---

## VIEW-01: RobotDetailView.swift Analyse

**Aktuelle Struktur (1.210 Zeilen, ein einziger Struct mit Extensions):**

Die View hat einen Hauptstruct `RobotDetailView` plus zwei Extension-Blöcke. Alle Sections sind `@ViewBuilder private var` Properties (kein eigenständiger Struct). Das Ziel ist, jede Section in einen eigenständigen Struct auszulagern.

### Identifizierte Sections und ihre Zeilen

| Section / Property | Zeilen (ca.) | Vorgeschlagener Struct | Datei |
|-------------------|--------------|------------------------|-------|
| Update Status Banner (5 Zustände: updateAvailable, downloading, readyToApply, inProgress, error + fallback) | 153 | `UpdateStatusBannerView` | Views/Detail/UpdateStatusBannerView.swift |
| updateOverlayView + Hilfsfunktionen (updateOverlayTitle/Subtitle) | 40 | `UpdateOverlayView` | Views/Detail/UpdateOverlayView.swift |
| compactStatusHeader + localizedStatus/statusColor/batteryIcon/batteryColor | 120 | `RobotStatusHeaderView` | Views/Detail/RobotStatusHeaderView.swift |
| controlSection (Buttons + Intensitäts-Menüs + Dock-Actions) | 189 | `RobotControlSectionView` | Views/Detail/RobotControlSectionView.swift |
| liveStatsChip + PulseAnimation | 44 | `LiveStatsChipView` | Views/Detail/LiveStatsChipView.swift |
| attachmentChips + attachmentChip(icon:label:attached:) | 57 | `AttachmentChipsView` | Views/Detail/AttachmentChipsView.swift |
| consumablesPreviewSection | 71 | `ConsumablesPreviewSectionView` | Views/Detail/ConsumablesPreviewSectionView.swift |
| statisticsSection + statisticRow + iconForStatType/colorForStatType/labelForStatType/formattedValue | 146 | `StatisticsSectionView` | Views/Detail/StatisticsSectionView.swift |
| roomsSection | 105 | `RoomsSectionView` | Views/Detail/RoomsSectionView.swift |
| eventsSection | 40 | `EventsSectionView` | Views/Detail/EventsSectionView.swift |
| cleanRouteSection | 20 | Teil von `RobotControlSectionView` oder eigenständig | Views/Detail/CleanRouteSectionView.swift |
| obstaclesSection | 25 | `ObstaclesSectionView` | Views/Detail/ObstaclesSectionView.swift |
| displayNameForOperationMode + iconForOperationMode | 19 | in `RobotControlSectionView` verschieben | — |

### Abhängigkeiten der extrahierten Structs

Jede Sub-View benötigt mindestens:
- `let viewModel: RobotDetailViewModel` (als `@Bindable` oder normale let-Eigenschaft je nach Bedarf)
- Für Sections, die async Actions auslösen: Binding oder Closure-Parameter
- `UpdateStatusBannerView` braucht zusätzlich `showUpdateWarning: Binding<Bool>`
- `RobotControlSectionView` braucht `displayNameForOperationMode` und `iconForOperationMode` — diese können als private Funktionen in den neuen Struct wandern
- `RobotStatusHeaderView` braucht `localizedStatus`, `statusColor`, `batteryIcon`, `batteryColor` — diese wandern in den neuen Struct

### RobotDetailView nach Extraktion (Zielzustand)

Nach Extraktion enthält RobotDetailView.swift nur noch:
- Struct-Definition mit @State, @Environment, init (ca. 22 Zeilen)
- var body: Orchestrierung der Sub-Views (ca. 70 Zeilen mit Modifiers)
- showUpdateOverlay computed property (ca. 10 Zeilen)
- Gesamtziel: ~150-180 Zeilen

---

## VIEW-02: RobotSettingsSections.swift Analyse

**Aktuelle Struktur (1.079 Zeilen, 6 eigenständige Structs in einer Datei):**

Die Structs sind bereits vollständig eigenständig und voneinander unabhängig. Es wird nur eine Dateitrennung benötigt — keine Code-Änderung an den Structs selbst.

### Structs und ihre Zeilenbereiche

| Struct | Zeilen (Start-Ende) | Grösse | Zieldatei |
|--------|---------------------|--------|-----------|
| AutoEmptyDockSettingsView | 7–81 | 75 | Views/Settings/AutoEmptyDockSettingsView.swift |
| QuirksView | 84–192 | 109 | Views/Settings/QuirksView.swift |
| WifiSettingsView | 195–408 | 214 | Views/Settings/WifiSettingsView.swift |
| MQTTSettingsView | 411–585 | 175 | Views/Settings/MQTTSettingsView.swift |
| NTPSettingsView | 587–772 | 186 | Views/Settings/NTPSettingsView.swift |
| StationSettingsView | 774–1079 | 306 | Views/Settings/StationSettingsView.swift |

**Wichtig:** Der `private let sectionsLogger = Logger(...)` am Anfang der Datei (Zeile 4) muss in jede neue Datei kopiert werden (oder per datei-lokalem Logger ersetzt werden). Jede neue Datei braucht `import SwiftUI` und `import os`.

**Nach der Aufteilung:** RobotSettingsSections.swift kann komplett gelöscht werden. StationSettingsView existiert bereits als NavigationLink-Ziel in RobotDetailView — der Import-Pfad ändert sich nicht (gleiche Target-Membership).

### Bereits bestehende Situation

`StationSettingsView` wird in RobotDetailView.swift direkt referenziert (Zeile 240: `StationSettingsView(robot:)`). Nach dem Verschieben in eine eigene Datei bleibt diese Referenz valide, da XcodeGen alle `.swift`-Dateien in `ValetudoApp/` globwise einbindet (keine explizite Dateilliste in project.yml).

---

## VIEW-03: MapContentView / MapView.swift Analyse

**Aktuelle Struktur von MapView.swift (863 Zeilen, 4 Structs):**

| Struct | Zeilen (ca.) | Status |
|--------|-------------|--------|
| RestrictionIdentifier | 17–28 | Zu klein, bleibt |
| MapTabView | 30–48 | 19 Zeilen, bleibt |
| MapPreviewView | 50–169 | 120 Zeilen, bleibt |
| MapContentView | 171–834 | ~664 Zeilen — muss reduziert werden |
| MapView | 836–863 | 28 Zeilen, bleibt |

### @State-Properties in MapContentView (aktuell, Zeilen 177-192)

```swift
@State var viewModel: MapViewModel          // ViewModel — bleibt in View
@State var scale: CGFloat = 1.0             // Gesture-lokal
@State var lastScale: CGFloat = 1.0         // Gesture-lokal
@State var offset: CGSize = .zero           // Gesture-lokal
@State var lastOffset: CGSize = .zero       // Gesture-lokal
@State var currentDrawStart: CGPoint?       // Gesture/Drawing-lokal
@State var currentDrawEnd: CGPoint?         // Gesture/Drawing-lokal
@State var isDraggingSplitStart = false     // Gesture-lokal
@State var isDraggingSplitEnd = false       // Gesture-lokal
@State var currentViewSize: CGSize = .zero  // Layout-lokal
```

### Analyse: Was gehört wohin?

**Bleiben als @State in View (rein view-bound, frame-abhängig):**
- `scale`, `lastScale`, `offset`, `lastOffset` — diese sind direkte CGAffineTransform-Parameter des `.scaleEffect()` / `.offset()` Modifiers. Sie sind vollständig view-gebunden und an die Render-Pipeline geknüpft.
- `currentDrawStart`, `currentDrawEnd`, `isDraggingSplitStart`, `isDraggingSplitEnd` — Gesture-Koordinaten in Screen Space. Diese existieren nur während einer aktiven Geste und sind frame-dependent.
- `currentViewSize` — GeometryReader-Output, rein view-bound.

**Fazit für VIEW-03:** Die @State-Properties in MapContentView sind korrekt als View-State modelliert und sollten NICHT in MapViewModel verschoben werden. MapViewModel enthält bereits den richtigen State (editMode, drawnZones, etc.). Das Requirements-Ziel "MapContentView State-Properties sind in MapViewModel migriert" bezieht sich wahrscheinlich auf einen älteren Zustand der Datei — oder auf eine konzeptuelle Migration, die bereits stattgefunden hat.

**Wie wird MapContentView dennoch unter 400 Zeilen reduziert?**

MapContentView enthält mehrere grosse `@ViewBuilder private func`-Blöcke, die extrahiert werden können:

Aus der Analyse des Body und der Extension-Methoden in MapControlBarsView.swift:
- `drawingOverlay(geometry:)` — Zeichn-Overlay für Zonen/Wände/GoTo
- `splitLineHandles(geometry:)` — Drag-Handles für Room-Split
- Gesture-Definitionen (pinch, drag, tap) — können in eine `MapGestureView` oder als separate ViewModifier ausgelagert werden
- Die Koordinaten-Hilfsfunktionen `screenToMapCoords`, `mapToScreenCoords`, `calculateMapParams` sind bereits gut isoliert

**Empfohlene Extraktion für MapView.swift:**

| Zu extrahierender Block | Zieldatei |
|------------------------|-----------|
| `drawingOverlay(geometry:)` + `splitLineHandles(geometry:)` | bereits teilweise in MapControlBarsView.swift |
| GoTo/Preset-Marker-Rendering | `MapMarkerOverlayView` (neue Datei oder in MapInteractiveView integrieren) |
| Koordinaten-Utilities (`screenToMapCoords`, etc.) | in MapViewModel oder eigene Utility-Struct |
| `updateGestureCoords` / Drag-Gesten-Handler | Bleiben inline, sind Closures |

**Konkrete Zielgrösse:** MapContentView von ~664 auf ca. 320 Zeilen reduzieren, indem der GoTo-Marker-Block (~100 Zeilen) und die Preset-Marker-Anzeige (~60 Zeilen) in MapControlBarsView.swift oder eine neue Datei wandern.

---

## Architecture Patterns

### SwiftUI Sub-View Extraktion — Standardmuster

**Was:** `@ViewBuilder private var` in eigenständigen Struct auslagern.

**Wann:** Wenn ein Block mehr als ~50 Zeilen hat und eigenständig wiederverwendbar oder testbar ist.

**Muster für abhängige Sub-Views:**

```swift
// Vorher (in RobotDetailView):
@ViewBuilder
private var consumablesPreviewSection: some View {
    if !viewModel.consumables.isEmpty {
        Section { ... }
    }
}

// Nachher — Sub-View mit ViewModel-Referenz:
struct ConsumablesPreviewSectionView: View {
    let viewModel: RobotDetailViewModel
    
    var body: some View {
        if !viewModel.consumables.isEmpty {
            Section { ... }
        }
    }
}

// Aufruf in RobotDetailView:
ConsumablesPreviewSectionView(viewModel: viewModel)
```

Da `RobotDetailViewModel` mit `@Observable` annotiert ist, kann es als plain `let` weitergegeben werden — SwiftUI trackt automatisch die verwendeten Properties.

### Async Action Weitergabe

Sections, die async Actions ausführen (z.B. `viewModel.performAction(.start)`), können das ViewModel direkt erhalten:

```swift
struct RobotControlSectionView: View {
    let viewModel: RobotDetailViewModel  // @Observable — kein @Bindable nötig wenn nur Lesen + Tasks
    
    var body: some View {
        Section {
            Button { Task { await viewModel.performAction(.start) } } label: { ... }
        }
    }
}
```

Für Properties, die direkt per `$viewModel.property` gebunden werden (z.B. in Picker), muss `@Bindable` verwendet werden:

```swift
struct RobotControlSectionView: View {
    @Bindable var viewModel: RobotDetailViewModel
    // Ermöglicht: Binding(get: { viewModel.foo }, set: { viewModel.foo = $0 })
}
```

### XcodeGen File Groups

Das `project.yml` verwendet `sources: - ValetudoApp` (Verzeichnis-basiert). XcodeGen liest alle `.swift`-Dateien rekursiv ein. Neue Unterverzeichnisse wie `Views/Detail/` oder `Views/Settings/` werden automatisch als Xcode Group erkannt — keine Änderung an `project.yml` nötig. Xcode regeneriert das Projekt via `xcodegen generate`.

### Gemeinsamer Logger-Import

Jede Settings-Datei aus RobotSettingsSections.swift braucht einen Logger:

```swift
import os
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudoApp", category: "AutoEmptyDockSettingsView")
```

Der bisherige `sectionsLogger` wird durch dateispezifische Logger ersetzt.

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Verwenden |
|---------|-------------------|-----------|
| Datei-Gruppen in Xcode | Manuelle xcodeproj-Bearbeitung | XcodeGen `xcodegen generate` nach Ordner-Erstellung |
| @Observable Binding in Sub-Views | Manuelles `@Binding` für alle Properties | `@Bindable var viewModel: ViewModel` |
| View-State Migration | Alles in ViewModel packen | Nur echter App-State in ViewModel, Gesture/Layout-State bleibt in View |

---

## Common Pitfalls

### Pitfall 1: @Observable Sub-View Tracking verloren
**Was geht schief:** Sub-View erhält ViewModel als `let`, aber SwiftUI trackt Änderungen nicht korrekt.
**Warum:** Bei `@Observable` muss SwiftUI die Property-Zugriffe innerhalb von `body` beobachten. Das funktioniert nur, wenn das ViewModel direkt (nicht als Kopie) übergeben wird.
**Vermeidung:** ViewModel als `let viewModel: RobotDetailViewModel` übergeben (Referenztyp, `@Observable` ist eine class). Kein Wrapper wie `@StateObject` nötig, da die View das ViewModel nicht besitzt.
**Warnung:** Wenn eine Sub-View einen `Binding<X>` braucht und X im ViewModel liegt, `@Bindable var viewModel` verwenden.

### Pitfall 2: XcodeGen nicht neu ausgeführt
**Was geht schief:** Neue Dateien in neuen Unterordnern sind nicht im Xcode-Projekt sichtbar.
**Warum:** Das `.xcodeproj` wird von XcodeGen generiert — manuell erstellte Dateien in neuen Ordnern erscheinen erst nach `xcodegen generate`.
**Vermeidung:** Nach dem Erstellen neuer Unterordner immer `xcodegen generate` aus dem `ValetudoApp/`-Verzeichnis ausführen.

### Pitfall 3: sectionsLogger in mehrere Dateien nicht angepasst
**Was geht schief:** Logger-Kategorie in allen Settings-Dateien heisst "RobotSettingsSections".
**Warum:** Der gemeinsame Logger wurde ohne Anpassung kopiert.
**Vermeidung:** Jeden neuen Logger mit der Struct-spezifischen `category` versehen.

### Pitfall 4: StationSettingsView doppelt vorhanden
**Was geht schief:** `StationSettingsView` existiert in RobotSettingsSections.swift. Es gibt aber bereits einen `NavigationLink` zu `StationSettingsView` in RobotDetailView.
**Warum:** Wenn beim Verschieben eine neue Datei erstellt wird, aber die alte nicht gelöscht, kompiliert Xcode nicht.
**Vermeidung:** RobotSettingsSections.swift nach dem Aufteilen vollständig löschen (nicht nur den Inhalt leeren).

### Pitfall 5: MapContentView @State-Properties fälschlich in ViewModel verschoben
**Was geht schief:** `scale`, `offset`, `currentDrawStart` etc. in MapViewModel migriert — Map springt beim Neuaufbau des Views zurück auf Startzustand.
**Warum:** Diese Properties sind Gesture/Layout-State, der an die View-Lebensdauer gebunden ist. ViewModel lebt länger als die View.
**Vermeidung:** Diese Properties in der View belassen. Die Requirements meinen vermutlich bereits-migrierte State aus einer früheren Phase, oder beziehen sich auf andere Properties, die inzwischen schon in MapViewModel sind.

---

## Standard Stack

### Core (bereits im Projekt, keine Änderungen)
| Technologie | Version | Zweck |
|-------------|---------|-------|
| Swift | 5.9 | Sprache |
| SwiftUI | iOS 17+ | UI-Framework |
| @Observable | iOS 17+ | State-Management |
| XcodeGen | 2.x | Projektdatei-Generierung |

**Keine externen Dependencies.** Keine Packages werden hinzugefügt.

---

## Verzeichnisstruktur (Ziel)

```
ValetudoApp/
└── Views/
    ├── Detail/                        (NEU)
    │   ├── UpdateStatusBannerView.swift
    │   ├── UpdateOverlayView.swift
    │   ├── RobotStatusHeaderView.swift
    │   ├── RobotControlSectionView.swift
    │   ├── LiveStatsChipView.swift
    │   ├── AttachmentChipsView.swift
    │   ├── ConsumablesPreviewSectionView.swift
    │   ├── StatisticsSectionView.swift
    │   ├── RoomsSectionView.swift
    │   ├── EventsSectionView.swift
    │   ├── CleanRouteSectionView.swift
    │   └── ObstaclesSectionView.swift
    ├── Settings/                      (NEU)
    │   ├── AutoEmptyDockSettingsView.swift
    │   ├── QuirksView.swift
    │   ├── WifiSettingsView.swift
    │   ├── MQTTSettingsView.swift
    │   ├── NTPSettingsView.swift
    │   └── StationSettingsView.swift
    ├── RobotDetailView.swift          (stark reduziert, ~150 Zeilen)
    ├── RobotSettingsSections.swift    (gelöscht nach Aufteilung)
    ├── MapView.swift                  (reduziert, <400 Zeilen)
    └── [alle anderen Views bleiben]
```

---

## Environment Availability

Step 2.6: SKIPPED — Reine Code/Refactoring-Änderungen, keine externen Dependencies.

XcodeGen ist im Projekt bereits im Einsatz (project.yml vorhanden). Kein neues Tooling nötig.

---

## Validation Architecture

Validation ist per `workflow.nyquist_validation: false` deaktiviert — diese Sektion wird übersprungen.

---

## Open Questions

1. **RoomsManagementView, MapInteractiveView, MapControlBarsView, RobotSettingsView sind ebenfalls uber 400 Zeilen**
   - Was wir wissen: Diese Dateien sind 507–693 Zeilen, aber nicht explizit in VIEW-01/02/03 erwähnt.
   - Was unklar: Sind diese im Scope von Phase 25 (Success Criteria sagen "keine View-Datei uber 400 Zeilen") oder explizit ausgeschlossen?
   - Empfehlung: Success Criteria sagen "keine View-Datei überschreitet 400 Zeilen" — das impliziert, dass alle 7 Dateien angegangen werden müssen, auch wenn die Requirements nur drei explizit nennen.

2. **VIEW-03 "MapContentView State-Properties in MapViewModel migriert" — was ist gemeint?**
   - Was wir wissen: Die aktuellen @State-Properties sind Gesture/Layout-State und sollten nicht in ViewModel wandern.
   - Was unklar: Gab es eine frühere Version mit falschen @State-Properties, die mittlerweile schon migriert wurden?
   - Empfehlung: Das Requirement als "MapContentView unter 400 Zeilen bringen durch Extraktion von Sub-Views" interpretieren, da der aktuelle State korrekt aufgeteilt ist.

---

## Sources

### Primary (HIGH confidence)
- Direktes Code-Audit: `/ValetudoApp/Views/RobotDetailView.swift` (1.210 Zeilen, vollständig analysiert)
- Direktes Code-Audit: `/ValetudoApp/Views/RobotSettingsSections.swift` (1.079 Zeilen, Structs identifiziert)
- Direktes Code-Audit: `/ValetudoApp/Views/MapView.swift` (863 Zeilen, @State analysiert)
- Direktes Code-Audit: `/ValetudoApp/project.yml` — XcodeGen Konfiguration verifiziert
- Apple SwiftUI @Observable Dokumentation (iOS 17 API, Kenntnisstand Aug 2025)

### Secondary (MEDIUM confidence)
- Zeilen-Zählung via `wc -l` auf alle View-Dateien im Hauptprojekt

---

## Metadata

**Confidence breakdown:**
- Dateianalyse (Zeilenzahlen, Structs): HIGH — direkte Code-Inspektion
- Extraktionsstrategie (welche Structs, welche Dateien): HIGH — basiert auf bestehenden MARK-Sektionen
- @Observable Sub-View Passing: HIGH — iOS 17 API, bekanntes Muster
- MAP-State-Frage: MEDIUM — Interpretation des Requirements unklar

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabiler Stack, keine schnellen Änderungen)
