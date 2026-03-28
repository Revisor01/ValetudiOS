import Foundation
import SwiftUI
import os

@MainActor
final class RobotSettingsViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotSettingsViewModel")
    let robot: RobotConfig
    private let robotManager: RobotManager

    // MARK: - Settings values
    @Published var volume: Double = 80
    @Published var carpetMode = false
    @Published var persistentMap = false
    @Published var keyLock = false
    @Published var obstacleAvoidance = false
    @Published var petObstacleAvoidance = false
    @Published var collisionAvoidance = false
    @Published var mopDockAutoDrying = false
    @Published var floorMaterialNavigation = false
    @Published var carpetSensorMode: String = ""
    @Published var currentWashTemperature: String = ""

    // MARK: - Capability flags
    @Published var hasVolumeControl = DebugConfig.showAllCapabilities
    @Published var hasSpeakerTest = DebugConfig.showAllCapabilities
    @Published var hasCarpetMode = DebugConfig.showAllCapabilities
    @Published var hasPersistentMap = DebugConfig.showAllCapabilities
    @Published var hasMappingPass = DebugConfig.showAllCapabilities
    @Published var hasAutoEmptyDock = DebugConfig.showAllCapabilities
    @Published var hasQuirks = DebugConfig.showAllCapabilities
    @Published var hasWifiConfig = DebugConfig.showAllCapabilities
    @Published var hasWifiScan = DebugConfig.showAllCapabilities
    @Published var hasKeyLock = DebugConfig.showAllCapabilities
    @Published var hasObstacleAvoidance = DebugConfig.showAllCapabilities
    @Published var hasPetObstacleAvoidance = DebugConfig.showAllCapabilities
    @Published var hasCarpetSensorMode = DebugConfig.showAllCapabilities
    @Published var hasMapReset = DebugConfig.showAllCapabilities
    @Published var hasCollisionAvoidance = DebugConfig.showAllCapabilities
    @Published var hasMopDockAutoDrying = DebugConfig.showAllCapabilities
    @Published var hasMopDockWashTemperature = DebugConfig.showAllCapabilities
    @Published var hasFloorMaterialNavigation = DebugConfig.showAllCapabilities
    @Published var hasMapSnapshots = DebugConfig.showAllCapabilities
    @Published var hasPendingMapChange = DebugConfig.showAllCapabilities

    // MARK: - Presets
    @Published var carpetSensorModePresets: [String] = []
    @Published var mopDockWashTemperaturePresets: [String] = []

    // MARK: - Map Snapshots state
    @Published var mapSnapshots: [MapSnapshot] = []
    @Published var isRestoringSnapshot = false

    // MARK: - Pending Map Change state
    @Published var pendingMapChangeEnabled = false
    @Published var isHandlingMapChange = false

    // MARK: - UI state
    @Published var isLoading = false
    @Published var isInitialLoad = true
    @Published var volumeChanged = false

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
        isLoading = true
        defer { isLoading = false }

        // Load speaker volume
        do {
            volume = Double(try await api.getSpeakerVolume())
        } catch {
            if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
        }

        // Load carpet mode
        do {
            carpetMode = try await api.getCarpetMode()
        } catch {
            if !DebugConfig.showAllCapabilities { hasCarpetMode = false }
        }

        // Load persistent map
        do {
            persistentMap = try await api.getPersistentMap()
        } catch {
            if !DebugConfig.showAllCapabilities { hasPersistentMap = false }
        }

        // Check capabilities
        do {
            let capabilities = try await api.getCapabilities()
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
            hasFloorMaterialNavigation = DebugConfig.showAllCapabilities || capabilities.contains("FloorMaterialDirectionAwareNavigationControlCapability")
            hasMapSnapshots = DebugConfig.showAllCapabilities || capabilities.contains("MapSnapshotCapability")
            hasPendingMapChange = DebugConfig.showAllCapabilities || capabilities.contains("PendingMapChangeHandlingCapability")
        } catch {
            hasMappingPass = DebugConfig.showAllCapabilities
        }

        // Load key lock state
        if hasKeyLock {
            do {
                keyLock = try await api.getKeyLock()
            } catch {
                if !DebugConfig.showAllCapabilities { hasKeyLock = false }
            }
        }

        // Load obstacle avoidance state
        if hasObstacleAvoidance {
            do {
                obstacleAvoidance = try await api.getObstacleAvoidance()
            } catch {
                if !DebugConfig.showAllCapabilities { hasObstacleAvoidance = false }
            }
        }

        // Load pet obstacle avoidance state
        if hasPetObstacleAvoidance {
            do {
                petObstacleAvoidance = try await api.getPetObstacleAvoidance()
            } catch {
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
                if !DebugConfig.showAllCapabilities { hasCollisionAvoidance = false }
            }
        }

        // Load floor material navigation
        if hasFloorMaterialNavigation {
            do {
                floorMaterialNavigation = try await api.getFloorMaterialNavigation()
            } catch {
                if !DebugConfig.showAllCapabilities { hasFloorMaterialNavigation = false }
            }
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
                mopDockWashTemperaturePresets = []
            }
        }

        // Load map snapshots
        if hasMapSnapshots {
            do {
                mapSnapshots = try await api.getMapSnapshots()
            } catch {
                if !DebugConfig.showAllCapabilities { hasMapSnapshots = false }
                logger.debug("Map snapshots not supported: \(error, privacy: .public)")
            }
        }

        // Load pending map change
        if hasPendingMapChange {
            do {
                let state = try await api.getPendingMapChange()
                pendingMapChangeEnabled = state.enabled
            } catch {
                if !DebugConfig.showAllCapabilities { hasPendingMapChange = false }
                logger.debug("Pending map change not supported: \(error, privacy: .public)")
            }
        }

        // Mark initial load as complete to enable onChange handlers
        isInitialLoad = false
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

    // MARK: - Map Snapshots
    func restoreMapSnapshot(_ snapshot: MapSnapshot) async {
        guard let api = api else { return }
        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }
        do {
            try await api.restoreMapSnapshot(id: snapshot.id)
            mapSnapshots = (try? await api.getMapSnapshots()) ?? mapSnapshots
            logger.info("Restored map snapshot: \(snapshot.id, privacy: .public)")
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
