import Foundation
import SwiftUI
import os

@MainActor
class RobotManager: ObservableObject {
    @Published var robots: [RobotConfig] = []
    @Published var robotStates: [UUID: RobotStatus] = [:]
    @Published var robotUpdateAvailable: [UUID: Bool] = [:]

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotManager")
    private var apis: [UUID: ValetudoAPI] = [:]
    private var refreshTask: Task<Void, Never>?
    private var previousStates: [UUID: RobotStatus] = [:]
    private var lastConsumableCheck: [UUID: Date] = [:]
    private let storageKey = "valetudo_robots"
    private let notificationService = NotificationService.shared
    private let sseManager = SSEConnectionManager()

    init() {
        loadRobots()
        startRefreshing()
        notificationService.setupCategories()

        // Request notification permission
        Task {
            await notificationService.requestAuthorization()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Robot Management
    func addRobot(_ config: RobotConfig) {
        robots.append(config)
        if let pw = config.password, !pw.isEmpty {
            KeychainStore.save(password: pw, for: config.id)
        }
        apis[config.id] = ValetudoAPI(config: config)
        saveRobots()
        Task { await refreshRobot(config.id) }
    }

    func updateRobot(_ config: RobotConfig) {
        if let index = robots.firstIndex(where: { $0.id == config.id }) {
            robots[index] = config
            if let pw = config.password, !pw.isEmpty {
                KeychainStore.save(password: pw, for: config.id)
            }
            apis[config.id] = ValetudoAPI(config: config)
            saveRobots()
            Task { await refreshRobot(config.id) }
        }
    }

    func removeRobot(_ id: UUID) {
        // Disconnect SSE before clearing state so stream cleanup completes
        Task { await sseManager.disconnect(robotId: id) }
        KeychainStore.delete(for: id)
        robots.removeAll { $0.id == id }
        apis.removeValue(forKey: id)
        robotStates.removeValue(forKey: id)
        previousStates.removeValue(forKey: id)
        saveRobots()
    }

    func getAPI(for id: UUID) -> ValetudoAPI? {
        apis[id]
    }

    func getRobotName(for id: UUID) -> String {
        robots.first { $0.id == id }?.name ?? "Robot"
    }

    // MARK: - Status Refresh

    private func startRefreshing() {
        refreshTask = Task {
            while !Task.isCancelled {
                // Connect SSE for each robot that doesn't have an active connection yet
                for robot in robots {
                    guard let api = apis[robot.id] else { continue }
                    let sseActive = await sseManager.isSSEActive(for: robot.id)
                    if !sseActive {
                        let robotId = robot.id
                        await sseManager.connect(
                            robotId: robotId,
                            api: api,
                            onAttributesUpdate: { [weak self] attrs in
                                Task { @MainActor [weak self] in
                                    self?.applyAttributeUpdate(attrs, for: robotId)
                                }
                            },
                            onConnectionChange: { [weak self] connected in
                                Task { @MainActor [weak self] in
                                    self?.sseConnectionChanged(connected, for: robotId)
                                }
                            }
                        )
                    }
                }

                // Poll only robots without active SSE (fallback)
                await withTaskGroup(of: Void.self) { group in
                    for robot in robots {
                        group.addTask {
                            let sseActive = await self.sseManager.isSSEActive(for: robot.id)
                            if !sseActive {
                                await self.refreshRobot(robot.id)
                            }
                        }
                    }
                }

                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func refreshAllRobots() async {
        await withTaskGroup(of: Void.self) { group in
            for robot in robots {
                group.addTask { await self.refreshRobot(robot.id) }
            }
        }
    }

    func refreshRobot(_ id: UUID) async {
        guard let api = apis[id] else { return }
        let robotName = getRobotName(for: id)
        let previousState = previousStates[id]

        do {
            let attributes = try await api.getAttributes()
            let info = try await api.getRobotInfo()

            let newStatus = RobotStatus(
                isOnline: true,
                attributes: attributes,
                info: info
            )

            // Check for state changes and send notifications
            checkStateChanges(robotName: robotName, previous: previousState, current: newStatus)

            previousStates[id] = robotStates[id]
            robotStates[id] = newStatus

            // Check for updates and consumables (in background, don't block refresh)
            Task {
                await self.checkUpdateForRobot(id)
                await self.checkConsumables(for: id)
            }
        } catch {
            // Treat any error as offline signal — avoids double-request overhead of checkConnection()
            if previousState?.isOnline == true {
                notificationService.notifyRobotOffline(robotName: robotName)
            }
            previousStates[id] = robotStates[id]
            robotStates[id] = RobotStatus(isOnline: false)
        }
    }

    // MARK: - SSE Update Handling

    private func applyAttributeUpdate(_ attrs: [RobotAttribute], for id: UUID) {
        let existingInfo = robotStates[id]?.info
        let newStatus = RobotStatus(
            isOnline: true,
            attributes: attrs,
            info: existingInfo
        )
        let robotName = getRobotName(for: id)
        checkStateChanges(robotName: robotName, previous: previousStates[id], current: newStatus)
        previousStates[id] = robotStates[id]
        robotStates[id] = newStatus
    }

    private func sseConnectionChanged(_ connected: Bool, for id: UUID) {
        if connected {
            logger.info("SSE connection established for robot \(id, privacy: .public)")
        } else {
            logger.warning("SSE connection lost for robot \(id, privacy: .public) — falling back to polling")
        }
    }

    func checkUpdateForRobot(_ id: UUID) async {
        guard let api = apis[id] else { return }
        do {
            let updaterState = try await api.getUpdaterState()
            await MainActor.run {
                self.robotUpdateAvailable[id] = updaterState.isUpdateAvailable
            }
        } catch {
            // Silently ignore - not all robots support this
        }
    }

    // MARK: - State Change Notifications
    private func checkStateChanges(robotName: String, previous: RobotStatus?, current: RobotStatus) {
        guard let prevStatus = previous?.statusValue else { return }
        let currentStatus = current.statusValue ?? ""

        // Cleaning completed
        if prevStatus == "cleaning" && (currentStatus == "docked" || currentStatus == "idle") {
            notificationService.notifyCleaningComplete(robotName: robotName, area: current.cleanedArea)
        }

        // Robot stuck (specific flag)
        if current.statusFlag == "stuck" && previous?.statusFlag != "stuck" {
            notificationService.notifyRobotStuck(robotName: robotName)
        }

        // Robot error (general error state)
        if currentStatus == "error" && prevStatus != "error" {
            let errorMsg = current.statusFlag ?? String(localized: "status.error")
            notificationService.notifyRobotError(robotName: robotName, error: errorMsg)
        }
    }

    // MARK: - Check Consumables
    func checkConsumables(for id: UUID) async {
        guard let api = apis[id] else { return }

        // Only check consumables once per hour to avoid spam
        if let lastCheck = lastConsumableCheck[id],
           Date().timeIntervalSince(lastCheck) < 3600 {
            return
        }

        lastConsumableCheck[id] = Date()
        let robotName = getRobotName(for: id)

        do {
            let consumables = try await api.getConsumables()
            for consumable in consumables {
                if consumable.remainingPercent < 15 {
                    notificationService.notifyConsumableLow(
                        robotName: robotName,
                        consumableName: consumable.displayName,
                        percent: Int(consumable.remainingPercent)
                    )
                }
            }
        } catch {
            // Silently ignore consumable check failures
        }
    }

    // MARK: - Persistence
    private func loadRobots() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) else { return }

        var migratedRobots = decoded
        var migrationOccurred = false

        for (index, robot) in decoded.enumerated() {
            // Skip if already in Keychain
            guard KeychainStore.password(for: robot.id) == nil else {
                apis[robot.id] = ValetudoAPI(config: migratedRobots[index])
                continue
            }

            // Migrate password from UserDefaults JSON blob to Keychain
            if let legacyPassword = robot.password, !legacyPassword.isEmpty {
                let saved = KeychainStore.save(password: legacyPassword, for: robot.id)
                // Read-back verification — only mark migration if verified in Keychain
                if saved, KeychainStore.password(for: robot.id) != nil {
                    migratedRobots[index].password = nil
                    migrationOccurred = true
                }
            }
            apis[robot.id] = ValetudoAPI(config: migratedRobots[index])
        }

        robots = migratedRobots
        if migrationOccurred { saveRobots() } // Re-save without passwords in blob
    }

    private func saveRobots() {
        if let encoded = try? JSONEncoder().encode(robots) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Robot Status
struct RobotStatus {
    let isOnline: Bool
    let attributes: [RobotAttribute]
    let info: RobotInfo?

    init(isOnline: Bool, attributes: [RobotAttribute] = [], info: RobotInfo? = nil) {
        self.isOnline = isOnline
        self.attributes = attributes
        self.info = info
    }

    var batteryLevel: Int? {
        attributes.first { $0.__class == "BatteryStateAttribute" }?.level
    }

    var batteryStatus: String? {
        attributes.first { $0.__class == "BatteryStateAttribute" }?.flag
    }

    var statusValue: String? {
        attributes.first { $0.__class == "StatusStateAttribute" }?.value
    }

    var statusFlag: String? {
        attributes.first { $0.__class == "StatusStateAttribute" }?.flag
    }

    var cleanedArea: Int? {
        // Area in cm² from CurrentStatisticsAttribute
        if let areaAttr = attributes.first(where: { $0.__class == "LatestCleanupStatisticsAttribute" && $0.type == "area" }) {
            return areaAttr.value.flatMap { Int($0) }
        }
        return nil
    }

    // MARK: - Attachment States
    var dustbinAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "dustbin" }) {
            return attr.value == "true"
        }
        return nil
    }

    var mopAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "mop" }) {
            return attr.value == "true"
        }
        return nil
    }

    var waterTankAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "watertank" }) {
            return attr.value == "true"
        }
        return nil
    }

    // Returns true if any attachment is missing that the robot expects
    var hasMissingAttachments: Bool {
        // Only check attachments that the robot reports (not nil)
        if dustbinAttached == false { return true }
        if mopAttached == false { return true }
        if waterTankAttached == false { return true }
        return false
    }
}
