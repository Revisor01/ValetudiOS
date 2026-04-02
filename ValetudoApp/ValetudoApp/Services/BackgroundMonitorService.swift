import BackgroundTasks
import Foundation
import os

final class BackgroundMonitorService {
    static let shared = BackgroundMonitorService()
    static let taskIdentifier = "de.simonluthe.ValetudiOS.backgroundRefresh"

    private let logger = Logger(subsystem: "de.simonluthe.ValetudiOS", category: "BackgroundMonitor")
    private let robotConfigsKey = "valetudo_robots"

    private init() {}

    // MARK: - Public API

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundMonitorService.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // 1. Sofort reschedulen — garantiert naechsten Zyklus auch wenn dieser Task abbricht
        scheduleBackgroundRefresh()

        // 2. Swift Task fuer async Arbeit
        let workTask = Task {
            await checkAllRobots()
        }

        // 3. Expiration Handler — iOS kann den Task jederzeit abbrechen
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }

        // 4. Nach Abschluss completion aufrufen
        Task {
            _ = await workTask.result
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Private: Robot Checks

    private func checkAllRobots() async {
        let configs = loadRobotConfigs()
        for config in configs {
            guard !Task.isCancelled else { break }
            await checkRobot(config: config)
        }
    }

    private func checkRobot(config: RobotConfig) async {
        let api = ValetudoAPI(config: config)
        do {
            let attributes = try await api.getAttributes()
            let newStatus = PersistedRobotStatus(attributes: attributes)
            let previous = loadPersistedStatus(for: config.id)
            checkStateChanges(robotName: config.name, previous: previous, current: newStatus)
            saveStatus(newStatus, for: config.id)
        } catch {
            logger.warning("Background check failed for \(config.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkStateChanges(robotName: String, previous: PersistedRobotStatus?, current: PersistedRobotStatus) {
        guard let prevStatus = previous?.statusValue else { return }
        let currentStatus = current.statusValue ?? ""

        // Reinigung abgeschlossen
        if prevStatus == "cleaning" && (currentStatus == "docked" || currentStatus == "idle") {
            Task { @MainActor in
                NotificationService.shared.notifyCleaningComplete(robotName: robotName, area: nil)
            }
        }

        // Roboter steckt fest
        if current.statusFlag == "stuck" && previous?.statusFlag != "stuck" {
            Task { @MainActor in
                NotificationService.shared.notifyRobotStuck(robotName: robotName)
            }
        }

        // Roboter im Fehler-Zustand
        if currentStatus == "error" && prevStatus != "error" {
            let errorMsg = current.statusFlag ?? String(localized: "status.error")
            Task { @MainActor in
                NotificationService.shared.notifyRobotError(robotName: robotName, error: errorMsg)
            }
        }
    }

    // MARK: - Persistence

    private struct PersistedRobotStatus: Codable {
        let statusValue: String?
        let statusFlag: String?
        let timestamp: Date

        init(attributes: [RobotAttribute]) {
            let statusAttr = attributes.first { $0.__class == "StatusStateAttribute" }
            statusValue = statusAttr?.value
            statusFlag = statusAttr?.flag
            timestamp = Date()
        }
    }

    private func userDefaultsKey(for robotId: UUID) -> String {
        "bg_last_status_\(robotId.uuidString)"
    }

    private func loadRobotConfigs() -> [RobotConfig] {
        guard let data = UserDefaults.standard.data(forKey: robotConfigsKey),
              let configs = try? JSONDecoder().decode([RobotConfig].self, from: data)
        else { return [] }
        return configs
    }

    private func loadPersistedStatus(for robotId: UUID) -> PersistedRobotStatus? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: robotId)),
              let decoded = try? JSONDecoder().decode(PersistedRobotStatus.self, from: data)
        else { return nil }
        return decoded
    }

    private func saveStatus(_ status: PersistedRobotStatus, for robotId: UUID) {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey(for: robotId))
        }
    }
}
