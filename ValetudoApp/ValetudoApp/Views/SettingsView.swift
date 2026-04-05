import SwiftUI

struct SettingsView: View {
    @Environment(RobotManager.self) var robotManager
    var notificationService = NotificationService.shared
    @State private var robotToEdit: RobotConfig?
    @State private var showAddRobot = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Robots Section
                Section {
                    ForEach(robotManager.robots) { robot in
                        Button {
                            robotToEdit = robot
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(robot.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(robot.host)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Online status
                                Circle()
                                    .fill(robotManager.robotStates[robot.id]?.isOnline == true ? .green : .red)
                                    .frame(width: 10, height: 10)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: deleteRobots)

                    Button {
                        showAddRobot = true
                    } label: {
                        Label(String(localized: "settings.add_robot"), systemImage: "plus")
                    }
                } header: {
                    Text("settings.robots")
                } footer: {
                    Text("settings.robots_footer")
                }

                // MARK: - Notifications Section
                Section {
                    Toggle(isOn: Binding(
                        get: { notificationService.isAuthorized },
                        set: { _ in
                            Task {
                                await notificationService.requestAuthorization()
                            }
                        }
                    )) {
                        Label(String(localized: "settings.notifications"), systemImage: "bell.fill")
                    }

                    if notificationService.isAuthorized {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label(String(localized: "settings.notification_settings"), systemImage: "bell.badge")
                        }
                    }
                } header: {
                    Text("settings.notifications_section")
                } footer: {
                    if !notificationService.isAuthorized {
                        Text("settings.notifications_disabled_footer")
                    }
                }

                // MARK: - Support Section
                Section {
                    NavigationLink {
                        SupportView()
                    } label: {
                        Label(String(localized: "support.title"), systemImage: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: Constants.valetudoWebsiteUrl) {
                        Link(destination: url) {
                            HStack {
                                Label(String(localized: "settings.valetudo_website"), systemImage: "globe")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let url = URL(string: Constants.valetudoGithubUrl) {
                        Link(destination: url) {
                            HStack {
                                Label("Valetudo GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let url = URL(string: Constants.appGithubUrl) {
                        Link(destination: url) {
                            HStack {
                                Label("ValetudiOS GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("settings.about")
                } footer: {
                    VStack(spacing: 4) {
                        Text("settings.license_footer")
                        HStack(spacing: 4) {
                            Text("Made with")
                            Image(systemName: "dove.fill")
                                .foregroundStyle(.secondary)
                            Text("in Hennstedt")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        Text("Friede. Schalom. Salam.")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .sheet(isPresented: $showAddRobot) {
                AddRobotView()
            }
            .sheet(item: $robotToEdit) { robot in
                EditRobotView(robot: robot)
            }
        }
    }

    private func deleteRobots(at offsets: IndexSet) {
        for index in offsets {
            robotManager.removeRobot(robotManager.robots[index].id)
        }
    }
}

// MARK: - Edit Robot View
struct EditRobotView: View {
    @Environment(RobotManager.self) var robotManager
    @Environment(\.dismiss) var dismiss

    let robot: RobotConfig

    @State private var name: String
    @State private var host: String
    @State private var useAuthentication: Bool
    @State private var username: String
    @State private var password: String
    @State private var useSSL: Bool
    @State private var ignoreCertificateErrors: Bool
    @State private var isTesting = false
    @State private var testResult: ConnectionTestResult?
    @State private var showDeleteConfirmation = false

    init(robot: RobotConfig) {
        self.robot = robot
        _name = State(initialValue: robot.name)
        _host = State(initialValue: robot.host)
        _useAuthentication = State(initialValue: !(robot.username?.isEmpty ?? true))
        _username = State(initialValue: robot.username ?? "")
        _password = State(initialValue: KeychainStore.password(for: robot.id) ?? "")
        _useSSL = State(initialValue: robot.useSSL)
        _ignoreCertificateErrors = State(initialValue: robot.ignoreCertificateErrors)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "robot.name"), text: $name)
                    TextField(String(localized: "robot.host"), text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section {
                    Toggle(String(localized: "robot.use_auth"), isOn: $useAuthentication)

                    if useAuthentication {
                        TextField(String(localized: "robot.username"), text: $username)
                            .autocapitalization(.none)
                        SecureField(String(localized: "robot.password"), text: $password)
                    }
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
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text(String(localized: "robot.test_connection"))
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let result = testResult {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                            }
                        }
                    }
                    .disabled(host.isEmpty || isTesting)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "settings.delete_robot"))
                            Spacer()
                        }
                    }
                    .confirmationDialog(String(localized: "settings.delete_robot"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                        Button(String(localized: "settings.delete_robot"), role: .destructive) {
                            robotManager.removeRobot(robot.id)
                            dismiss()
                        }
                    } message: {
                        Text(String(localized: "settings.delete_robot_confirm"))
                    }
                }
            }
            .navigationTitle(String(localized: "settings.edit_robot"))
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
        }
    }

    private func saveRobot() {
        let updatedRobot = RobotConfig(
            id: robot.id,
            name: name,
            host: host,
            username: useAuthentication ? username : nil,
            password: useAuthentication ? password : nil,
            useSSL: useSSL,
            ignoreCertificateErrors: useSSL ? ignoreCertificateErrors : false
        )
        robotManager.updateRobot(updatedRobot)
        dismiss()
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        let testConfig = RobotConfig(
            name: name,
            host: host,
            username: useAuthentication ? username : nil,
            password: useAuthentication ? password : nil,
            useSSL: useSSL,
            ignoreCertificateErrors: useSSL ? ignoreCertificateErrors : false
        )

        let api = ValetudoAPI(config: testConfig)
        let success = await api.checkConnection()
        testResult = ConnectionTestResult(success: success)
    }
}

struct ConnectionTestResult {
    let success: Bool
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @AppStorage("notify_cleaning_complete") private var notifyCleaningComplete = true
    @AppStorage("notify_robot_error") private var notifyRobotError = true
    @AppStorage("notify_robot_stuck") private var notifyRobotStuck = true
    @AppStorage("notify_consumable_low") private var notifyConsumableLow = true
    @AppStorage("notify_robot_offline") private var notifyRobotOffline = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notifyCleaningComplete) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(String(localized: "notification.cleaning_complete.title"))
                            Text(String(localized: "settings.notify_cleaning_complete_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Toggle(isOn: $notifyRobotError) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(String(localized: "settings.notify_error"))
                            Text(String(localized: "settings.notify_error_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Toggle(isOn: $notifyRobotStuck) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(String(localized: "settings.notify_stuck"))
                            Text(String(localized: "settings.notify_stuck_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Toggle(isOn: $notifyConsumableLow) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(String(localized: "settings.notify_consumable"))
                            Text(String(localized: "settings.notify_consumable_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(.purple)
                    }
                }

                Toggle(isOn: $notifyRobotOffline) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(String(localized: "settings.notify_offline"))
                            Text(String(localized: "settings.notify_offline_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.gray)
                    }
                }
            } footer: {
                Text("settings.notification_settings_footer")
            }
        }
        .navigationTitle(String(localized: "settings.notification_settings"))
    }
}

#Preview {
    SettingsView()
        .environment(RobotManager())
}
