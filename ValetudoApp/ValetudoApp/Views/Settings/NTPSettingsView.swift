import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "NTPSettingsView")

// MARK: - NTP Settings View
struct NTPSettingsView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var config: NTPConfig?
    @State private var status: NTPStatus?
    @State private var isLoading = false
    @State private var isSaving = false

    @State private var enabled = true
    @State private var server = "valetudo.pool.ntp.org"
    @State private var port = "123"

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Form {
            // Current Time Section
            if let status = status, let robotTime = status.robotTime {
                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(String(localized: "ntp.robot_time"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatRobotTime(robotTime))
                                .font(.system(.body, design: .monospaced))
                        }
                        Spacer()
                        Button {
                            Task { await loadStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }

                    if let state = status.state, let lastSync = state.timestamp {
                        HStack {
                            Text(String(localized: "ntp.last_sync"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatSyncTime(lastSync))
                                .font(.caption)
                        }
                    }

                    if let state = status.state, let offset = state.offset {
                        HStack {
                            Text("Offset")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(offset) ms")
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(String(localized: "ntp.status"), systemImage: "clock.badge.checkmark")
                }
            }

            Section {
                Toggle(String(localized: "ntp.enabled"), isOn: $enabled)
            }

            if enabled {
                Section {
                    TextField(String(localized: "ntp.server"), text: $server)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField(String(localized: "ntp.port"), text: $port)
                        .keyboardType(.numberPad)
                } header: {
                    Label(String(localized: "ntp.config"), systemImage: "clock")
                } footer: {
                    Text(String(localized: "ntp.desc"))
                }

                Section {
                    Button {
                        Task { await saveConfig() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(String(localized: "settings.save"))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || server.isEmpty)
                }
            }
        }
        .navigationTitle("NTP")
        .task {
            await loadConfig()
            await loadStatus()
        }
        .refreshable {
            await loadStatus()
        }
        .overlay {
            if isLoading && config == nil {
                ProgressView()
            }
        }
    }

    private func loadConfig() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            config = try await api.getNTPConfig()
            if let config = config {
                enabled = config.enabled
                server = config.server
                port = String(config.port)
            }
        } catch {
            logger.error("Failed to load NTP config: \(error, privacy: .public)")
        }
    }

    private func loadStatus() async {
        guard let api = api else {
            logger.error("NTP: No API available")
            return
        }
        logger.debug("Loading NTP status...")
        do {
            status = try await api.getNTPStatus()
            logger.debug("NTP status loaded successfully")
        } catch {
            logger.error("Failed to load NTP status: \(error, privacy: .public)")
        }
    }

    private func saveConfig() async {
        guard let api = api, var config = config else { return }
        isSaving = true
        defer { isSaving = false }

        config.enabled = enabled
        config.server = server
        config.port = Int(port) ?? 123

        do {
            try await api.setNTPConfig(config)
            self.config = config
        } catch {
            logger.error("Failed to save NTP config: \(error, privacy: .public)")
        }
    }

    private func formatRobotTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .medium
            return displayFormatter.string(from: date)
        }
        return isoString
    }

    private func formatSyncTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = RelativeDateTimeFormatter()
            displayFormatter.unitsStyle = .abbreviated
            return displayFormatter.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}
