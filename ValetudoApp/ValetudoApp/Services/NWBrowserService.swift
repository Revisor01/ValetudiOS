import Foundation
import Network
import os

@MainActor
final class NWBrowserService: ObservableObject {
    @Published private(set) var discovered: [DiscoveredRobot] = []
    @Published private(set) var isBrowsing = false

    private var browser: NWBrowser?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "mDNS")

    func startBrowsing() {
        guard !isBrowsing else { return }
        logger.info("Starting mDNS browsing for _valetudo._tcp")

        let params = NWParameters()
        params.includePeerToPeer = false

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_valetudo._tcp", domain: "local."), using: params)

        browser.browseResultsChangedHandler = { results, _ in
            // Delivered on main queue (browser started with queue: .main)
            MainActor.assumeIsolated {
                self.handleResults(results)
            }
        }

        browser.stateUpdateHandler = { state in
            // Delivered on main queue (browser started with queue: .main)
            MainActor.assumeIsolated {
                switch state {
                case .ready:
                    self.isBrowsing = true
                    self.logger.info("mDNS browser ready")
                case .failed(let error):
                    self.isBrowsing = false
                    self.logger.error("mDNS browser failed: \(error.localizedDescription, privacy: .public)")
                case .cancelled:
                    self.isBrowsing = false
                    self.logger.info("mDNS browser cancelled")
                case .waiting(let error):
                    self.logger.warning("mDNS browser waiting: \(error.localizedDescription, privacy: .public)")
                default:
                    break
                }
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    private func txtRecordValue(_ record: NWTXTRecord, key: String) -> String? {
        guard let entry = record.getEntry(for: key) else { return nil }
        if case let .string(value) = entry {
            return value
        }
        return nil
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        logger.info("mDNS browser stopped")
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var robots: [DiscoveredRobot] = []

        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }

            var friendlyName: String? = nil
            var model: String? = nil

            if case let .bonjour(txtRecord) = result.metadata {
                friendlyName = self.txtRecordValue(txtRecord, key: "friendlyName")
                model = self.txtRecordValue(txtRecord, key: "model")
            }

            // Use <name>.local as host (simpler than NWConnection resolution per D-10)
            let host = "\(name).local"

            let robot = DiscoveredRobot(
                host: host,
                name: friendlyName,
                model: model,
                discoveredVia: .mdns
            )
            robots.append(robot)
        }

        discovered = robots
        logger.info("mDNS discovered \(robots.count, privacy: .public) robot(s)")
    }
}
