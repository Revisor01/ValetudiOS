import SwiftUI
import os

private let settingsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotSettingsView")

struct RobotSettingsView: View {
    let robot: RobotConfig
    let updateService: UpdateService?
    @Environment(RobotManager.self) var robotManager
    @State private var viewModel: RobotSettingsViewModel

    // Pure UI presentation state (alert toggles only)
    @State private var showMappingAlert = false
    @State private var showMapResetAlert = false

    init(robot: RobotConfig, robotManager: RobotManager, updateService: UpdateService? = nil) {
        self.robot = robot
        self.updateService = updateService
        _viewModel = State(initialValue: RobotSettingsViewModel(robot: robot, robotManager: robotManager))
    }

    var body: some View {
        List {
            // Speaker Section
            if viewModel.hasVolumeControl || viewModel.hasSpeakerTest {
                Section {
                    if viewModel.hasVolumeControl {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: volumeIcon)
                                    .foregroundStyle(.blue)
                                Text(String(localized: "settings.volume"))
                                Spacer()
                                Text("\(Int(viewModel.volume))%")
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $viewModel.volume, in: 0...100, step: 10) {
                                Text("Volume")
                            } onEditingChanged: { editing in
                                if !editing {
                                    viewModel.volumeChanged = true
                                    Task { await viewModel.setVolume() }
                                }
                            }
                        }
                    }

                    if viewModel.hasSpeakerTest {
                        Button {
                            Task { await viewModel.testSpeaker() }
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.blue)
                                Text(String(localized: "settings.test_speaker"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                } header: {
                    Label(String(localized: "settings.speaker"), systemImage: "speaker.wave.2")
                }
            }

            // Cleaning Settings Section
            if viewModel.hasCarpetMode || viewModel.hasObstacleAvoidance || viewModel.hasPetObstacleAvoidance || viewModel.hasCollisionAvoidance || viewModel.hasCarpetSensorMode || viewModel.hasFloorMaterialNavigation {
                Section {
                    if viewModel.hasCarpetMode {
                        Toggle(isOn: $viewModel.carpetMode) {
                            HStack {
                                Image(systemName: "square.grid.3x3")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.carpet_mode"))
                            }
                        }
                        .onChange(of: viewModel.carpetMode) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setCarpetMode(newValue) }
                        }
                    }

                    if viewModel.hasObstacleAvoidance {
                        Toggle(isOn: $viewModel.obstacleAvoidance) {
                            HStack {
                                Image(systemName: "eye.trianglebadge.exclamationmark")
                                    .foregroundStyle(.purple)
                                Text(String(localized: "settings.obstacle_avoidance"))
                            }
                        }
                        .onChange(of: viewModel.obstacleAvoidance) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setObstacleAvoidance(newValue) }
                        }
                    }

