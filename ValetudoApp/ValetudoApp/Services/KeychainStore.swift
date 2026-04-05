import Foundation
import OSLog
import Security

struct KeychainStore {
    private static let service = "com.valetudio.robot.password"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "KeychainStore")

    static func password(for robotId: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(password: String, for robotId: UUID) -> Bool {
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete (save) failed: \(deleteStatus, privacy: .public)")
        }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecValueData: Data(password.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func delete(for robotId: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete (delete) failed: \(deleteStatus, privacy: .public)")
        }
    }

    // MARK: - Robot Config Storage (SEC-03)
    private static let configService = "com.valetudio.robot.config"

    static func robotConfig(for robotId: UUID) -> RobotConfig? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: configService,
            kSecAttrAccount: robotId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                logger.error("SecItemCopyMatching (robotConfig) failed: \(status, privacy: .public)")
            }
            return nil
        }
        do {
            return try JSONDecoder().decode(RobotConfig.self, from: data)
        } catch {
            logger.error("Failed to decode robot config: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    static func saveRobotConfig(_ config: RobotConfig, for robotId: UUID) -> Bool {
        // Delete-then-add pattern (identisch zum bestehenden Password-Pattern)
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: configService,
            kSecAttrAccount: robotId.uuidString
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete (saveRobotConfig) failed: \(deleteStatus, privacy: .public)")
        }

        guard let data = try? JSONEncoder().encode(config) else {
            logger.error("Failed to encode robot config for \(robotId.uuidString, privacy: .public)")
            return false
        }
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: configService,
            kSecAttrAccount: robotId.uuidString,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("SecItemAdd (saveRobotConfig) failed: \(addStatus, privacy: .public)")
        }
        return addStatus == errSecSuccess
    }

    static func deleteRobotConfig(for robotId: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: configService,
            kSecAttrAccount: robotId.uuidString
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete (deleteRobotConfig) failed: \(deleteStatus, privacy: .public)")
        }
    }
}
