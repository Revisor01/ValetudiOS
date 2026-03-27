import Foundation
import os

actor SSEConnectionManager {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "SSE")

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var isConnected: [UUID: Bool] = [:]

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

        let task = Task {
            await self.streamWithReconnect(
                robotId: robotId,
                api: api,
                onAttributesUpdate: onAttributesUpdate,
                onConnectionChange: onConnectionChange
            )
        }
        tasks[robotId] = task
    }

    func disconnect(robotId: UUID) {
        tasks[robotId]?.cancel()
        tasks.removeValue(forKey: robotId)
        isConnected.removeValue(forKey: robotId)
        logger.info("SSE disconnected for robot \(robotId, privacy: .public)")
    }

    func disconnectAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
        isConnected.removeAll()
        logger.info("SSE disconnected for all robots")
    }

    // MARK: - Private Streaming

    private func streamWithReconnect(
        robotId: UUID,
        api: ValetudoAPI,
        onAttributesUpdate: @escaping @Sendable ([RobotAttribute]) -> Void,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) async {
        let decoder = JSONDecoder()

        while !Task.isCancelled {
            do {
                let bytes = try await api.streamStateLines()

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

                // Wait 30 seconds before reconnecting
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch is CancellationError {
                    break
                } catch {
                    break
                }
            }
        }

        // Cleanup on exit
        isConnected[robotId] = false
        logger.info("SSE stream ended for robot \(robotId, privacy: .public)")
    }
}
