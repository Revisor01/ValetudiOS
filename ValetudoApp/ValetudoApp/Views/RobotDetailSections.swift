import SwiftUI
import os

private let detailSectionsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "RobotDetailSections")

// MARK: - Pulse Animation for Live Indicator
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Control Button
struct ControlButton<MenuContent: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () async -> Void
    let menuContent: (() -> MenuContent)?

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void) where MenuContent == EmptyView {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = nil
    }

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void, @ViewBuilder menu: @escaping () -> MenuContent) {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = menu
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                // Badge inside button at top right corner
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }
            }
        }
        .if(menuContent != nil) { view in
            view.contextMenu {
                if let menuContent = menuContent {
                    menuContent()
                }
            }
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Device Info View (eigenständige Unterseite)
struct DeviceInfoView: View {
    let robot: RobotConfig
    let updateService: UpdateService?
    @Environment(RobotManager.self) var robotManager

    @State private var version: ValetudoVersion?
    @State private var hostInfo: SystemHostInfo?
    @State private var robotProperties: RobotProperties?
    @State private var latestRelease: GitHubRelease?
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private var hasUpdate: Bool {
        if case .updateAvailable = updateService?.phase {
            return true
        }
        guard let current = version?.release,
              let latest = latestRelease?.tag_name else { return false }
        return current != latest
    }

    var body: some View {
        List {
            // Update Available Banner
            if hasUpdate, let latest = latestRelease {
                Section {
                    Link(destination: URL(string: latest.html_url)!) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.available"))
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("\(version?.release ?? "") → \(latest.tag_name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Valetudo
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text(version?.release ?? "-")
                        if hasUpdate {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        } else if latestRelease != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                if let version = version {
                    HStack {
                        Text("Commit")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(version.commit.prefix(8)))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                if let latest = latestRelease {
                    Link(destination: URL(string: latest.html_url)!) {
                        HStack {
                            Text(String(localized: "update.latest"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(latest.tag_name)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Valetudo", systemImage: "app.badge")
            }

            // System
            if let info = hostInfo {
                Section {
                    LabeledContent(String(localized: "device_info.hostname"), value: info.hostname)
                    HStack {
                        Text("Architecture")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(info.arch)
                    }
                    if let firmware = robotProperties?.firmwareVersion {
                        LabeledContent("Firmware", value: firmware)
                    }
                    LabeledContent(String(localized: "device_info.uptime"), value: formatUptime(info.uptime))
                    if let load = info.load {
                        HStack {
                            Text(String(localized: "device_info.cpu"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f / %.2f / %.2f", load._1, load._5, load._15))
                                .font(.caption)
                        }
                    }
                    HStack {
                        Text(String(localized: "info.memory"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatBytes(info.mem.total - info.mem.free)) / \(formatBytes(info.mem.total))")
                            .font(.caption)
                    }
                } header: {
                    Label(String(localized: "info.system"), systemImage: "cpu")
                }
            }
        }
        .navigationTitle(String(localized: "device_info.title"))
        .task {
            await loadInfo()
        }
        .refreshable {
            await loadInfo()
        }
        .overlay {
            if isLoading && version == nil {
                ProgressView()
            }
        }
    }

    private func loadInfo() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let v = api.getValetudoVersion()
            async let h = api.getSystemHostInfo()
            async let p = api.getRobotProperties()
            version = try await v
            hostInfo = try await h
            robotProperties = try? await p
        } catch {
            detailSectionsLogger.error("Failed to load device info: \(error, privacy: .public)")
        }

        await checkForUpdate()
    }

    private func checkForUpdate() async {
        guard let url = URL(string: Constants.githubApiLatestReleaseUrl) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            latestRelease = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            detailSectionsLogger.error("Failed to check for updates: \(error, privacy: .public)")
        }
    }

    private func formatUptime(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Dock Action Button
struct DockActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 60, maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
