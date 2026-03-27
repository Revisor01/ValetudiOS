import Foundation
import SwiftUI

@MainActor
final class RobotSettingsViewModel: ObservableObject {
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

    // MARK: - Presets
    @Published var carpetSensorModePresets: [String] = []
    @Published var mopDockWashTemperaturePresets: [String] = []

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

        // Mark initial load as complete to enable onChange handlers
        isInitialLoad = false
    }

    // MARK: - Actions
    func setVolume() async {
        guard let api = api else { return }

        do {
            try await api.setSpeakerVolume(Int(volume))
        } catch {
            print("Failed to set volume: \(error)")
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
            print("Speaker test not supported: \(error)")
        }
    }

    func setCarpetMode(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetMode(enabled: enabled)
        } catch {
            print("Failed to set carpet mode: \(error)")
            carpetMode = !enabled
        }
    }

    func setPersistentMap(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPersistentMap(enabled: enabled)
        } catch {
            print("Failed to set persistent map: \(error)")
            persistentMap = !enabled
        }
    }

    func setKeyLock(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setKeyLock(enabled: enabled)
        } catch {
            print("Failed to set key lock: \(error)")
            keyLock = !enabled
        }
    }

    func setObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setObstacleAvoidance(enabled: enabled)
        } catch {
            print("Failed to set obstacle avoidance: \(error)")
            obstacleAvoidance = !enabled
        }
    }

    func setPetObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPetObstacleAvoidance(enabled: enabled)
        } catch {
            print("Failed to set pet obstacle avoidance: \(error)")
            petObstacleAvoidance = !enabled
        }
    }

    func setCarpetSensorMode(_ mode: String) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetSensorMode(mode: mode)
        } catch {
            print("Failed to set carpet sensor mode: \(error)")
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
            print("Failed to reset map: \(error)")
        }
    }

    func startMappingPass() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.startMappingPass()
        } catch {
            print("Failed to start mapping pass: \(error)")
            hasMappingPass = false
        }
    }

    func setCollisionAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCollisionAvoidantNavigation(enabled: enabled)
        } catch {
            print("Failed to set collision avoidance: \(error)")
            collisionAvoidance = !enabled
        }
    }

    func setFloorMaterialNavigation(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setFloorMaterialNavigation(enabled: enabled)
        } catch {
            print("Failed to set floor material navigation: \(error)")
            floorMaterialNavigation = !enabled
        }
    }

    func setMopDockAutoDrying(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockAutoDrying(enabled: enabled)
        } catch {
            print("Failed to set mop dock auto drying: \(error)")
            mopDockAutoDrying = !enabled
        }
    }

    func setMopDockWashTemperature(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockWashTemperature(preset: preset)
        } catch {
            print("Failed to set wash temperature: \(error)")
        }
    }
}