                    if viewModel.hasPetObstacleAvoidance {
                        Toggle(isOn: $viewModel.petObstacleAvoidance) {
                            HStack {
                                Image(systemName: "pawprint.fill")
                                    .foregroundStyle(.brown)
                                Text(String(localized: "settings.pet_obstacle_avoidance"))
                            }
                        }
                        .onChange(of: viewModel.petObstacleAvoidance) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setPetObstacleAvoidance(newValue) }
                        }
                    }

                    if viewModel.hasCollisionAvoidance {
                        Toggle(isOn: $viewModel.collisionAvoidance) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.yellow)
                                Text(String(localized: "settings.collision_avoidance"))
                            }
                        }
                        .onChange(of: viewModel.collisionAvoidance) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setCollisionAvoidance(newValue) }
                        }
                    }

                    if viewModel.hasFloorMaterialNavigation {
                        Toggle(isOn: $viewModel.floorMaterialNavigation) {
                            HStack {
                                Image(systemName: "arrow.left.and.right")
                                    .foregroundStyle(.cyan)
                                Text(String(localized: "settings.floor_material_navigation"))
                            }
                        }
                        .onChange(of: viewModel.floorMaterialNavigation) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setFloorMaterialNavigation(newValue) }
                        }
                    }

                    if viewModel.hasCarpetSensorMode && !viewModel.carpetSensorModePresets.isEmpty {
                        Picker(selection: $viewModel.carpetSensorMode) {
                            ForEach(viewModel.carpetSensorModePresets, id: \.self) { preset in
                                Text(displayNameForCarpetSensorMode(preset)).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sensor.fill")
                                    .foregroundStyle(.teal)
                                Text(String(localized: "settings.carpet_sensor_mode"))
                            }
                        }
                        .onChange(of: viewModel.carpetSensorMode) { _, newValue in
                            guard !viewModel.isInitialLoad && !newValue.isEmpty else { return }
                            Task { await viewModel.setCarpetSensorMode(newValue) }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.cleaning"), systemImage: "sparkles")
                }
            }

            // Device Lock Section
            if viewModel.hasKeyLock {
                Section {
                    Toggle(isOn: $viewModel.keyLock) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                            Text(String(localized: "settings.key_lock"))
                        }
                    }
                    .onChange(of: viewModel.keyLock) { _, newValue in
                        guard !viewModel.isInitialLoad else { return }
                        Task { await viewModel.setKeyLock(newValue) }
                    }
                } header: {
                    Label(String(localized: "settings.device"), systemImage: "gearshape")
                } footer: {
                    Text(String(localized: "settings.key_lock_desc"))
                }
            }

            // Map Settings Section
            if viewModel.hasPersistentMap || viewModel.hasMappingPass || viewModel.hasMapReset {
                Section {
                    if viewModel.hasPersistentMap {
                        Toggle(isOn: $viewModel.persistentMap) {
                            HStack {
                                Image(systemName: "map")
                                    .foregroundStyle(.green)
                                Text(String(localized: "settings.persistent_map"))
                            }
                        }
                        .onChange(of: viewModel.persistentMap) { _, newValue in
                            guard !viewModel.isInitialLoad else { return }
                            Task { await viewModel.setPersistentMap(newValue) }
                        }
                    }

                    if viewModel.hasMappingPass {
                        Button {
                            showMappingAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "point.bottomleft.forward.to.arrowtriangle.uturn.scurvepath")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.start_mapping"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }

                    if viewModel.hasMapReset {
                        Button(role: .destructive) {
                            showMapResetAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                Text(String(localized: "settings.map_reset"))
                                    .foregroundStyle(.red)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                } header: {
                    Label(String(localized: "settings.map"), systemImage: "map")
                } footer: {
                    if viewModel.hasPersistentMap && viewModel.hasMappingPass {
                        Text(String(localized: "settings.persistent_map_desc"))
                    } else if viewModel.hasPersistentMap {
                        Text(String(localized: "settings.persistent_map_desc"))
                    } else if viewModel.hasMappingPass {
                        Text(String(localized: "settings.start_mapping_desc"))
                    }
                }
            }

            // Map Snapshots Section
            if viewModel.hasMapSnapshots {
                Section {
                    if viewModel.mapSnapshots.isEmpty {
                        Text(String(localized: "snapshots.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.mapSnapshots) { snapshot in
                            HStack {
                                Image(systemName: "map")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                Text(snapshot.id)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    Task { await viewModel.restoreMapSnapshot(snapshot) }
                                } label: {
                                    if viewModel.isRestoringSnapshot {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text(String(localized: "snapshots.restore"))
                                            .font(.caption)
                                    }
                                }
                                .disabled(viewModel.isRestoringSnapshot)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "snapshots.title"))
                } footer: {
                    Text(String(localized: "snapshots.footer"))
                }
            }

            // Pending Map Change Section
            if viewModel.hasPendingMapChange && viewModel.pendingMapChangeEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.orange)
                            Text(String(localized: "pending_map.description"))
                                .font(.subheadline)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task { await viewModel.acceptPendingMapChange() }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text(String(localized: "pending_map.accept"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button {
                                Task { await viewModel.rejectPendingMapChange() }
                            } label: {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text(String(localized: "pending_map.reject"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .disabled(viewModel.isHandlingMapChange)
                    }
                } header: {
                    Text(String(localized: "pending_map.title"))
                }
            }

            // Voice Pack Section
            if viewModel.hasVoicePack && !viewModel.voicePacks.isEmpty {
                Section {
                    Picker(selection: $viewModel.currentVoicePackId) {
                        ForEach(viewModel.voicePacks) { pack in
                            Text(pack.name).tag(pack.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2.bubble")
                                .foregroundStyle(.indigo)
                            Text(String(localized: "voice_pack.label"))
                        }
                    }
                    .onChange(of: viewModel.currentVoicePackId) { _, newValue in
                        guard !viewModel.isInitialLoad && !newValue.isEmpty else { return }
                        Task { await viewModel.setVoicePack(newValue) }
                    }
                    .disabled(viewModel.isSettingVoicePack)
                } header: {
                    Label(String(localized: "voice_pack.title"), systemImage: "speaker.wave.2.bubble")
                } footer: {
                    Text(String(localized: "voice_pack.footer"))
                }
            }

            // Quirks Section
            if viewModel.hasQuirks {
                Section {
                    NavigationLink {
                        QuirksView(robot: robot)
                    } label: {
                        HStack {
                            Image(systemName: "wrench.adjustable")
                                .foregroundStyle(.orange)
                            Text(String(localized: "settings.quirks"))
                        }
                    }
                } header: {
                    Label(String(localized: "settings.advanced"), systemImage: "slider.horizontal.3")
                } footer: {
                    Text(String(localized: "settings.quirks_desc"))
                }
            }

            // Valetudo System Section
            Section {
                // WiFi Settings
                if viewModel.hasWifiConfig || viewModel.hasWifiScan {
                    NavigationLink {
                        WifiSettingsView(robot: robot)
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundStyle(.blue)
                            Text(String(localized: "settings.wifi"))
                        }
                    }
                }

                // MQTT Settings
                NavigationLink {
                    MQTTSettingsView(robot: robot)
                } label: {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.green)
                        Text("MQTT")
                    }
                }

                // NTP Settings
                NavigationLink {
                    NTPSettingsView(robot: robot)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                        Text("NTP")
                    }
                }

                // Geräteinfo-Valetudo
                NavigationLink {
                    DeviceInfoView(robot: robot, updateService: updateService)
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.gray)
                        Text(String(localized: "device_info.title"))
                    }
                }

            } header: {
                Label(String(localized: "settings.system"), systemImage: "gearshape.2")
            }

            // No settings available
            if !viewModel.hasVolumeControl && !viewModel.hasSpeakerTest && !viewModel.hasCarpetMode && !viewModel.hasPersistentMap && !viewModel.hasMappingPass && !viewModel.hasAutoEmptyDock && !viewModel.hasMopDockAutoDrying && !viewModel.hasMopDockWashTemperature && !viewModel.hasMopDockDryingTime && !viewModel.hasQuirks && !viewModel.isLoading {
                Section {
                    Text(String(localized: "settings.robot_no_settings"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.section_robot"))
        .task {
            await viewModel.loadSettings()
        }
        .refreshable {
            await viewModel.loadSettings()
        }
        .overlay {
            if viewModel.isLoading && !viewModel.hasVolumeControl && !viewModel.hasCarpetMode && !viewModel.hasPersistentMap && !viewModel.hasMappingPass {
                ProgressView()
            }
        }
        .alert(
            String(localized: "settings.mapping_warning_title"),
            isPresented: $showMappingAlert
        ) {
            Button(String(localized: "settings.cancel"), role: .cancel) { }
            Button(String(localized: "settings.mapping_start"), role: .destructive) {
                Task { await viewModel.startMappingPass() }
            }
        } message: {
            Text(String(localized: "settings.mapping_warning_message"))
        }
        .alert(
            String(localized: "settings.map_reset_warning_title"),
            isPresented: $showMapResetAlert
        ) {
            Button(String(localized: "settings.cancel"), role: .cancel) { }
            Button(String(localized: "settings.map_reset_confirm"), role: .destructive) {
                Task { await viewModel.resetMap() }
            }
        } message: {
            Text(String(localized: "settings.map_reset_warning_message"))
        }
    }

    private var volumeIcon: String {
        if viewModel.volume == 0 { return "speaker.slash" }
        if viewModel.volume < 33 { return "speaker.wave.1" }
        if viewModel.volume < 66 { return "speaker.wave.2" }
        return "speaker.wave.3"
    }

    private func displayNameForCarpetSensorMode(_ mode: String) -> String {
        // Convert API mode names to user-friendly display names
        switch mode.lowercased() {
        case "off":
            return String(localized: "settings.carpet_sensor.off")
        case "low":
            return String(localized: "settings.carpet_sensor.low")
        case "medium":
            return String(localized: "settings.carpet_sensor.medium")
        case "high":
            return String(localized: "settings.carpet_sensor.high")
        case "auto":
            return String(localized: "settings.carpet_sensor.auto")
        case "avoidance":
            return String(localized: "settings.carpet_sensor.avoidance")
        case "adaptation":
            return String(localized: "settings.carpet_sensor.adaptation")
        default:
            // Fallback: capitalize and replace underscores
            return mode.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

}

#Preview {
    let robotManager = RobotManager()
    NavigationStack {
        RobotSettingsView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"), robotManager: robotManager)
            .environment(robotManager)
    }
}
