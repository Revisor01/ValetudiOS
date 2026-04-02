import Foundation
import Network
import os
import Observation

struct DiscoveredRobot: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let name: String?
    let model: String?
    let discoveredVia: DiscoveryMethod

    enum DiscoveryMethod: Hashable {
        case mdns
        case ipScan
    }

    var displayName: String {
        name ?? model ?? host
    }

    // Hashable conformance based on host (not UUID) so duplicate filtering works
    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
    }

    static func == (lhs: DiscoveredRobot, rhs: DiscoveredRobot) -> Bool {
        lhs.host == rhs.host
    }
}

@MainActor
@Observable
class NetworkScanner {
    var discoveredRobots: [DiscoveredRobot] = []
    var isScanning = false
    var progress: Double = 0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "NetworkScanner")
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private let browserService = NWBrowserService()

    func startScan() {
        stopScan()
        discoveredRobots = []
        isScanning = true
        progress = 0

        // Start mDNS immediately
        browserService.startBrowsing()

        scanTask = Task {
            // Wait 3 seconds for mDNS to collect results
            try? await Task.sleep(for: .seconds(3))

            guard !Task.isCancelled else { return }

            // Merge mDNS results before starting IP scan
            mergeMDNSResults()

            // Always run IP scan for full coverage (as fallback and supplement)
            await scanNetwork()

            // Final merge after IP scan
            mergeMDNSResults()

            isScanning = false
            browserService.stopBrowsing()
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        browserService.stopBrowsing()
    }

    // Merges mDNS results into discoveredRobots, preferring mDNS over IP scan for duplicates
    private func mergeMDNSResults() {
        let mdnsRobots = browserService.discovered
        let existingHosts = Set(discoveredRobots.map(\.host))

        // Add new mDNS robots not already in list
        for robot in mdnsRobots where !existingHosts.contains(robot.host) {
            discoveredRobots.insert(robot, at: 0)
        }

        // Replace IP-scan entries if mDNS found same host (mDNS has better metadata)
        for mdnsRobot in mdnsRobots {
            if let idx = discoveredRobots.firstIndex(where: { $0.host == mdnsRobot.host && $0.discoveredVia == .ipScan }) {
                discoveredRobots[idx] = mdnsRobot
            }
        }
    }

    private func scanNetwork() async {
        guard let localIP = getLocalIPAddress() else {
            logger.warning("Could not determine local IP address")
            return
        }

        let subnet = getSubnet(from: localIP)
        logger.debug("Scanning subnet: \(subnet, privacy: .private).x")

        let totalHosts = 254
        var scannedHosts = 0

        await withTaskGroup(of: DiscoveredRobot?.self) { group in
            for i in 1...254 {
                let host = "\(subnet).\(i)"

                group.addTask {
                    await self.checkHost(host)
                }

                if i % 20 == 0 {
                    for await result in group {
                        scannedHosts += 1
                        await MainActor.run {
                            self.progress = Double(scannedHosts) / Double(totalHosts)
                        }
                        if let robot = result {
                            await MainActor.run {
                                // Only add if not already discovered via mDNS
                                if !self.discoveredRobots.contains(where: { $0.host == robot.host }) {
                                    self.discoveredRobots.append(robot)
                                }
                            }
                        }
                    }
                }
            }

            for await result in group {
                scannedHosts += 1
                await MainActor.run {
                    self.progress = Double(scannedHosts) / Double(totalHosts)
                }
                if let robot = result {
                    await MainActor.run {
                        if !self.discoveredRobots.contains(where: { $0.host == robot.host }) {
                            self.discoveredRobots.append(robot)
                        }
                    }
                }
            }
        }

        await MainActor.run {
            self.progress = 1.0
        }
    }

    private func checkHost(_ host: String) async -> DiscoveredRobot? {
        guard let url = URL(string: "http://\(host)/api/v2/robot") else {
            logger.error("checkHost: Invalid URL for host \(host, privacy: .public)")
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            if let robotInfo = try? decoder.decode(RobotInfo.self, from: data) {
                return DiscoveredRobot(
                    host: host,
                    name: nil,
                    model: robotInfo.modelName ?? robotInfo.manufacturer,
                    discoveredVia: .ipScan
                )
            }

            return DiscoveredRobot(host: host, name: nil, model: "Valetudo", discoveredVia: .ipScan)
        } catch {
            return nil
        }
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }

        return address
    }

    private func getSubnet(from ip: String) -> String {
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return "192.168.1" }
        return "\(components[0]).\(components[1]).\(components[2])"
    }
}
