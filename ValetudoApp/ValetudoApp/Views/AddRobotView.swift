import SwiftUI

struct AddRobotView: View {
    @Environment(RobotManager.self) var robotManager
    @Environment(\.dismiss) var dismiss
    @State private var scanner = NetworkScanner()

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var useSSL = false
    @State private var ignoreCertificateErrors = false
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                // Network Scan Section
                Section {
                    Button {
                        showScanner = true
                        scanner.startScan()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.blue)
                            Text(String(localized: "scan.title"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(String(localized: "scan.description"))
                }

                // Manual Entry Section
                Section(String(localized: "scan.manual_entry")) {
                    TextField(String(localized: "settings.name"), text: $name)
                        .textContentType(.name)

                    TextField(String(localized: "settings.host"), text: $host)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section(String(localized: "settings.auth.optional")) {
                    TextField(String(localized: "settings.username"), text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)

                    SecureField(String(localized: "settings.password"), text: $password)
                        .textContentType(.password)
                }

                Section {
                    Toggle(String(localized: "settings.use_ssl"), isOn: $useSSL)

                    if useSSL {
                        Toggle(String(localized: "settings.ignore_certificate_errors"), isOn: $ignoreCertificateErrors)
                    }
                } header: {
                    Text(String(localized: "settings.connection"))
                }

                if useSSL && ignoreCertificateErrors {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(String(localized: "settings.ignore_certificate_errors.warning"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text(String(localized: "settings.test_connection"))
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let result = testResult {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result ? .green : .red)
                            }
                        }
                    }
                    .disabled(host.isEmpty || isTesting)
                }
            }
            .navigationTitle(String(localized: "robots.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        saveRobot()
                    }
                    .disabled(name.isEmpty || host.isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                NetworkScannerView(scanner: scanner) { robot in
                    host = robot.host
                    name = robot.displayName
                    showScanner = false
                    testConnection()
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let config = RobotConfig(
            name: name,
            host: host,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            useSSL: useSSL,
            ignoreCertificateErrors: ignoreCertificateErrors
        )

        Task {
            let api = ValetudoAPI(config: config)
            let result = await api.checkConnection()
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func saveRobot() {
        let config = RobotConfig(
            name: name,
            host: host,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            useSSL: useSSL,
            ignoreCertificateErrors: ignoreCertificateErrors
        )
        robotManager.addRobot(config)
        dismiss()
    }
}

// MARK: - Network Scanner View
struct NetworkScannerView: View {
    var scanner: NetworkScanner
    @Environment(\.dismiss) var dismiss
    let onSelect: (DiscoveredRobot) -> Void

    // mDNS results first, then IP scan; alphabetical within each group
    private var sortedRobots: [DiscoveredRobot] {
        scanner.discoveredRobots.sorted { lhs, rhs in
            if lhs.discoveredVia == rhs.discoveredVia {
                return lhs.displayName < rhs.displayName
            }
            return lhs.discoveredVia == .mdns
        }
    }

    @ViewBuilder
    private func discoveryBadge(for robot: DiscoveredRobot) -> some View {
        switch robot.discoveredVia {
        case .mdns:
            Label("Bonjour", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .ipScan:
            Label("IP Scan", systemImage: "network")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Progress Section
                if scanner.isScanning {
                    Section {
                        VStack(spacing: 12) {
                            ProgressView(value: scanner.progress) {
                                HStack {
                                    Text(String(localized: "scan.scanning"))
                                    Spacer()
                                    Text("\(Int(scanner.progress * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(String(localized: "scan.scanning_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Found Robots Section
                if !scanner.discoveredRobots.isEmpty {
                    Section(String(localized: "scan.found_robots")) {
                        ForEach(sortedRobots) { robot in
                            Button {
                                onSelect(robot)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(robot.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        if let model = robot.model, robot.discoveredVia == .mdns {
                                            Text(model)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Text(robot.host)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        discoveryBadge(for: robot)
                                    }
                                }
                            }
                        }
                    }
                }

                // No Results
                if !scanner.isScanning && scanner.discoveredRobots.isEmpty && scanner.progress > 0 {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "scan.no_robots"))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "scan.no_robots_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }

                // Rescan Button
                if !scanner.isScanning && scanner.progress > 0 {
                    Section {
                        Button {
                            scanner.startScan()
                        } label: {
                            HStack {
                                Spacer()
                                Label(String(localized: "scan.rescan"), systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "scan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        scanner.stopScan()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddRobotView()
        .environment(RobotManager())
}
