import Foundation
import Network
import os

actor SSEConnectionManager {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "SSE")

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var isConnected: [UUID: Bool] = [:]

    // Stored connect params for reconnect-on-network-change
    private struct ConnectionParams {
        let api: ValetudoAPI
        let onAttributesUpdate: @Sendable ([RobotAttribute]) -> Void
        let onConnectionChange: @Sendable (Bool) -> Void
    }
    private var connectionParams: [UUID: ConnectionParams] = [:]

    // NWPathMonitor for detecting network path changes
    private var pathMonitor: NWPathMonitor?
    private var pathMonitorQueue: DispatchQueue?
    private var lastPathStatus: NWPath.Status = .satisfied

    // MARK: - Public Interface

    func isSSEActive(for robotId: UUID) -> Bool {
        isConnected[robotId] == true
    }

    func connect(
        robotId: UUID,
        api: ValetudoAPI,
        onAttributesUpdate: @escaping @Sendable ([RobotAttribute]) -> Void,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) {
        // Cancel any existing task for this robot
        tasks[robotId]?.cancel()
        tasks[robotId] = nil
        isConnected[robotId] = false

        // Store params for potential reconnect on network change
        connectionParams[robotId] = ConnectionParams(
            api: api,
            onAttributesUpdate: onAttributesUpdate,
            onConnectionChange: onConnectionChange
        )

        let task = Task {
            await self.streamWithReconnect(
                robotId: robotId,
                api: api,
                onAttributesUpdate: onAttributesUpdate,
                onConnectionChange: onConnectionChange
            )
        }
        tasks[robotId] = task

        // Start path monitor if not already running
        startPathMonitorIfNeeded()
    }

    func disconnect(robotId: UUID) {
        tasks[robotId]?.cancel()
        tasks.removeValue(forKey: robotId)
        isConnected.removeValue(forKey: robotId)
        connectionParams.removeValue(forKey: robotId)
        logger.info("SSE disconnected for robot \(robotId, privacy: .public)")

        if tasks.isEmpty {
            stopPathMonitor()
        }
    }

    func disconnectAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
        isConnected.removeAll()
        connectionParams.removeAll()
        stopPathMonitor()
        logger.info("SSE disconnected for all robots")
    }

    // MARK: - NWPathMonitor

    private func startPathMonitorIfNeeded() {
        guard pathMonitor == nil else { return }

        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "SSEPathMonitor", qos: .utility)
        pathMonitor = monitor
        pathMonitorQueue = queue

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task {
                await self.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        logger.info("SSE NWPathMonitor started")
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        pathMonitorQueue = nil
        logger.info("SSE NWPathMonitor stopped")
    }

    private func handlePathUpdate(_ path: NWPath) {
        let previousStatus = lastPathStatus
        lastPathStatus = path.status

        // Reconnect when network becomes available after being unavailable
        guard path.status == .satisfied, previousStatus != .satisfied else { return }

        logger.info("SSE network path restored — reconnecting all active SSE streams")
        reconnectAll()
    }

    private func reconnectAll() {
        let snapshot = connectionParams

        for (robotId, params) in snapshot {
            // Cancel existing task
            tasks[robotId]?.cancel()
            tasks[robotId] = nil
            isConnected[robotId] = false

            let task = Task {
                await self.streamWithReconnect(
                    robotId: robotId,
                    api: params.api,
                    onAttributesUpdate: params.onAttributesUpdate,
                    onConnectionChange: params.onConnectionChange
                )
            }
            tasks[robotId] = task
            logger.info("SSE reconnect triggered for robot \(robotId, privacy: .public) after network change")
        }
    }

    // MARK: - Private Streaming

    private let maxRetries = 20

    private func streamWithReconnect(
        robotId: UUID,
        api: ValetudoAPI,
        onAttributesUpdate: @escaping @Sendable ([RobotAttribute]) -> Void,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) async {
        let decoder = JSONDecoder()
        var retryCount = 0

        while !Task.isCancelled && retryCount < maxRetries {
            do {
                let bytes = try await api.streamStateLines()

                // Successful connection — reset backoff
                retryCount = 0
                isConnected[robotId] = true
                onConnectionChange(true)
                logger.info("SSE connected for robot \(robotId, privacy: .public)")

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    guard line.hasPrefix("data:") else { continue }

                    let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    guard !jsonString.isEmpty,
                          let jsonData = jsonString.data(using: .utf8) else { continue }

                    do {
                        let attributes = try decoder.decode([RobotAttribute].self, from: jsonData)
                        onAttributesUpdate(attributes)
                    } catch {
                        logger.warning("SSE decode error for robot \(robotId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }

            } catch is CancellationError {
                // Task was cancelled — exit cleanly without retry
                break
            } catch {
                logger.warning("SSE connection error for robot \(robotId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                isConnected[robotId] = false
                onConnectionChange(false)

                // Exponential backoff: 1s → 5s → 30s (capped)
                retryCount += 1
                let delay: Double
                switch retryCount {
                case 1:  delay = 1
                case 2:  delay = 5
                default: delay = 30
                }
                logger.info("SSE retry \(retryCount, privacy: .public) for robot \(robotId, privacy: .public) — waiting \(delay, privacy: .public)s")

                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch is CancellationError {
                    break
                } catch {
                    break
                }
            }
        }

        // Cleanup on exit
        isConnected[robotId] = false
        if retryCount >= maxRetries {
            logger.warning("SSE retry limit (\(self.maxRetries, privacy: .public)) reached for robot \(robotId, privacy: .public) — falling back to polling")
        }
        logger.info("SSE stream ended for robot \(robotId, privacy: .public)")
    }
}
