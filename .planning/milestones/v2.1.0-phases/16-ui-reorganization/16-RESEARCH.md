# Phase 16: UI Reorganization - Research

**Researched:** 2026-04-01
**Domain:** SwiftUI View Refactoring / ViewModel Extension
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Sektions-Struktur
- Eine einzige Section "Geräteinformationen" für alle Geräte-Daten
- Platzierung am Ende der RobotDetailView (wo Robot Properties jetzt steht)
- Als DisclosureGroup (zugeklappt) — konsistent mit Statistics Section
- "Valetudo" NavigationLink in RobotSettingsView komplett entfernen

#### Datenanzeige
- Memory-Anzeige übernehmen, als einzelne Bar dargestellt (nicht LabeledContent, nicht mehrere Bars)
- CPU-Load übernehmen, als einzelne Bar dargestellt (nicht drei separate Werte)
- Update-Anzeige bleibt im bestehenden Banner oben (Phase 15) — nicht in der Geräte-Info duplizieren
- Reihenfolge: Hardware (Model, Serial, Manufacturer) → Valetudo (Version, Commit) → System (Hostname, Uptime, CPU-Bar, Memory-Bar)

#### Code-Struktur
- Neue Sub-View in RobotDetailSections.swift — passt zum Decomposition-Muster aus Phase 11
- RobotDetailViewModel erweitern mit loadSystemInfo() und loadValetudoVersion() — konsistent mit loadRobotProperties()
- ValetudoInfoView (in RobotSettingsSections.swift) nach Migration löschen — kein ungenutzter Code
- "Valetudo System" Section in RobotSettingsView bleibt (WiFi, MQTT, NTP) — nur der Valetudo-Link wird entfernt

### Claude's Discretion

None specified.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REORG-01 | ValetudoInfoView (Firmware, Commit, Host-Info, Memory, Uptime) wird von den Einstellungen in den Roboter-Detail-Screen verschoben | Bestehende ValetudoInfoView (RobotSettingsSections.swift:774-989) enthält vollständige Lade-/Anzeigelogik; API-Methoden getValetudoVersion() und getSystemHostInfo() bereits vorhanden |
| REORG-02 | Die Robot Properties Section und ValetudoInfoView werden zu einer einheitlichen Geräte-Info-Sektion zusammengeführt | robotPropertiesSection (RobotDetailView.swift:945-964) und ValetudoInfoView werden in einer neuen DeviceInfoSection in RobotDetailSections.swift kombiniert |
</phase_requirements>

---

## Summary

Phase 16 ist ein reines SwiftUI-Refactoring ohne neue API-Endpunkte oder Netzwerk-Logik. Die gesamte benötigte Funktionalität existiert bereits — sie muss lediglich neu angeordnet und konsolidiert werden.

Die valide Referenzimplementierung liegt vollständig in `ValetudoInfoView` (RobotSettingsSections.swift:774-989). Diese View enthält die Ladelogik, Formatierungs-Helpers (`formatUptime`, `formatBytes`) und die Bar-Darstellung für Memory. Diese Logik wird in den `RobotDetailViewModel` (als ViewModel-Methoden) und eine neue Sub-View in `RobotDetailSections.swift` überführt.

Die Statistics Section in `RobotDetailView.swift` (Zeile 848-940) ist die exakte Vorlage für die DisclosureGroup-Struktur. Das ViewModel-Pattern für API-Datenladung ist in `loadRobotProperties()` kanonisiert.

**Primary recommendation:** Neue `DeviceInfoSection` Struct in `RobotDetailSections.swift` anlegen, ViewModel um zwei `@Published` Properties und zwei `load`-Methoden erweitern, `robotPropertiesSection` in `RobotDetailView` durch `DeviceInfoSection(viewModel:)` ersetzen, NavigationLink in `RobotSettingsView` entfernen, `ValetudoInfoView` Struct aus `RobotSettingsSections.swift` löschen.

---

## Standard Stack

### Core (bereits im Projekt vorhanden)

