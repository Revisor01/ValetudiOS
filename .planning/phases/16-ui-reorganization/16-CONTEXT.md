# Phase 16: UI Reorganization - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

ValetudoInfoView (Firmware, Commit, Host-Info, Memory, Uptime) und Robot Properties (Model, Serial, Manufacturer) werden zu einer einheitlichen Geräte-Info-Sektion im Roboter-Detail-Screen zusammengeführt. Die bisherige Navigation über RobotSettingsView → Valetudo entfällt.

</domain>

<decisions>
## Implementation Decisions

### Sektions-Struktur
- Eine einzige Section "Geräteinformationen" für alle Geräte-Daten
- Platzierung am Ende der RobotDetailView (wo Robot Properties jetzt steht)
- Als DisclosureGroup (zugeklappt) — konsistent mit Statistics Section
- "Valetudo" NavigationLink in RobotSettingsView komplett entfernen

### Datenanzeige
- Memory-Anzeige übernehmen, als einzelne Bar dargestellt (nicht LabeledContent, nicht mehrere Bars)
- CPU-Load übernehmen, als einzelne Bar dargestellt (nicht drei separate Werte)
- Update-Anzeige bleibt im bestehenden Banner oben (Phase 15) — nicht in der Geräte-Info duplizieren
- Reihenfolge: Hardware (Model, Serial, Manufacturer) → Valetudo (Version, Commit) → System (Hostname, Uptime, CPU-Bar, Memory-Bar)

### Code-Struktur
- Neue Sub-View in RobotDetailSections.swift — passt zum Decomposition-Muster aus Phase 11
- RobotDetailViewModel erweitern mit loadSystemInfo() und loadValetudoVersion() — konsistent mit loadRobotProperties()
- ValetudoInfoView (in RobotSettingsSections.swift) nach Migration löschen — kein ungenutzter Code
- "Valetudo System" Section in RobotSettingsView bleibt (WiFi, MQTT, NTP) — nur der Valetudo-Link wird entfernt

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- ValetudoInfoView (RobotSettingsSections.swift:774-989) — enthält die gesamte Lade-/Anzeigelogik für System-Daten, wird als Vorlage für die neue Sub-View genutzt
- Robot Properties Section (RobotDetailView.swift:945-964) — bestehende LabeledContent-Darstellung
- RobotDetailViewModel.loadRobotProperties() — bestehendes Pattern für API-Datenladung im ViewModel
- ValetudoAPI.getValetudoVersion(), getSystemHostInfo() — bestehende API-Methoden

### Established Patterns
- DisclosureGroup für zugeklappte Sektionen (Statistics Section als Referenz)
- Sub-Views in RobotDetailSections.swift (Phase 11 Decomposition)
- ViewModel-Methoden laden Daten async in .task{} — nicht inline in Views
- sectionsLogger für Logging in RobotDetailSections.swift

### Integration Points
- RobotDetailView: robotPropertiesSection ersetzen durch neue deviceInfoSection
- RobotDetailViewModel: neue @Published Properties für systemHostInfo und valetudoVersion
- RobotSettingsView: "Valetudo" NavigationLink entfernen, updateService-Parameter ggf. anpassen
- RobotSettingsSections.swift: ValetudoInfoView Struct löschen

</code_context>

<specifics>
## Specific Ideas

- Memory und CPU jeweils als eine einzelne Bar (Gauge/ProgressView) — nicht als Text, nicht als mehrere Bars
- Zuklappbar wie Statistics Section (DisclosureGroup)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
