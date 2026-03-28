import SwiftUI

// MARK: - Map Rename Sheet
struct MapRenameSheet: View {
    let segmentName: String
    @Binding var newName: String
    let onRename: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "rooms.new_name"), text: $newName)
                        .focused($isNameFocused)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "rooms.rename_message \(segmentName)"))
                }
            }
            .navigationTitle(String(localized: "rooms.rename"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        onRename()
                        dismiss()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Save GoTo Preset Sheet
struct SaveGoToPresetSheet: View {
    @Binding var presetName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "map.preset_name"), text: $presetName)
                        .focused($isNameFocused)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "map.save_preset_message"))
                } footer: {
                    Text(String(localized: "map.save_preset_hint"))
                }
            }
            .navigationTitle(String(localized: "map.save_preset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "map.skip")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        onSave()
                        dismiss()
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - GoTo Presets Sheet
struct GoToPresetsSheet: View {
    let robot: RobotConfig
    @ObservedObject var presetStore: GoToPresetStore
    let onSelect: (GoToPreset) -> Void
    let onEdit: ((GoToPreset) -> Void)?
    @Environment(\.dismiss) var dismiss

    init(robot: RobotConfig, presetStore: GoToPresetStore, onSelect: @escaping (GoToPreset) -> Void, onEdit: ((GoToPreset) -> Void)? = nil) {
        self.robot = robot
        self.presetStore = presetStore
        self.onSelect = onSelect
        self.onEdit = onEdit
    }

    private var robotPresets: [GoToPreset] {
        presetStore.presets(for: robot.id)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(robotPresets) { preset in
                    Button {
                        onSelect(preset)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(preset.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if onEdit != nil {
                                Button {
                                    onEdit?(preset)
                                    dismiss()
                                } label: {
                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        presetStore.deletePreset(robotPresets[index])
                    }
                }
            }
            .navigationTitle(String(localized: "map.presets"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
