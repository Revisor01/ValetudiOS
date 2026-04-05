import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "WifiSettingsView")

// MARK: - WiFi Settings View
struct WifiSettingsView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var wifiStatus: WifiStatus?
    @State private var networks: [WifiNetwork] = []
    @State private var isLoading = false
    @State private var isScanning = false
    @State private var showConnectSheet = false
    @State private var selectedNetwork: WifiNetwork?
    @State private var password = ""

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Current Connection
            if let status = wifiStatus, let details = status.details {
                Section {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(details.ssid ?? "Unknown")
                                .fontWeight(.medium)
                            if let signal = details.signal {
                                Text("\(signal) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(status.state.capitalized)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let ips = details.ips, !ips.isEmpty {
                        HStack {
                            Text("IP")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ips.joined(separator: ", "))
                                .font(.caption)
                        }
                    }

                    if let freq = details.frequency {
                        HStack {
                            Text(String(localized: "wifi.frequency"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(freq.uppercased())
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(String(localized: "wifi.current"), systemImage: "wifi")
                }
            }

            // Available Networks
            Section {
                if isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(String(localized: "wifi.scanning"))
                            .foregroundStyle(.secondary)
                    }
                } else if networks.isEmpty {
                    Button {
                        Task { await scanNetworks() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "wifi.scan"))
                        }
                    }
                } else {
                    ForEach(networks) { network in
                        Button {
                            selectedNetwork = network
                            showConnectSheet = true
                        } label: {
                            HStack {
                                Image(systemName: network.signalIcon)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text(network.details.ssid)
                                        .foregroundStyle(.primary)
                                    Text("\(network.details.signal) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if wifiStatus?.details?.ssid == network.details.ssid {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }

                    Button {
                        Task { await scanNetworks() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "wifi.rescan"))
                        }
                    }
                }
            } header: {
                Label(String(localized: "wifi.available"), systemImage: "wifi.exclamationmark")
            }
        }
        .navigationTitle(String(localized: "settings.wifi"))
        .task {
            await loadStatus()
        }
        .refreshable {
            await loadStatus()
            await scanNetworks()
        }
        .sheet(isPresented: $showConnectSheet) {
            if let network = selectedNetwork {
                NavigationStack {
                    Form {
                        Section {
                            Text(network.details.ssid)
                                .fontWeight(.medium)
                        } header: {
                            Text(String(localized: "wifi.network"))
                        }

                        Section {
                            SecureField(String(localized: "wifi.password"), text: $password)
                        }

                        Section {
                            Button {
                                Task {
                                    await connectToNetwork(network)
                                    showConnectSheet = false
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if isLoading {
                                        ProgressView()
                                    } else {
                                        Text(String(localized: "wifi.connect"))
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(password.isEmpty || isLoading)
                        }
                    }
                    .navigationTitle(String(localized: "wifi.connect_to"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "settings.cancel")) {
                                showConnectSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func loadStatus() async {
        guard let api = api else { return }
        do {
            wifiStatus = try await api.getWifiStatus()
        } catch {
            logger.error("Failed to load WiFi status: \(error, privacy: .public)")
        }
    }

    private func scanNetworks() async {
        guard let api = api else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            networks = try await api.scanWifi()
            // Sort by signal strength
            networks.sort { $0.details.signal > $1.details.signal }
        } catch {
            logger.error("Failed to scan WiFi: \(error, privacy: .public)")
        }
    }

    private func connectToNetwork(_ network: WifiNetwork) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setWifiConfig(ssid: network.details.ssid, password: password)
            password = ""
            await loadStatus()
        } catch {
            logger.error("Failed to connect to WiFi: \(error, privacy: .public)")
        }
    }
}
