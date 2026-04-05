import SwiftUI

struct RobotControlSectionView: View {
    @Bindable var viewModel: RobotDetailViewModel

    var body: some View {
        Section {
            // Main control buttons - 3 buttons: Start/Pause (toggle), Stop, Home
            HStack(spacing: 12) {
                // Start/Pause toggle button
                if viewModel.isRunning {
                    ControlButton(
                        title: String(localized: "action.pause"),
                        icon: "pause.fill",
                        color: .orange
                    ) {
                        await viewModel.performAction(.pause)
                    }
                    .buttonStyle(.plain)
                } else {
                    ControlButton(
                        title: viewModel.isPaused ? String(localized: "action.resume") : String(localized: "action.start"),
                        icon: "play.fill",
                        color: .green,
                        badge: "\(viewModel.selectedIterations)×"
                    ) {
                        await viewModel.performAction(.start)
                    } menu: {
                        ForEach(1...3, id: \.self) { count in
                            Button {
                                viewModel.selectedIterations = count
                            } label: {
                                HStack {
                                    Text(count == 1 ? String(localized: "iterations.single") : String(localized: "iterations.multiple \(count)"))
                                    if viewModel.selectedIterations == count {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ControlButton(title: String(localized: "action.stop"), icon: "stop.fill", color: .red) {
                    await viewModel.performAction(.stop)
                }
                .buttonStyle(.plain)

                ControlButton(title: String(localized: "action.home"), icon: "house.fill", color: .blue) {
                    await viewModel.performAction(.home)
                }
                .buttonStyle(.plain)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

            // Intensity Controls (Operation Mode, Fan Speed, Water Usage)
            if !viewModel.fanSpeedPresets.isEmpty || !viewModel.waterUsagePresets.isEmpty || !viewModel.operationModePresets.isEmpty {
                HStack(spacing: 8) {
                    Spacer()

                    // Operation Mode
                    if !viewModel.operationModePresets.isEmpty {
                        Menu {
                            ForEach(viewModel.operationModePresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setOperationMode(preset) }
                                } label: {
                                    HStack {
                                        Image(systemName: iconForOperationMode(preset))
                                        Text(displayNameForOperationMode(preset))
                                        if viewModel.currentOperationMode == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.currentOperationMode.map { iconForOperationMode($0) } ?? "gearshape")
                                    .font(.caption)
                                Text(viewModel.currentOperationMode.map { displayNameForOperationMode($0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                        }
                    }

                    // Fan Speed
                    if !viewModel.fanSpeedPresets.isEmpty {
                        Menu {
                            ForEach(viewModel.fanSpeedPresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setFanSpeed(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if viewModel.currentFanSpeed == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "fan")
                                    .font(.caption)
                                Text(viewModel.currentFanSpeed.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                    }

                    // Water Usage
                    if !viewModel.waterUsagePresets.isEmpty {
                        Menu {
                            ForEach(viewModel.waterUsagePresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setWaterUsage(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if viewModel.currentWaterUsage == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                Text(viewModel.currentWaterUsage.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundStyle(.cyan)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

            // Dock Actions (if available)
            if viewModel.hasAutoEmptyTrigger || viewModel.hasMopDockClean || viewModel.hasMopDockDry {
                HStack(spacing: 12) {
                    if viewModel.hasAutoEmptyTrigger {
                        DockActionButton(title: String(localized: "dock.empty"), icon: "arrow.up.bin", color: .purple) {
                            await viewModel.triggerAutoEmpty()
                        }
                    }
                    if viewModel.hasMopDockClean {
                        DockActionButton(title: String(localized: "dock.clean"), icon: "drop.triangle", color: .blue) {
                            await viewModel.triggerMopDockClean()
                        }
                    }
                    if viewModel.hasMopDockDry {
                        DockActionButton(title: String(localized: "dock.dry"), icon: "wind", color: .cyan) {
                            await viewModel.triggerMopDockDry()
                        }
                    }
                }
                .buttonStyle(.plain)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        }
    }

    private func displayNameForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return String(localized: "mode.vacuum")
        case "mop": return String(localized: "mode.mop")
        case "vacuum_and_mop": return String(localized: "mode.vacuum_and_mop")
        case "vacuum_then_mop": return String(localized: "mode.vacuum_then_mop")
        default: return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func iconForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return "tornado"
        case "mop": return "drop.fill"
        case "vacuum_and_mop", "vacuum_then_mop": return "sparkles"
        default: return "gearshape"
        }
    }
}
