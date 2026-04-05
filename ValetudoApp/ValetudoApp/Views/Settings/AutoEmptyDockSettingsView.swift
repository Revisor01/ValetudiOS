import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "AutoEmptyDockSettingsView")

// MARK: - Auto Empty Dock Settings View
struct AutoEmptyDockSettingsView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var presets: [String] = []
    @State private var selectedPreset: String?
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if presets.isEmpty && !isLoading {
                Text(String(localized: "settings.no_presets"))
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            Task { await selectPreset(preset) }
                        } label: {
                            HStack {
                                Text(preset.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(String(localized: "settings.auto_empty_interval_desc"))
                }
            }
        }
        .navigationTitle(String(localized: "settings.auto_empty_interval"))
        .task {
            await loadPresets()
        }
        .overlay {
            if isLoading && presets.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadPresets() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            presets = try await api.getAutoEmptyDockIntervalPresets()
        } catch {
            logger.error("Failed to load auto empty dock presets: \(error, privacy: .public)")
        }
    }

    private func selectPreset(_ preset: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setAutoEmptyDockInterval(preset: preset)
            selectedPreset = preset
        } catch {
            logger.error("Failed to set auto empty dock preset: \(error, privacy: .public)")
        }
    }
}