| Komponente | Quelle | Zweck |
|------------|--------|-------|
| `DisclosureGroup` | SwiftUI | Zugeklappte Section — identisch zu statisticsSection |
| `ProgressView(value:total:)` | SwiftUI | CPU-Load-Bar (einzelner Wert aus `load._1`) |
| `GeometryReader` + `RoundedRectangle` | SwiftUI | Memory-Bar — exakt wie in ValetudoInfoView:922-931 |
| `LabeledContent` | SwiftUI | Hardware-Zeilen (Model, Serial, Manufacturer) — wie bestehende robotPropertiesSection |
| `ValetudoAPI.getValetudoVersion()` | ValetudoAPI.swift:590 | Lädt `ValetudoVersion { release, commit }` |
| `ValetudoAPI.getSystemHostInfo()` | ValetudoAPI.swift:594 | Lädt `SystemHostInfo { hostname, arch, mem, uptime, load? }` |

**Keine neuen Abhängigkeiten erforderlich.**

---

## Architecture Patterns

### Recommended Project Structure

Die neue Sub-View kommt in die bestehende Datei für Decomposed Sub-Views:

```
ValetudoApp/Views/
├── RobotDetailSections.swift    ← DeviceInfoSection struct hier hinzufügen
├── RobotDetailView.swift        ← robotPropertiesSection ersetzen durch DeviceInfoSection(viewModel:)
├── RobotSettingsView.swift      ← NavigationLink "Valetudo" (Zeile 408-417) entfernen
└── RobotSettingsSections.swift  ← ValetudoInfoView struct (Zeile 774-989) löschen
ValetudoApp/ViewModels/
└── RobotDetailViewModel.swift   ← @Published valetudoVersion, systemHostInfo + 2 load-Methoden
```

### Pattern 1: ViewModel Extension (angelehnt an loadRobotProperties)

```swift
// In RobotDetailViewModel.swift — nach loadRobotProperties()
@Published var valetudoVersion: ValetudoVersion?
@Published var systemHostInfo: SystemHostInfo?

private func loadSystemInfo() async {
    guard let api = api else { return }
    do {
        async let versionResult = api.getValetudoVersion()
        async let hostInfoResult = api.getSystemHostInfo()
        valetudoVersion = try await versionResult
        systemHostInfo = try await hostInfoResult
    } catch {
        logger.debug("System info not available: \(error, privacy: .public)")
    }
}
```

Die Methode muss in `loadData()` zu den `async let` Tasks hinzugefügt werden, genau wie `propertiesTask`.

### Pattern 2: DisclosureGroup Section (Referenz: statisticsSection, Zeile 848-940)

```swift
// In RobotDetailSections.swift
struct DeviceInfoSection: View {
    @ObservedObject var viewModel: RobotDetailViewModel

    var body: some View {
        Section {
            DisclosureGroup {
                // Hardware-Block: Model, Serial, Manufacturer (LabeledContent)
                // Valetudo-Block: Version, Commit
                // System-Block: Hostname, Uptime, CPU-Bar, Memory-Bar
            } label: {
                Label(String(localized: "device_info.title"), systemImage: "info.circle")
            }
        }
    }
}
```

Die Section zeigt sich nur wenn `viewModel.robotProperties != nil || viewModel.valetudoVersion != nil` (graceful degradation).

### Pattern 3: CPU-Bar mit ProgressView

```swift
// CPU-Load: nur _1-Wert (1-Minuten-Durchschnitt), normalisiert auf 0...1
// Valetudo-Roboter sind Single-Core oder Dual-Core — Load > 1.0 abschneiden
if let load = viewModel.systemHostInfo?.load {
    let normalizedLoad = min(load._1, 1.0)
    ProgressView(value: normalizedLoad, total: 1.0)
        .tint(normalizedLoad > 0.8 ? .red : .blue)
}
```

### Pattern 4: Memory-Bar (direkte Übernahme aus ValetudoInfoView:922-931)

```swift
// Exakt wie in der bestehenden ValetudoInfoView
let usedPercent = Double(info.mem.total - info.mem.free) / Double(info.mem.total)
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
        RoundedRectangle(cornerRadius: 4)
            .fill(usedPercent > 0.8 ? Color.red : Color.blue)
            .frame(width: geometry.size.width * usedPercent)
    }
}
.frame(height: 8)
```

### Pattern 5: Formatierungs-Helpers migrieren

`formatUptime(_:)` und `formatBytes(_:)` sind private Methoden in `ValetudoInfoView`. Sie müssen in `DeviceInfoSection` (oder als `fileprivate` Helfer in RobotDetailSections.swift) neu definiert werden. Die Implementierungen sind vollständig in RobotSettingsSections.swift:968-988 vorhanden.

### Anti-Patterns to Avoid

