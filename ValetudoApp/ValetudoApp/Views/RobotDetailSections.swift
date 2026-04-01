import SwiftUI

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

// MARK: - Device Info Section
struct DeviceInfoSection: View {
    @ObservedObject var viewModel: RobotDetailViewModel
    @State private var isExpanded = false

    var body: some View {
        let hasAnyData = viewModel.robotProperties != nil
            || viewModel.valetudoVersion != nil
            || viewModel.systemHostInfo != nil

        if hasAnyData {
            Section {
                DisclosureGroup(isExpanded: $isExpanded) {
                    // Hardware
                    if let props = viewModel.robotProperties {
                        if let model = props.model {
                            LabeledContent(String(localized: "device_info.model"), value: model)
                        }
                        if let manufacturer = props.manufacturer {
                            LabeledContent(String(localized: "device_info.manufacturer"), value: manufacturer)
                        }
                        if let serial = props.metaData?.manufacturerSerialNumber {
                            LabeledContent(String(localized: "device_info.serial"), value: serial)
                        }
                    }

                    // Valetudo
                    if let version = viewModel.valetudoVersion {
                        LabeledContent(String(localized: "device_info.valetudo_version"), value: version.release)
                        HStack {
                            Text(String(localized: "device_info.commit"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(version.commit.prefix(8)))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }

                    // System
                    if let info = viewModel.systemHostInfo {
                        LabeledContent(String(localized: "device_info.hostname"), value: info.hostname)
                        LabeledContent(String(localized: "device_info.uptime"), value: formatUptime(info.uptime))

                        // CPU bar
                        if let load = info.load {
                            HStack {
                                Text(String(localized: "device_info.cpu"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let normalizedLoad = min(load._1, 1.0)
                                ProgressView(value: normalizedLoad, total: 1.0)
                                    .tint(normalizedLoad > 0.8 ? .red : .blue)
                                    .frame(width: 100)
                            }
                        }

                        // Memory bar
                        HStack {
                            Text(String(localized: "device_info.memory"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatBytes(info.mem.total - info.mem.free))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("/")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatBytes(info.mem.total))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        let usedPercent = Double(info.mem.total - info.mem.free) / Double(info.mem.total)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(usedPercent > 0.8 ? Color.red : Color.blue)
                                    .frame(width: geometry.size.width * usedPercent)
                            }
                        }
                        .frame(height: 8)
                    }
                } label: {
                    Label(String(localized: "device_info.title"), systemImage: "cpu")
                }
            }
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
