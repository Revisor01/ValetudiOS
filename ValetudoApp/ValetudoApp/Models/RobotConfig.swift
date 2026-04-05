import Foundation

struct RobotConfig: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var username: String?
    var password: String?
    var useSSL: Bool
    var ignoreCertificateErrors: Bool

    var baseURL: URL? {
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(host)")
    }

    /// Whether this robot is on a local network (private IP or .local mDNS)
    var isLocalNetwork: Bool {
        let h = host.lowercased()
        // mDNS / .local hostnames
        if h.hasSuffix(".local") { return true }
        // Private IPv4 ranges
        if h.starts(with: "192.168.") || h.starts(with: "10.") { return true }
        if h.starts(with: "172.") {
            let parts = h.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) { return true }
        }
        // Link-local
        if h.starts(with: "169.254.") { return true }
        return false
    }

    init(id: UUID = UUID(), name: String, host: String, username: String? = nil, password: String? = nil, useSSL: Bool = false, ignoreCertificateErrors: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.password = password
        self.useSSL = useSSL
        self.ignoreCertificateErrors = ignoreCertificateErrors
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, host, username, useSSL, ignoreCertificateErrors
    }

    // Custom decoder for backward compatibility with existing saved robots
    // Note: password is intentionally excluded from CodingKeys — stored in Keychain, never in UserDefaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        password = nil // Passwords are stored in Keychain, not in UserDefaults JSON
        useSSL = try container.decodeIfPresent(Bool.self, forKey: .useSSL) ?? false
        ignoreCertificateErrors = try container.decodeIfPresent(Bool.self, forKey: .ignoreCertificateErrors) ?? false
    }
}