- **Update-Banner duplizieren:** Die Update-Anzeige (Zeile 26-50 in RobotDetailView.swift) bleibt an ihrem Platz (Phase 15). In DeviceInfoSection KEIN `hasUpdate`-Check und kein `updateService`-Parameter.
- **Inline-Ladelogik in der View:** Kein `.task {}` in der Sub-View selbst — Daten werden vom ViewModel geladen, View liest nur `viewModel.valetudoVersion` und `viewModel.systemHostInfo`.
- **Drei CPU-Bars:** Nur `load._1` als einzelne Bar, nicht `_1 / _5 / _15` separat.
- **Mehrere Memory-Zeilen:** Nur die Bar anzeigen, keine separaten Total/Free/Valetudo-Zeilen — das war die Designentscheidung.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Progressbalken | Eigene ZStack-Geometrie für CPU | `ProgressView(value:total:)` — SwiftUI-nativ |
| Uptime-Formatierung | Neuen Parser schreiben | `formatUptime` aus ValetudoInfoView:968-980 direkt kopieren |
| Bytes-Formatierung | `ByteCountFormatter` von Hand bauen | `formatBytes` aus ValetudoInfoView:982-988 direkt kopieren |

**Key insight:** Sämtliche Logik existiert bereits in `ValetudoInfoView`. Diese Phase ist ein Move-and-Adapt, kein Neuschreiben.

---

## Common Pitfalls

### Pitfall 1: loadData() vergessen zu erweitern
**What goes wrong:** `valetudoVersion` und `systemHostInfo` bleiben nil, Section zeigt nichts
**Why it happens:** Neue ViewModel-Methoden hinzugefügt, aber nicht in `loadData()` mit `async let` verknüpft
**How to avoid:** `loadData()` in RobotDetailViewModel.swift:121-134 muss `async let systemInfoTask: () = loadSystemInfo()` enthalten und im abschließenden `await`-Tuple aufgeführt sein
**Warning signs:** Build läuft, Section ist im Simulator unsichtbar

### Pitfall 2: ValetudoInfoView wird in RobotSettingsView noch referenziert
**What goes wrong:** Compile-Fehler nach Löschen der Struct
**Why it happens:** NavigationLink auf Zeile 410 referenziert `ValetudoInfoView(robot:updateService:)` direkt
**How to avoid:** NavigationLink in RobotSettingsView.swift:408-417 ZUERST entfernen, DANN ValetudoInfoView Struct löschen
**Warning signs:** "cannot find type 'ValetudoInfoView'" Compiler-Fehler

### Pitfall 3: `sectionsLogger` nicht verfügbar in DeviceInfoSection
**What goes wrong:** Compile-Fehler wenn Logging aus ValetudoInfoView übernommen wird
**Why it happens:** `sectionsLogger` ist bereits in RobotDetailSections.swift definiert — oder muss dort definiert sein
**How to avoid:** Prüfen ob `sectionsLogger` in RobotDetailSections.swift deklariert ist; falls nicht, analog zu bestehenden Loggern definieren

### Pitfall 4: DisclosureGroup-State nicht persistent
**What goes wrong:** Section klappt sich bei jedem Reload zu
**Why it happens:** `DisclosureGroup` braucht `@State var isExpanded = false` damit SwiftUI den Zustand nicht zurücksetzt
**How to avoid:** `@State private var isExpanded = false` in `DeviceInfoSection`, `DisclosureGroup(isExpanded: $isExpanded)` verwenden — wie Statistics Section

---

## Code Examples

### Neue ViewModel-Properties und Methode

```swift
// RobotDetailViewModel.swift — MARK: - Data state Block
@Published var valetudoVersion: ValetudoVersion?
@Published var systemHostInfo: SystemHostInfo?

// loadData() erweitern:
async let systemInfoTask: () = loadSystemInfo()
_ = await (..., systemInfoTask)

// Neue private Methode:
private func loadSystemInfo() async {
    guard let api = api else { return }
    do {
        async let v = api.getValetudoVersion()
        async let h = api.getSystemHostInfo()
        valetudoVersion = try await v
        systemHostInfo = try await h
    } catch {
        logger.debug("System info not available: \(error, privacy: .public)")
    }
}
```

### DeviceInfoSection Grundstruktur

