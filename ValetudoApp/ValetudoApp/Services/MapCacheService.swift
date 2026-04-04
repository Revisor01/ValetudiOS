import Foundation
import os

final class MapCacheService {
    static let shared = MapCacheService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MapCacheService")
    private var lastDataHash: [UUID: Int] = [:]
    private init() {}

    // MARK: - Cache Directory

    private func cacheDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent("MapCache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    private func cacheURL(for robotId: UUID) throws -> URL {
        try cacheDirectory().appendingPathComponent("\(robotId.uuidString).json")
    }

    // MARK: - Public API

    func saveIfChanged(_ map: RobotMap, for robotId: UUID) async {
        do {
            let url = try cacheURL(for: robotId)
            let data = try JSONEncoder().encode(map)
            let newHash = data.hashValue

            if lastDataHash[robotId] == newHash {
                return  // Keine Aenderung — Disk-Write ueberspringen
            }
            lastDataHash[robotId] = newHash
            try data.write(to: url, options: .atomic)
            logger.debug("MapCache saved (changed) for \(robotId.uuidString, privacy: .public)")
        } catch {
            logger.error("MapCache save failed for \(robotId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func save(_ map: RobotMap, for robotId: UUID) async {
        do {
            let url = try cacheURL(for: robotId)
            let data = try JSONEncoder().encode(map)
            try data.write(to: url, options: .atomic)
            logger.debug("MapCache saved for \(robotId.uuidString, privacy: .public)")
        } catch {
            logger.error("MapCache save failed for \(robotId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func load(for robotId: UUID) async -> RobotMap? {
        do {
            let url = try cacheURL(for: robotId)
            let data = try Data(contentsOf: url)
            let map = try JSONDecoder().decode(RobotMap.self, from: data)
            logger.debug("MapCache loaded for \(robotId.uuidString, privacy: .public)")
            return map
        } catch {
            logger.debug("MapCache load: no cache for \(robotId.uuidString, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func deleteCache(for robotId: UUID) {
        do {
            let url = try cacheURL(for: robotId)
            try FileManager.default.removeItem(at: url)
            logger.info("MapCache deleted for \(robotId.uuidString, privacy: .public)")
        } catch {
            logger.debug("MapCache delete: nichts zu loeschen fuer \(robotId.uuidString, privacy: .public)")
        }
    }
}
