import Foundation
import SwiftUI

@MainActor
final class RobotDetailViewModel: ObservableObject {

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
        _ = await (segmentsTask, consumablesTask, capabilitiesTask, fanSpeedTask, updateTask, statsTask)
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
            print("Failed to load segments: \(error)")
        }
    }

    private func loadConsumables() async {
        guard let api = api else { return }
        do {
            consumables = try await api.getConsumables()
        } catch {
            print("Failed to load consumables: \(error)")
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
        } catch {
            print("Failed to load capabilities: \(error)")
        }
    }

    private func loadFanSpeedPresets() async {
        guard let api = api else { return }
        do {
            fanSpeedPresets = try await api.getFanSpeedPresets()
        } catch {
            print("Fan speed not supported: \(error)")
            if DebugConfig.showAllCapabilities && fanSpeedPresets.isEmpty {
                fanSpeedPresets = ["low", "medium", "high", "max"]
            }
        }

        do {
            waterUsagePresets = try await api.getWaterUsagePresets()
        } catch {
            print("Water usage not supported: \(error)")
            if DebugConfig.showAllCapabilities && waterUsagePresets.isEmpty {
                waterUsagePresets = ["low", "medium", "high"]
            }
        }

        do {
            operationModePresets = try await api.getOperationModePresets()
        } catch {
            print("Operation mode not supported: \(error)")
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
            print("Failed to check for updates: \(error)")
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
            print("Action failed: \(error)")
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
            print("Clean failed: \(error)")
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
            print("Failed to set fan speed: \(error)")
        }
    }

    func setWaterUsage(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setWaterUsage(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set water usage: \(error)")
        }
    }

    func setOperationMode(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setOperationMode(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set operation mode: \(error)")
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
            print("Failed to trigger auto empty: \(error)")
        }
    }

    func triggerMopDockClean() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockClean()
        } catch {
            print("Failed to trigger mop clean: \(error)")
        }
    }

    func triggerMopDockDry() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockDry()
        } catch {
            print("Failed to trigger mop dry: \(error)")
        }
    }

    // MARK: - Consumable Reset

    func resetConsumable(_ consumable: Consumable) async {
        guard let api = api else { return }
        do {
            try await api.resetConsumable(type: consumable.type, subType: consumable.subType)
            await loadConsumables()
        } catch {
            print("Failed to reset consumable: \(error)")
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
            print("Update failed: \(error)")
            updateInProgress = false
        }
    }
}
