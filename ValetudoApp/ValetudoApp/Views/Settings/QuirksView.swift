import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "QuirksView")

// MARK: - Quirks View
struct QuirksView: View {
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var quirks: [Quirk] = []
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if quirks.isEmpty && !isLoading {
                Text(String(localized: "settings.no_quirks"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(quirks) { quirk in
                    Section {
                        Picker(selection: Binding(
                            get: { quirk.value },
                            set: { newValue in
                                Task { await setQuirk(id: quirk.id, value: newValue) }
                            }
                        )) {
                            ForEach(quirk.options, id: \.self) { option in
                                Text(option.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .tag(option)
                            }
                        } label: {
                            Text(quirk.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .pickerStyle(.menu)
                    } footer: {
                        Text(quirk.description)
                            .lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.quirks"))
        .task {
            await loadQuirks()
        }
        .refreshable {
            await loadQuirks()
        }
        .overlay {
            if isLoading && quirks.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadQuirks() async {
        // In DEBUG mode, always show debug quirks
        if DebugConfig.showAllCapabilities {
            quirks = debugQuirks
            return
        }

        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            quirks = try await api.getQuirks()
        } catch {
            logger.error("Failed to load quirks: \(error, privacy: .public)")
        }
    }

    private var debugQuirks: [Quirk] {
        [
            Quirk(id: "carpetModeSensitivity", options: ["low", "medium", "high"], title: "Carpet Mode Sensitivity", description: "Adjusts carpet detection sensitivity based on carpet type", value: "medium"),
            Quirk(id: "tightMopPattern", options: ["on", "off"], title: "Tight Mop Pattern", description: "Enabling this makes your robot move in a much tighter pattern when mopping.", value: "off"),
            Quirk(id: "mopDockMopOnlyMode", options: ["on", "off"], title: "Mop Only", description: "Disable the vacuum functionality when the mop pads are attached.", value: "off"),
            Quirk(id: "mopDockMopCleaningFrequency", options: ["every_segment", "every_5_m2", "every_10_m2", "every_15_m2", "every_20_m2", "every_25_m2"], title: "Mop Cleaning Frequency", description: "Controls mop cleaning and re-wetting intervals during cleanup", value: "every_10_m2"),
            Quirk(id: "mopDockUvTreatment", options: ["on", "off"], title: "Wastewater UV Treatment", description: "Disinfect the waste water tank after each successful cleanup using the in-built UV-C light.", value: "on"),
            Quirk(id: "mopDryingTime", options: ["2h", "3h", "4h"], title: "Mop Drying Time", description: "Define how long the mop should be dried after a cleanup", value: "3h"),
            Quirk(id: "mopDockDetergent", options: ["on", "off"], title: "Detergent", description: "Select if the Dock should automatically add detergent to the water", value: "on"),
            Quirk(id: "mopDockWetDrySwitch", options: ["wet", "dry"], title: "Pre-Wet Mops", description: "Allows selection of pre-wetting mops or running dry for spill cleanup", value: "wet"),
            Quirk(id: "edgeExtensionFrequency", options: ["automatic", "each_cleanup", "every_7_days"], title: "Edge Extension: Frequency", description: "Controls when mop and side brush extend for corner coverage", value: "automatic"),
            Quirk(id: "carpetDetectionAutoDeepCleaning", options: ["on", "off"], title: "Deep Carpet Cleaning", description: "When enabled, the robot will automatically slowly clean detected carpets with twice the cleanup passes in alternating directions.", value: "off"),
            Quirk(id: "mopDockWaterUsage", options: ["low", "medium", "high"], title: "Mop Dock Mop Wash Intensity", description: "Higher settings mean more water and longer wash cycles.", value: "medium"),
            Quirk(id: "sideBrushExtend", options: ["on", "off"], title: "Edge Extension: Side Brush", description: "Automatically extend the side brush to further reach into corners or below furniture", value: "on"),
            Quirk(id: "detachMops", options: ["on", "off"], title: "Detach Mops", description: "When enabled, the robot will leave the mop pads in the dock when running a vacuum-only cleanup", value: "on"),
            Quirk(id: "cleanRoute", options: ["quick", "standard", "intensive", "deep"], title: "Clean Route", description: "Trade speed for thoroughness and vice-versa. These settings only apply when mopping.", value: "standard"),
            Quirk(id: "sideBrushOnCarpet", options: ["on", "off"], title: "Side Brush on Carpet", description: "Select if the side brush should spin when cleaning carpets.", value: "on"),
            Quirk(id: "mopDockAutoRepair", options: ["select_to_trigger", "trigger"], title: "Mop Dock Auto Repair", description: "Addresses air in system preventing proper water tank filling. Select trigger to start.", value: "select_to_trigger"),
            Quirk(id: "waterHookupTest", options: ["select_to_trigger", "trigger"], title: "Water Hookup Test", description: "Tests permanent water hookup installation with voice prompts.", value: "select_to_trigger"),
            Quirk(id: "drainInternalWaterTank", options: ["select_to_trigger", "trigger"], title: "Drain Internal Water Tank", description: "Drain the internal water tank of the robot into the dock. May take up to 3 minutes.", value: "select_to_trigger"),
            Quirk(id: "mopDockCleaningProcess", options: ["select_to_trigger", "trigger"], title: "Mop Dock Cleaning Process", description: "Triggers manual base cleaning with user guidance.", value: "select_to_trigger")
        ]
    }

    private func setQuirk(id: String, value: String) async {
        guard let api = api else { return }

        do {
            try await api.setQuirk(id: id, value: value)
            await loadQuirks()
        } catch {
            logger.error("Failed to set quirk: \(error, privacy: .public)")
        }
    }
}
