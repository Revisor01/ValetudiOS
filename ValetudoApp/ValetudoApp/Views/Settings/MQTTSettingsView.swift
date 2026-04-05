import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MQTTSettingsView")

// MARK: - MQTT Settings View
struct MQTTSettingsView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var config: MQTTConfig?
    @State private var isLoading = false
    @State private var isSaving = false

    // Editable fields
    @State private var enabled = false
    @State private var host = ""
    @State private var port = "1883"
    @State private var username = ""
    @State private var password = ""
    @State private var identifier = ""
    @State private var useAuth = false
    @State private var homeAssistant = true
    @State private var homie = false
    @State private var provideMapData = true
    @State private var showPassword = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "mqtt.enabled"), isOn: $enabled)
            }

            if enabled {
                Section {
                    TextField(String(localized: "mqtt.host"), text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField(String(localized: "mqtt.port"), text: $port)
                        .keyboardType(.numberPad)
                } header: {
                    Label(String(localized: "mqtt.connection"), systemImage: "network")
                }

                Section {
                    Toggle(String(localized: "mqtt.use_auth"), isOn: $useAuth)
                    if useAuth {
                        TextField(String(localized: "mqtt.username"), text: $username)
                            .autocapitalization(.none)
                        HStack {
                            if showPassword {
                                TextField(String(localized: "mqtt.password"), text: $password)
                                    .autocapitalization(.none)
                            } else {
                                SecureField(String(localized: "mqtt.password"), text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label(String(localized: "mqtt.authentication"), systemImage: "lock")
                } footer: {
                    if useAuth {
                        Text(String(localized: "mqtt.credentials_note"))
                    }
                }

                Section {
                    TextField(String(localized: "mqtt.identifier"), text: $identifier)
                        .autocapitalization(.none)
                } header: {
                    Label(String(localized: "mqtt.identity"), systemImage: "tag")
                } footer: {
                    Text(String(localized: "mqtt.identifier_desc"))
                }

                Section {
                    Toggle("Home Assistant", isOn: $homeAssistant)
                    Toggle("Homie", isOn: $homie)
                    Toggle(String(localized: "mqtt.provide_map"), isOn: $provideMapData)
                } header: {
                    Label(String(localized: "mqtt.interfaces"), systemImage: "square.stack.3d.up")
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
                    .disabled(isSaving || host.isEmpty)
                }
            }
        }
        .navigationTitle("MQTT")
        .task {
            await loadConfig()
        }
        .overlay {
            if isLoading && config == nil {
                ProgressView()
            }
        }
    }

    private func loadConfig() async {
        guard let api = api else {
            logger.error("MQTT: No API available")
            return
        }
        isLoading = true
        defer { isLoading = false }

        logger.debug("Loading MQTT config...")
        do {
            config = try await api.getMQTTConfig()
            logger.debug("MQTT config loaded: enabled=\(config?.enabled ?? false, privacy: .public)")
            if let config = config {
                enabled = config.enabled
                host = config.connection.host
                port = String(config.connection.port)
                // Don't load redacted credentials - leave empty for user to enter new ones
                let loadedUsername = config.connection.authentication.credentials.username
                let loadedPassword = config.connection.authentication.credentials.password
                logger.debug("MQTT username from API: '\(loadedUsername == "<redacted>" ? "<redacted>" : "set", privacy: .public)'")
                username = loadedUsername == "<redacted>" ? "" : loadedUsername
                password = loadedPassword == "<redacted>" ? "" : loadedPassword
                useAuth = config.connection.authentication.credentials.enabled
                identifier = config.identity.identifier
                homeAssistant = config.interfaces.homeassistant.enabled
                homie = config.interfaces.homie.enabled
                provideMapData = config.customizations.provideMapData
            }
        } catch {
            logger.error("Failed to load MQTT config: \(error, privacy: .public)")
        }
    }

    private func saveConfig() async {
        guard let api = api, var config = config else { return }
        isSaving = true
        defer { isSaving = false }

        config.enabled = enabled
        config.connection.host = host
        config.connection.port = Int(port) ?? 1883
        config.connection.authentication.credentials.enabled = useAuth
        config.connection.authentication.credentials.username = username
        config.connection.authentication.credentials.password = password
        config.identity.identifier = identifier
        config.interfaces.homeassistant.enabled = homeAssistant
        config.interfaces.homie.enabled = homie
        config.customizations.provideMapData = provideMapData

        do {
            try await api.setMQTTConfig(config)
            self.config = config
        } catch {
            logger.error("Failed to save MQTT config: \(error, privacy: .public)")
        }
    }
}