```swift
// RobotDetailSections.swift
struct DeviceInfoSection: View {
    @ObservedObject var viewModel: RobotDetailViewModel
    @State private var isExpanded = false

    var body: some View {
        let hasAnyData = viewModel.robotProperties != nil
            || viewModel.valetudoVersion != nil
            || viewModel.systemHostInfo != nil

        if hasAnyData {
            Section {
                DisclosureGroup(isExpanded: $isExpanded) {
                    // Hardware
                    // Valetudo
                    // System
                } label: {
                    Label(String(localized: "device_info.title"), systemImage: "info.circle")
                }
            }
        }
    }
}
```

### Nutzung in RobotDetailView

```swift
// RobotDetailView.swift — robotPropertiesSection ersetzen
// ALT:
robotPropertiesSection
// NEU:
DeviceInfoSection(viewModel: viewModel)
```

### NavigationLink entfernen (RobotSettingsView.swift:408-417)

```swift
// Diese 10 Zeilen vollständig löschen:
// System Info
NavigationLink {
    ValetudoInfoView(robot: robot, updateService: updateService)
} label: {
    HStack {
        Image(systemName: "info.circle")
            .foregroundStyle(.gray)
        Text("Valetudo")
    }
}
```

---

## Localization

Bestehende Localization-Keys, die wiederverwendet werden:

| Key | Verwendung in DeviceInfoSection |
|-----|--------------------------------|
| `robot_properties.model` | Hardware-Block: Modell |
| `robot_properties.serial` | Hardware-Block: Seriennummer |
| `robot_properties.manufacturer` | Hardware-Block: Hersteller |
| `robot_properties.firmware` | Hardware-Block: Firmware-Version (aus RobotProperties) |
| `info.system` | System-Block Header (optional) |
| `info.memory` | Memory-Label |
| `info.free` | Falls Memory-Text noch benötigt |

Neuer Key erforderlich: `device_info.title` für den DisclosureGroup-Label ("Geräteinformationen" / "Device Info"). Dieser Key muss in `Localizable.xcstrings` für alle drei Sprachen (de/en/fr) ergänzt werden.

---

## State of the Art

| Altes Pattern | Neues Pattern | Grund |
|---------------|---------------|-------|
| ValetudoInfoView als eigenständige NavigationLink-Destination | Eingebettete Section in RobotDetailView | Vereinfachte Navigation, alle Gerätedaten an einem Ort |
| `@State` Datenladung direkt in der View | `@Published` im ViewModel, View liest nur | Konsistent mit Phase-11-Decomposition-Pattern |
| Robot Properties und System-Info in separaten Screens/Sections | Einheitliche DisclosureGroup in DeviceInfoSection | Entspricht REORG-02 |

---

## Open Questions

1. **CPU-Bar Normalisierung**
   - Was wir wissen: `load._1` kann > 1.0 sein auf Multi-Core-Systemen
   - Was unklar: Ob Valetudo-Roboter typischerweise Single- oder Multi-Core sind
   - Empfehlung: `min(load._1, 1.0)` normalisieren — visuell sinnvoll, keine falsch-negativen Anzeigen

2. **`sectionsLogger` Deklaration**
   - Was wir wissen: Der Logger wird in ValetudoInfoView genutzt (`sectionsLogger.error(...)`)
   - Was unklar: Ob `sectionsLogger` bereits in RobotDetailSections.swift oder in RobotSettingsSections.swift top-level deklariert ist
   - Empfehlung: Beim Lesen von RobotDetailSections.swift Anfang prüfen; falls nicht vorhanden, analog zu `logger` im ViewModel definieren

---

## Sources

### Primary (HIGH confidence)
- Direkt gelesen: `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift:774-989` — vollständige ValetudoInfoView Implementierung
- Direkt gelesen: `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift:848-964` — Statistics DisclosureGroup + robotPropertiesSection
- Direkt gelesen: `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` — vollständige ViewModel-Struktur
- Direkt gelesen: `ValetudoApp/ValetudoApp/Models/RobotState.swift:677-707` — ValetudoVersion, SystemHostInfo Modelle
- Direkt gelesen: `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift:408-417` — NavigationLink zu entfernende Stelle
- Direkt gelesen: `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` — bestehende Localization-Keys

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — alle Komponenten direkt im Quellcode verifiziert
- Architecture: HIGH — bestehende Patterns (DisclosureGroup, loadRobotProperties) direkt gelesen
- Pitfalls: HIGH — aus Quellcode-Analyse abgeleitet (Compile-Abhängigkeiten, loadData-Struktur)

**Research date:** 2026-04-01
**Valid until:** Stabil bis Observable-Migration (Phase 19)
