import SwiftUI

struct RobotStatusHeaderView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(viewModel.status?.isOnline == true ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Status text
            if let statusValue = viewModel.status?.statusValue {
                Text(localizedStatus(statusValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor(statusValue))
            } else {
                Text(String(localized: "robot.offline"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }

            // Model name (after status)
            if let model = viewModel.status?.info?.modelName {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Consumable warning
            if viewModel.hasConsumableWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // HTTP connection warning (SEC-01)
            if !viewModel.robot.useSSL {
                Image(systemName: "lock.open.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(String(localized: "security.http_connection"))
            }

            // Locate button (compact, before battery)
            if viewModel.status?.isOnline == true {
                Button {
                    Task { await viewModel.locate() }
                } label: {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Battery pill (rightmost)
            if let battery = viewModel.status?.batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(level: battery, charging: viewModel.status?.batteryStatus == "charging"))
                        .font(.caption)
                    Text("\(battery)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(batteryColor(level: battery))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(batteryColor(level: battery).opacity(0.12))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "idle": return String(localized: "status.idle")
        case "cleaning": return String(localized: "status.cleaning")
        case "paused": return String(localized: "status.paused")
        case "returning": return String(localized: "status.returning")
        case "docked": return String(localized: "status.docked")
        case "error": return String(localized: "status.error")
        default: return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "cleaning": return .blue
        case "paused": return .orange
        case "returning": return .purple
        case "error": return .red
        default: return .green
        }
    }

    private func batteryIcon(level: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}
