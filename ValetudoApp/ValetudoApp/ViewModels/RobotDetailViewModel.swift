import Foundation
import SwiftUI
import os

@MainActor
final class RobotDetailViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotDetailViewModel")

    // MARK: - Identity
    let robot: RobotConfig
    let robotManager: RobotManager

    // MARK: - Data state
    @Published var segments: [Segment] = []
    @Published var consumables: [Consumable] = []
    @Published var selectedSegments: Set<String> = []
    @Published var selectedIterations: Int = 1
    @Published var isLoading = false

    // Intensity control presets
    @Published var fanSpeedPresets: [String] = []
    @Published var waterUsagePresets: [String] = []
    @Published var operationModePresets: [String] = []

    // Capability flags
    @Published var hasManualControl = DebugConfig.showAllCapabilities
    @Published var hasAutoEmptyTrigger = DebugConfig.showAllCapabilities
    @Published var hasMopDockClean = DebugConfig.showAllCapabilities
    @Published var hasMopDockDry = DebugConfig.showAllCapabilities
    @Published var hasEvents = DebugConfig.showAllCapabilities
    @Published var hasCleanRoute = DebugConfig.showAllCapabilities
    @Published var hasObstacleImages = DebugConfig.showAllCapabilities

    // Update state
    @Published var currentVersion: String?
    @Published var latestVersion: String?
    @Published var updateUrl: String?
    @Published var updaterState: UpdaterState?
    @Published var isUpdating = false
    @Published var showUpdateWarning = false
    @Published var updateInProgress = false

    // Statistics
    @Published var lastCleaningStats: [StatisticEntry] = []
    @Published var totalStats: [StatisticEntry] = []

    // Events
    @Published var events: [ValetudoEvent] = []

    // Clean Route
    @Published var cleanRoutePresets: [String] = []
    @Published var currentCleanRoute: String = ""

    // Obstacles (from map entities)
    @Published var obstacles: [(id: String, label: String?)] = []

    // Robot Properties
    @Published var robotProperties: RobotProperties?

    // Live stats polling
    private var statsPollingTask: Task<Void, Never>?

    // MARK: - Computed properties

    var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    var isCleaning: Bool {
        status?.statusValue?.lowercased() == "cleaning"
    }

    var isPaused: Bool {
        status?.statusValue?.lowercased() == "paused"
    }

    var isRunning: Bool {
        let s = status?.statusValue?.lowercased() ?? ""
        return s == "cleaning" || s == "returning" || s == "moving"
    }

    var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var currentFanSpeed: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "fan_speed"
        })?.value
    }

    var currentWaterUsage: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "water_grade"
        })?.value
    }

    var currentOperationMode: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "operation_mode"
        })?.value
    }

    var hasConsumableWarning: Bool {
        consumables.contains { $0.remainingPercent < 20 }
    }

    // MARK: - Init

    init(robot: RobotConfig, robotManager: RobotManager) {
        self.robot = robot
        self.robotManager = robotManager
    }

    // MARK: - Data Loading

    func loadData() async {
        guard api != nil else { return }
        async let segmentsTask: () = loadSegments()
        async let consumablesTask: () = loadConsumables()
        async let capabilitiesTask: () = loadCapabilities()
        async let fanSpeedTask: () = loadFanSpeedPresets()
        async let updateTask: () = checkForUpdate()
        async let statsTask: () = loadLastCleaningStats()
        async let eventsTask: () = loadEvents()
        async let cleanRouteTask: () = loadCleanRoute()
        async let obstaclesTask: () = loadObstacles()
        async let propertiesTask: () = loadRobotProperties()
        _ = await (segmentsTask, consumablesTask, capabilitiesTask, fanSpeedTask, updateTask, statsTask, eventsTask, cleanRouteTask, obstaclesTask, propertiesTask)
    }

    func refreshData() async {
        await robotManager.refreshRobot(robot.id)
        await loadData()
    }

    private func loadSegments() async {
        guard let api = api else { return }
        do {
            segments = try await api.getSegments()
        } catch {
            logger.error("Failed to load segments: \(error, privacy: .public)")
        }
    }

    private func loadConsumables() async {
        guard let api = api else { return }
        do {
            consumables = try await api.getConsumables()
        } catch {
            logger.error("Failed to load consumables: \(error, privacy: .public)")
        }
    }

    private func loadCapabilities() async {
        guard let api = api else { return }
        do {
            let capabilities = try await api.getCapabilities()
            hasManualControl = DebugConfig.showAllCapabilities || capabilities.contains("HighResolutionManualControlCapability")
            hasAutoEmptyTrigger = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockManualTriggerCapability")
            hasMopDockClean = DebugConfig.showAllCapabilities || capabilities.contains("MopDockCleanManualTriggerCapability")
            hasMopDockDry = DebugConfig.showAllCapabilities || capabilities.contains("MopDockDryManualTriggerCapability")
            hasEvents = true // Events are always available (no capability gate in Valetudo)
            hasCleanRoute = DebugConfig.showAllCapabilities || capabilities.contains("CleanRouteControlCapability")
            hasObstacleImages = DebugConfig.showAllCapabilities || capabilities.contains("ObstacleImagesCapability")
        } catch {
            logger.error("Failed to load capabilities: \(error, privacy: .public)")
        }
    }

    private func loadFanSpeedPresets() async {
        guard let api = api else { return }
        do {
            fanSpeedPresets = try await api.getFanSpeedPresets()
        } catch {
            logger.debug("Fan speed not supported: \(error, privacy: .public)")
            if DebugConfig.showAllCapabilities && fanSpeedPresets.isEmpty {
                fanSpeedPresets = ["low", "medium", "high", "max"]
            }
        }

        do {
            waterUsagePresets = try await api.getWaterUsagePresets().filter { $0.lowercased() != "off" }
        } catch {
            logger.debug("Water usage not supported: \(error, privacy: .public)")
            if DebugConfig.showAllCapabilities && waterUsagePresets.isEmpty {
                waterUsagePresets = ["low", "medium", "high"]
            }
        }

        do {
            operationModePresets = try await api.getOperationModePresets()
        } catch {
            logger.debug("Operation mode not supported: \(error, privacy: .public)")
            if DebugConfig.showAllCapabilities && operationModePresets.isEmpty {
                operationModePresets = ["vacuum", "mop", "vacuum_and_mop"]
            }
        }
    }

    func loadLastCleaningStats() async {
        guard let api = api else { return }
        do {
            let stats = try await api.getCurrentStatistics()
            lastCleaningStats = stats
        } catch {
            // Silently fail - not all robots support this
        }
        do {
            let stats = try await api.getTotalStatistics()
            totalStats = stats
        } catch {
            // Silently fail - not all robots support this
        }
    }

    private func loadEvents() async {
        guard let api = api else { return }
        do {
            events = try await api.getEvents()
        } catch {
            logger.error("Failed to load events: \(error, privacy: .public)")
            if !DebugConfig.showAllCapabilities { hasEvents = false }
        }
    }

    private func loadCleanRoute() async {
        guard let api = api else { return }
        do {
            let state = try await api.getCleanRoute()
            currentCleanRoute = state.route
            cleanRoutePresets = try await api.getCleanRoutePresets()
        } catch {
            logger.debug("Clean route not supported: \(error, privacy: .public)")
            if !DebugConfig.showAllCapabilities { hasCleanRoute = false }
        }
    }

    private func loadObstacles() async {
        guard let api = api else { return }
        do {
            let mapData = try await api.getMap()
            let obstacleEntities = (mapData.entities ?? []).filter {
                $0.metaData?.id != nil
            }
            obstacles = obstacleEntities.compactMap { entity in
                guard let id = entity.metaData?.id else { return nil }
                return (id: id, label: entity.metaData?.label)
            }
        } catch {
            logger.debug("Failed to load obstacles from map: \(error, privacy: .public)")
        }
    }

    private func loadRobotProperties() async {
        guard let api = api else { return }
        do {
            robotProperties = try await api.getRobotProperties()
        } catch {
            logger.debug("Robot properties not available: \(error, privacy: .public)")
            // Non-fatal: section wird ausgeblendet wenn nil
        }
    }

    private func checkForUpdate() async {
        guard let api = api else { return }
        do {
            if let version = try? await api.getValetudoVersion() {
                currentVersion = version.release
            }

            try? await api.checkForUpdates()

            let state = try await api.getUpdaterState()
            updaterState = state

            let url = URL(string: "https://api.github.com/repos/Hypfer/Valetudo/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = release.tag_name
            updateUrl = release.html_url
        } catch {
            logger.error("Failed to check for updates: \(error, privacy: .public)")
        }
    }

    // MARK: - Stats Polling

    func startStatsPolling() {
        stopStatsPolling()
        statsPollingTask = Task {
            while !Task.isCancelled {
                await loadLastCleaningStats()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopStatsPolling() {
        statsPollingTask?.cancel()
        statsPollingTask = nil
    }

    // MARK: - Robot Actions

    func performAction(_ action: BasicAction) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.basicControl(action: action)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Action failed: \(error, privacy: .public)")
        }
    }

    func locate() async {
        guard let api = api else { return }
        try? await api.locate()
    }

    func cleanSelectedRooms() async {
        guard let api = api, !selectedSegments.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.cleanSegments(ids: Array(selectedSegments), iterations: selectedIterations)
            selectedSegments.removeAll()
            selectedIterations = 1
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Clean failed: \(error, privacy: .public)")
        }
    }

    func toggleSegment(_ id: String) {
        if selectedSegments.contains(id) {
            selectedSegments.remove(id)
        } else {
            selectedSegments.insert(id)
        }
    }

    // MARK: - Intensity Settings

    func setFanSpeed(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setFanSpeed(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Failed to set fan speed: \(error, privacy: .public)")
        }
    }

    func setWaterUsage(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setWaterUsage(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Failed to set water usage: \(error, privacy: .public)")
        }
    }

    func setOperationMode(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setOperationMode(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Failed to set operation mode: \(error, privacy: .public)")
        }
    }

    // MARK: - Dock Actions

    func triggerAutoEmpty() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerAutoEmptyDock()
        } catch {
            logger.error("Failed to trigger auto empty: \(error, privacy: .public)")
        }
    }

    func triggerMopDockClean() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockClean()
        } catch {
            logger.error("Failed to trigger mop clean: \(error, privacy: .public)")
        }
    }

    func triggerMopDockDry() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockDry()
        } catch {
            logger.error("Failed to trigger mop dry: \(error, privacy: .public)")
        }
    }

    // MARK: - Consumable Reset

    func resetConsumable(_ consumable: Consumable) async {
        guard let api = api else { return }
        do {
            try await api.resetConsumable(type: consumable.type, subType: consumable.subType)
            await loadConsumables()
        } catch {
            logger.error("Failed to reset consumable: \(error, privacy: .public)")
        }
    }

    // MARK: - Events

    func dismissEvent(_ event: ValetudoEvent) async {
        guard let api = api else { return }
        do {
            try await api.dismissEvent(id: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            logger.error("Failed to dismiss event: \(error, privacy: .public)")
        }
    }

    // MARK: - Clean Route

    func setCleanRoute(_ route: String) async {
        guard let api = api else { return }
        do {
            try await api.setCleanRoute(route: route)
            currentCleanRoute = route
        } catch {
            logger.error("Failed to set clean route: \(error, privacy: .public)")
        }
    }

    // MARK: - Update

    func startUpdate() async {
        guard let api = api else { return }

        let needsDownload = updaterState?.isUpdateAvailable == true && updaterState?.isReadyToApply != true
        let needsApply = updaterState?.isReadyToApply == true

        updateInProgress = true

        do {
            if needsDownload {
                try await api.downloadUpdate()

                var downloadComplete = false
                for _ in 0..<60 {
                    try? await Task.sleep(for: .seconds(5))
                    let state = try await api.getUpdaterState()
                    updaterState = state
                    if state.isReadyToApply {
                        downloadComplete = true
                        break
                    }
                    if !state.isDownloading && !state.isReadyToApply {
                        break
                    }
                }

                if !downloadComplete {
                    updateInProgress = false
                    return
                }
            }

            if needsApply || needsDownload {
                try await api.applyUpdate()
                // Keep showing progress - robot will be offline
            }
        } catch {
            logger.error("Update failed: \(error, privacy: .public)")
            updateInProgress = false
        }
    }
}
