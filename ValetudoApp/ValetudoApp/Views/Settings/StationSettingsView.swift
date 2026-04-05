import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "StationSettingsView")

// MARK: - Station Settings View (Dock/Station specific settings)
struct StationSettingsView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var isLoading = false
    @State private var stationLoaded = false

    // Capabilities
    @State private var hasAutoEmptyDock = DebugConfig.showAllCapabilities
    @State private var hasAutoEmptyDockDuration = DebugConfig.showAllCapabilities
    @State private var hasMopDockAutoDrying = DebugConfig.showAllCapabilities
    @State private var hasMopDockWashTemperature = DebugConfig.showAllCapabilities
    @State private var hasMopDockDryingTime = DebugConfig.showAllCapabilities

    // Settings
    @State private var mopDockAutoDrying = false
    @State private var mopDockWashTemperaturePresets: [String] = []
    @State private var currentWashTemperature: String = ""
    @State private var mopDockDryingTimePresets: [String] = []
    @State private var currentMopDockDryingTime: String = ""
    @State private var autoEmptyDockDurationPresets: [String] = []
    @State private var currentAutoEmptyDockDuration: String = ""

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Auto Empty Dock Settings
            if hasAutoEmptyDock || hasAutoEmptyDockDuration {
                Section {
                    if hasAutoEmptyDock {
                        NavigationLink {
                            AutoEmptyDockSettingsView(robot: robot)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.bin")
                                    .foregroundStyle(.purple)
                                Text(String(localized: "settings.auto_empty_interval"))
                            }
                        }
                    }

                    if hasAutoEmptyDockDuration && !autoEmptyDockDurationPresets.isEmpty {
                        Picker(selection: $currentAutoEmptyDockDuration) {
                            ForEach(autoEmptyDockDurationPresets, id: \.self) { preset in
                                Text(displayNameForAutoEmptyDockDuration(preset)).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundStyle(.purple)
                                Text(String(localized: "auto_empty.duration_label"))
                            }
                        }
                        .onChange(of: currentAutoEmptyDockDuration) { _, newValue in
                            guard stationLoaded && !newValue.isEmpty else { return }
                            Task { await setAutoEmptyDockDuration(newValue) }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.auto_empty"), systemImage: "arrow.up.bin")
                } footer: {
                    Text(String(localized: "settings.auto_empty_interval_desc"))
                }
            }

            // Mop Dock Settings
            if hasMopDockAutoDrying || hasMopDockWashTemperature || hasMopDockDryingTime {
                Section {
                    if hasMopDockAutoDrying {
                        Toggle(isOn: $mopDockAutoDrying) {
                            HStack {
                                Image(systemName: "wind")
                                    .foregroundStyle(.cyan)
                                Text(String(localized: "settings.mop_auto_drying"))
                            }
                        }
                        .onChange(of: mopDockAutoDrying) { _, newValue in
                            guard stationLoaded else { return }
                            Task { await setMopDockAutoDrying(newValue) }
                        }
                    }

                    if hasMopDockWashTemperature {
                        Picker(selection: $currentWashTemperature) {
                            ForEach(mopDockWashTemperaturePresets.isEmpty ? ["cold", "warm", "hot"] : mopDockWashTemperaturePresets, id: \.self) { preset in
                                Text(displayNameForWashTemperature(preset)).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.wash_temperature"))
                            }
                        }
                        .onChange(of: currentWashTemperature) { _, newValue in
                            guard stationLoaded && !newValue.isEmpty else { return }
                            Task { await setWashTemperature(newValue) }
                        }
                    }

                    if hasMopDockDryingTime && !mopDockDryingTimePresets.isEmpty {
                        Picker(selection: $currentMopDockDryingTime) {
                            ForEach(mopDockDryingTimePresets, id: \.self) { preset in
                                Text(preset.capitalized).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "fan")
                                    .foregroundStyle(.cyan)
                                Text(String(localized: "mop_dock.drying_time_label"))
                            }
                        }
                        .onChange(of: currentMopDockDryingTime) { _, newValue in
                            guard stationLoaded && !newValue.isEmpty else { return }
                            Task { await setDryingTime(newValue) }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.mop_dock"), systemImage: "drop.triangle")
                } footer: {
                    Text(String(localized: "settings.dock_settings_desc"))
                }
            }

            // No settings available
            if !hasAutoEmptyDock && !hasAutoEmptyDockDuration && !hasMopDockAutoDrying && !hasMopDockWashTemperature && !hasMopDockDryingTime && !isLoading {
                Section {
                    Text(String(localized: "settings.no_station_settings"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.section_station"))
        .task {
            await loadSettings()
        }
        .refreshable {
            await loadSettings()
        }
        .overlay {
            if isLoading && !hasAutoEmptyDock && !hasAutoEmptyDockDuration && !hasMopDockAutoDrying && !hasMopDockWashTemperature && !hasMopDockDryingTime {
                ProgressView()
            }
        }
    }

    private func loadSettings() async {
        guard let api = api else { return }
        stationLoaded = false
        isLoading = true
        defer { isLoading = false }

        // Check capabilities
        do {
            let capabilities = try await api.getCapabilities()
            hasAutoEmptyDock = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyIntervalControlCapability")
            hasAutoEmptyDockDuration = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyDurationControlCapability")
            hasMopDockAutoDrying = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopAutoDryingControlCapability")
            hasMopDockWashTemperature = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopWashTemperatureControlCapability")
            hasMopDockDryingTime = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopDryingTimeControlCapability")
        } catch {
            // Use debug defaults
        }

        // Load mop dock auto drying
        if hasMopDockAutoDrying {
            do {
                mopDockAutoDrying = try await api.getMopDockAutoDrying()
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockAutoDrying = false }
            }
        }

        // Load mop dock wash temperature presets
        if hasMopDockWashTemperature {
            do {
                mopDockWashTemperaturePresets = try await api.getMopDockWashTemperaturePresets()
                if let tempAttr = robotManager.robotStates[robot.id]?.attributes.first(where: {
                    $0.__class == "PresetSelectionStateAttribute" && $0.type == "mop_dock_mop_cleaning_water_temperature"
                }) {
                    currentWashTemperature = tempAttr.value ?? ""
                }
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockWashTemperature = false }
                // Use debug defaults
                if DebugConfig.showAllCapabilities {
                    mopDockWashTemperaturePresets = ["cold", "warm", "hot"]
                    currentWashTemperature = "warm"
                }
            }
        }

        // Load mop dock drying time presets
        if hasMopDockDryingTime {
            do {
                mopDockDryingTimePresets = try await api.getMopDockDryingTimePresets()
                if let attr = robotManager.robotStates[robot.id]?.attributes.first(where: {
                    $0.__class == "PresetSelectionStateAttribute" && $0.type == "mop_dock_mop_drying_time"
                }) {
                    currentMopDockDryingTime = attr.value ?? ""
                }
                if currentMopDockDryingTime.isEmpty, let first = mopDockDryingTimePresets.first {
                    currentMopDockDryingTime = first
                }
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockDryingTime = false }
                mopDockDryingTimePresets = []
                logger.debug("Mop dock drying time not supported: \(error, privacy: .public)")
            }
        }

        // Load auto empty dock duration presets
        if hasAutoEmptyDockDuration {
            do {
                autoEmptyDockDurationPresets = try await api.getAutoEmptyDockDurationPresets()
                if let attr = robotManager.robotStates[robot.id]?.attributes.first(where: {
                    $0.__class == "PresetSelectionStateAttribute" && $0.type == "auto_empty_dock_auto_empty_duration"
                }) {
                    currentAutoEmptyDockDuration = attr.value ?? ""
                }
                if currentAutoEmptyDockDuration.isEmpty, let first = autoEmptyDockDurationPresets.first {
                    currentAutoEmptyDockDuration = first
                }
            } catch {
                if !DebugConfig.showAllCapabilities { hasAutoEmptyDockDuration = false }
                autoEmptyDockDurationPresets = []
                logger.debug("Auto empty dock duration not supported: \(error, privacy: .public)")
            }
        }

        stationLoaded = true
    }

    private func setMopDockAutoDrying(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockAutoDrying(enabled: enabled)
        } catch {
            logger.error("Failed to set mop dock auto drying: \(error, privacy: .public)")
            mopDockAutoDrying = !enabled
        }
    }

    private func setWashTemperature(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockWashTemperature(preset: preset)
        } catch {
            logger.error("Failed to set wash temperature: \(error, privacy: .public)")
        }
    }

    private func setDryingTime(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockDryingTime(preset: preset)
        } catch {
            logger.error("Failed to set mop dock drying time: \(error, privacy: .public)")
        }
    }

    private func displayNameForWashTemperature(_ preset: String) -> String {
        switch preset.lowercased() {
        case "cold":
            return String(localized: "settings.wash_temp.cold")
        case "warm":
            return String(localized: "settings.wash_temp.warm")
        case "hot":
            return String(localized: "settings.wash_temp.hot")
        default:
            return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func setAutoEmptyDockDuration(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setAutoEmptyDockDuration(preset: preset)
        } catch {
            logger.error("Failed to set auto empty dock duration: \(error, privacy: .public)")
        }
    }

    private func displayNameForAutoEmptyDockDuration(_ preset: String) -> String {
        switch preset.lowercased() {
        case "min", "minimum":
            return String(localized: "preset.min")
        case "low":
            return String(localized: "preset.low")
        case "medium":
            return String(localized: "preset.medium")
        case "high":
            return String(localized: "preset.high")
        case "max", "maximum":
            return String(localized: "preset.max")
        default:
            return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }
}
