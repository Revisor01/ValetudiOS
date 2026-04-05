import Foundation
import SwiftUI
import os
import Observation

@MainActor
@Observable
final class RobotSettingsViewModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotSettingsViewModel")
    let robot: RobotConfig
    private let robotManager: RobotManager

    // MARK: - Settings values
    var volume: Double = 80
    var carpetMode = false
    var persistentMap = false
    var keyLock = false
    var obstacleAvoidance = false
    var petObstacleAvoidance = false
    var collisionAvoidance = false
    var mopDockAutoDrying = false
    var floorMaterialNavigation = false
    var carpetSensorMode: String = ""
    var currentWashTemperature: String = ""

    // MARK: - Capability flags
    var hasVolumeControl = DebugConfig.showAllCapabilities
    var hasSpeakerTest = DebugConfig.showAllCapabilities
    var hasCarpetMode = DebugConfig.showAllCapabilities
    var hasPersistentMap = DebugConfig.showAllCapabilities
    var hasMappingPass = DebugConfig.showAllCapabilities
    var hasAutoEmptyDock = DebugConfig.showAllCapabilities
    var hasQuirks = DebugConfig.showAllCapabilities
    var hasWifiConfig = DebugConfig.showAllCapabilities
    var hasWifiScan = DebugConfig.showAllCapabilities
    var hasKeyLock = DebugConfig.showAllCapabilities
    var hasObstacleAvoidance = DebugConfig.showAllCapabilities
    var hasPetObstacleAvoidance = DebugConfig.showAllCapabilities
    var hasCarpetSensorMode = DebugConfig.showAllCapabilities
    var hasMapReset = DebugConfig.showAllCapabilities
    var hasCollisionAvoidance = DebugConfig.showAllCapabilities
    var hasMopDockAutoDrying = DebugConfig.showAllCapabilities
    var hasMopDockWashTemperature = DebugConfig.showAllCapabilities
    var hasMopDockDryingTime = DebugConfig.showAllCapabilities
    var hasFloorMaterialNavigation = DebugConfig.showAllCapabilities
    var hasMapSnapshots = DebugConfig.showAllCapabilities
    var hasPendingMapChange = DebugConfig.showAllCapabilities
    var hasVoicePack = DebugConfig.showAllCapabilities
    var hasAutoEmptyDockDuration = DebugConfig.showAllCapabilities

    // MARK: - Presets
    var carpetSensorModePresets: [String] = []
    var mopDockWashTemperaturePresets: [String] = []
    var mopDockDryingTimePresets: [String] = []
    var currentMopDockDryingTime: String = ""
    var autoEmptyDockDurationPresets: [String] = []
    var currentAutoEmptyDockDuration: String = ""

    // MARK: - Voice Pack state
    var voicePacks: [VoicePack] = []
    var currentVoicePackId: String = ""
    var isSettingVoicePack = false

    // MARK: - Map Snapshots state
    var mapSnapshots: [MapSnapshot] = []
    var isRestoringSnapshot = false

    // MARK: - Pending Map Change state
    var pendingMapChangeEnabled = false
    var isHandlingMapChange = false

    // MARK: - UI state
    var isLoading = false
    private(set) var settingsLoaded = false
    var volumeChanged = false

    // ErrorRouter — injected from View
    var errorRouter: ErrorRouter?

    // MARK: - Computed
    var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    // MARK: - Init
    init(robot: RobotConfig, robotManager: RobotManager) {
        self.robot = robot
        self.robotManager = robotManager
    }

    // MARK: - Data Loading
    func loadSettings() async {
        guard let api = api else { return }
        settingsLoaded = false
        isLoading = true
        defer {
            isLoading = false
            settingsLoaded = true
        }

        // Load speaker volume
        do {
            volume = Double(try await api.getSpeakerVolume())
        } catch {
            logger.error("getSpeakerVolume failed: \(error, privacy: .public)")
            if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
        }

        // Load carpet mode
        do {
            carpetMode = try await api.getCarpetMode()
        } catch {
            logger.error("getCarpetMode failed: \(error, privacy: .public)")
            if !DebugConfig.showAllCapabilities { hasCarpetMode = false }
        }

        // Load persistent map
        do {
            persistentMap = try await api.getPersistentMap()
        } catch {
            logger.error("getPersistentMap failed: \(error, privacy: .public)")
            if !DebugConfig.showAllCapabilities { hasPersistentMap = false }
        }

        // Check capabilities (Cache-first, DEBT-06)
        do {
            let capabilities: [String]
            if let cached = robotManager.cachedCapabilities(for: robot.id) {
                capabilities = cached
            } else {
                capabilities = try await api.getCapabilities()
                robotManager.cacheCapabilities(capabilities, for: robot.id)
            }
            hasMappingPass = DebugConfig.showAllCapabilities || capabilities.contains("MappingPassCapability")
            hasAutoEmptyDock = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyIntervalControlCapability")
            hasQuirks = DebugConfig.showAllCapabilities || capabilities.contains("QuirksCapability")
            hasWifiConfig = DebugConfig.showAllCapabilities || capabilities.contains("WifiConfigurationCapability")
            hasWifiScan = DebugConfig.showAllCapabilities || capabilities.contains("WifiScanCapability")
            hasKeyLock = DebugConfig.showAllCapabilities || capabilities.contains("KeyLockCapability")
            hasObstacleAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("ObstacleAvoidanceControlCapability")
            hasPetObstacleAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("PetObstacleAvoidanceControlCapability")
            hasCarpetSensorMode = DebugConfig.showAllCapabilities || capabilities.contains("CarpetSensorModeControlCapability")
            hasMapReset = DebugConfig.showAllCapabilities || capabilities.contains("MapResetCapability")
            hasCollisionAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("CollisionAvoidantNavigationControlCapability")
            hasMopDockAutoDrying = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopAutoDryingControlCapability")
            hasMopDockWashTemperature = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopWashTemperatureControlCapability")
            hasMopDockDryingTime = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopDryingTimeControlCapability")
            hasFloorMaterialNavigation = DebugConfig.showAllCapabilities || capabilities.contains("FloorMaterialDirectionAwareNavigationControlCapability")
            hasMapSnapshots = DebugConfig.showAllCapabilities || capabilities.contains("MapSnapshotCapability")
            hasPendingMapChange = DebugConfig.showAllCapabilities || capabilities.contains("PendingMapChangeHandlingCapability")
            hasVoicePack = DebugConfig.showAllCapabilities || capabilities.contains("VoicePackManagementCapability")
            hasAutoEmptyDockDuration = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyDurationControlCapability")
        } catch {
            logger.error("getCapabilities failed: \(error, privacy: .public)")
            hasMappingPass = DebugConfig.showAllCapabilities
        }

        // Load key lock state
        if hasKeyLock {
            do {
                keyLock = try await api.getKeyLock()
            } catch {
                logger.error("getKeyLock failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasKeyLock = false }
            }
        }

        // Load obstacle avoidance state
        if hasObstacleAvoidance {
            do {
                obstacleAvoidance = try await api.getObstacleAvoidance()
            } catch {
                logger.error("getObstacleAvoidance failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasObstacleAvoidance = false }
            }
        }

        // Load pet obstacle avoidance state
        if hasPetObstacleAvoidance {
            do {
                petObstacleAvoidance = try await api.getPetObstacleAvoidance()
            } catch {
                logger.error("getPetObstacleAvoidance failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasPetObstacleAvoidance = false }
            }
        }

        // Load carpet sensor mode presets
        if hasCarpetSensorMode {
            do {
                carpetSensorModePresets = try await api.getCarpetSensorModePresets()
                if !carpetSensorModePresets.isEmpty {
                    carpetSensorMode = try await api.getCarpetSensorMode()
                }
            } catch {
                logger.error("getCarpetSensorMode failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities {
                    hasCarpetSensorMode = false
                }
                carpetSensorModePresets = []
            }
        }

        // Load collision avoidance
        if hasCollisionAvoidance {
            do {
                collisionAvoidance = try await api.getCollisionAvoidantNavigation()
            } catch {
                logger.error("getCollisionAvoidantNavigation failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasCollisionAvoidance = false }
            }
        }

        // Load floor material navigation
        if hasFloorMaterialNavigation {
            do {
                floorMaterialNavigation = try await api.getFloorMaterialNavigation()
            } catch {
                logger.error("getFloorMaterialNavigation failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasFloorMaterialNavigation = false }
            }
        }

        // Load mop dock auto drying
        if hasMopDockAutoDrying {
            do {
                mopDockAutoDrying = try await api.getMopDockAutoDrying()
            } catch {
                logger.error("getMopDockAutoDrying failed: \(error, privacy: .public)")
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
                logger.error("getMopDockWashTemperature failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasMopDockWashTemperature = false }
                mopDockWashTemperaturePresets = []
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
                logger.error("getMopDockDryingTime failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasMopDockDryingTime = false }
                mopDockDryingTimePresets = []
            }
        }

        // Load map snapshots
        if hasMapSnapshots {
            do {
                mapSnapshots = try await api.getMapSnapshots()
            } catch {
                logger.error("getMapSnapshots failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasMapSnapshots = false }
            }
        }

        // Load pending map change
        if hasPendingMapChange {
            do {
                let state = try await api.getPendingMapChange()
                pendingMapChangeEnabled = state.enabled
            } catch {
                logger.error("getPendingMapChange failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasPendingMapChange = false }
            }
        }

        // Load voice packs
        if hasVoicePack {
            do {
                let state = try await api.getVoicePackState()
                voicePacks = state.supportedLanguages ?? []
                currentVoicePackId = state.currentLanguage?.id ?? ""
            } catch {
                logger.error("getVoicePackState failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasVoicePack = false }
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
                logger.error("getAutoEmptyDockDuration failed: \(error, privacy: .public)")
                if !DebugConfig.showAllCapabilities { hasAutoEmptyDockDuration = false }
                autoEmptyDockDurationPresets = []
            }
        }

    }

    // MARK: - Actions
    func setVolume() async {
        guard let api = api else { return }

        do {
            try await api.setSpeakerVolume(Int(volume))
        } catch {
            logger.error("Failed to set volume: \(error, privacy: .public)")
        }
    }

    func testSpeaker() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.testSpeaker()
        } catch {
            hasSpeakerTest = false
            logger.debug("Speaker test not supported: \(error, privacy: .public)")
        }
    }

    func setCarpetMode(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetMode(enabled: enabled)
        } catch {
            logger.error("Failed to set carpet mode: \(error, privacy: .public)")
            carpetMode = !enabled
        }
    }

    func setPersistentMap(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPersistentMap(enabled: enabled)
        } catch {
            logger.error("Failed to set persistent map: \(error, privacy: .public)")
            persistentMap = !enabled
        }
    }

    func setKeyLock(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setKeyLock(enabled: enabled)
        } catch {
            logger.error("Failed to set key lock: \(error, privacy: .public)")
            keyLock = !enabled
        }
    }

    func setObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setObstacleAvoidance(enabled: enabled)
        } catch {
            logger.error("Failed to set obstacle avoidance: \(error, privacy: .public)")
            obstacleAvoidance = !enabled
        }
    }

    func setPetObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPetObstacleAvoidance(enabled: enabled)
        } catch {
            logger.error("Failed to set pet obstacle avoidance: \(error, privacy: .public)")
            petObstacleAvoidance = !enabled
        }
    }

    func setCarpetSensorMode(_ mode: String) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetSensorMode(mode: mode)
        } catch {
            logger.error("Failed to set carpet sensor mode: \(error, privacy: .public)")
            await loadCarpetSensorMode()
        }
    }

    private func loadCarpetSensorMode() async {
        guard let api = api else { return }
        do {
            carpetSensorMode = try await api.getCarpetSensorMode()
        } catch {
            // Ignore errors
        }
    }

    func resetMap() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.resetMap()
        } catch {
            logger.error("Failed to reset map: \(error, privacy: .public)")
        }
    }

    func startMappingPass() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.startMappingPass()
        } catch {
            logger.error("Failed to start mapping pass: \(error, privacy: .public)")
            hasMappingPass = false
        }
    }

    func setCollisionAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCollisionAvoidantNavigation(enabled: enabled)
        } catch {
            logger.error("Failed to set collision avoidance: \(error, privacy: .public)")
            collisionAvoidance = !enabled
        }
    }

    func setFloorMaterialNavigation(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setFloorMaterialNavigation(enabled: enabled)
        } catch {
            logger.error("Failed to set floor material navigation: \(error, privacy: .public)")
            floorMaterialNavigation = !enabled
        }
    }

    func setMopDockAutoDrying(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockAutoDrying(enabled: enabled)
        } catch {
            logger.error("Failed to set mop dock auto drying: \(error, privacy: .public)")
            mopDockAutoDrying = !enabled
        }
    }

    func setMopDockWashTemperature(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockWashTemperature(preset: preset)
        } catch {
            logger.error("Failed to set wash temperature: \(error, privacy: .public)")
        }
    }

    func setMopDockDryingTime(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setMopDockDryingTime(preset: preset)
            logger.info("Mop dock drying time set to: \(preset, privacy: .public)")
        } catch {
            logger.error("Failed to set mop dock drying time: \(error, privacy: .public)")
        }
    }

    func setAutoEmptyDockDuration(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setAutoEmptyDockDuration(preset: preset)
            logger.info("Auto empty dock duration set to: \(preset, privacy: .public)")
        } catch {
            logger.error("Failed to set auto empty dock duration: \(error, privacy: .public)")
        }
    }

    func setVoicePack(_ id: String) async {
        guard let api = api else { return }
        isSettingVoicePack = true
        defer { isSettingVoicePack = false }
        do {
            try await api.setVoicePack(id: id)
            logger.info("Voice pack set to: \(id, privacy: .public)")
        } catch {
            logger.error("Failed to set voice pack: \(error, privacy: .public)")
            errorRouter?.show(error)
            // Reload current state on error
            do {
                let state = try await api.getVoicePackState()
                currentVoicePackId = state.currentLanguage?.id ?? ""
            } catch {
                logger.error("getVoicePackState failed in setVoicePack: \(error, privacy: .public)")
                errorRouter?.show(error)
            }
        }
    }

    // MARK: - Map Snapshots
    func restoreMapSnapshot(_ snapshot: MapSnapshot) async {
        guard let api = api else { return }
        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }
        do {
            try await api.restoreMapSnapshot(id: snapshot.id)
            logger.info("Restored map snapshot: \(snapshot.id, privacy: .public)")
            do {
                mapSnapshots = try await api.getMapSnapshots()
            } catch {
                logger.error("getMapSnapshots reload failed: \(error, privacy: .public)")
                // mapSnapshots bleibt unveraendert — kein errorRouter noetig, ist nur ein Reload
            }
        } catch {
            logger.error("Failed to restore snapshot: \(error, privacy: .public)")
        }
    }

    // MARK: - Pending Map Change
    func acceptPendingMapChange() async {
        guard let api = api else { return }
        isHandlingMapChange = true
        defer { isHandlingMapChange = false }
        do {
            try await api.handlePendingMapChange(action: "accept")
            pendingMapChangeEnabled = false
            logger.info("Accepted pending map change")
        } catch {
            logger.error("Failed to accept map change: \(error, privacy: .public)")
        }
    }

    func rejectPendingMapChange() async {
        guard let api = api else { return }
        isHandlingMapChange = true
        defer { isHandlingMapChange = false }
        do {
            try await api.handlePendingMapChange(action: "reject")
            pendingMapChangeEnabled = false
            logger.info("Rejected pending map change")
        } catch {
            logger.error("Failed to reject map change: \(error, privacy: .public)")
        }
    }
}
