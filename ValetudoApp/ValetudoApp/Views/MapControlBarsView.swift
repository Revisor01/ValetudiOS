import SwiftUI

// MARK: - Map Control Button
struct MapControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () async -> Void

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
                    .minimumScaleFactor(0.6)
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
        .buttonStyle(.plain)
    }
}

// MARK: - Room Edit Button (consistent sizing)
struct RoomEditButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MapContentView Control Bar Extensions
extension MapContentView {

    // MARK: - Bottom Control Bar
    @ViewBuilder
    var selectedRoomsBar: some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.editMode == .roomEdit {
                roomEditBar
            } else if viewModel.editMode == .splitRoom {
                splitRoomBar
            } else if viewModel.showGoToConfirm {
                goToConfirmBar
            } else if viewModel.editMode == .savePreset && viewModel.goToMarkerPosition != nil {
                savePresetConfirmBar
            } else if viewModel.editMode != .none {
                editModeBar
            } else {
                normalControlBar
            }
        }
    }

    @ViewBuilder
    var normalControlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // GoTo preset quick select (tap toggles visibility or opens sheet, longpress shows menu)
                let quickPresets = viewModel.presetStore.presets(for: robot.id)
                MapControlButton(
                    title: String(localized: "map.presets"),
                    icon: quickPresets.isEmpty ? "star" : (viewModel.showPresetsOnMap ? "star.fill" : "star"),
                    color: quickPresets.isEmpty ? .gray : (viewModel.showPresetsOnMap ? .yellow : .gray)
                ) {
                    if quickPresets.isEmpty {
                        // No presets - start save mode
                        viewModel.editMode = .savePreset
                    } else {
                        // Toggle presets visibility on map
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showPresetsOnMap.toggle()
                        }
                    }
                }
                .contextMenu {
                    if !quickPresets.isEmpty {
                        ForEach(quickPresets) { preset in
                            Button {
                                Task { await viewModel.goToPoint(x: preset.x, y: preset.y) }
                            } label: {
                                Label(preset.name, systemImage: "location.fill")
                            }
                        }
                        Divider()
                    }
                    Button {
                        viewModel.editMode = .savePreset
                    } label: {
                        Label(String(localized: "map.add_preset"), systemImage: "plus.circle")
                    }
                    if !quickPresets.isEmpty {
                        Button {
                            viewModel.showPresetsSheet = true
                        } label: {
                            Label(String(localized: "map.manage_presets"), systemImage: "list.bullet")
                        }
                    }
                }

                // Clean button with iterations indicator and long-press menu
                MapControlButton(
                    title: String(localized: "rooms.clean_selected"),
                    icon: viewModel.isCleaning ? "hourglass" : "play.fill",
                    color: .green,
                    badge: "\(viewModel.selectedIterations)×"
                ) {
                    await viewModel.cleanSelectedRooms()
                }
                .opacity(viewModel.selectedSegmentIds.isEmpty ? 0.4 : 1.0)
                .disabled(viewModel.selectedSegmentIds.isEmpty || viewModel.isCleaning)
                .contextMenu {
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

                MapControlButton(
                    title: String(localized: "map.goto"),
                    icon: viewModel.editMode == .goTo ? "location.fill" : "location",
                    color: .blue
                ) {
                    viewModel.editMode = viewModel.editMode == .goTo ? .none : .goTo
                }
                .opacity(viewModel.hasGoTo ? 1.0 : 0.4)
                .disabled(!viewModel.hasGoTo)

            }

            HStack(spacing: 12) {
                if viewModel.hasSegmentRename || viewModel.hasSegmentEdit {
                    MapControlButton(
                        title: String(localized: "rooms.edit"),
                        icon: "square.and.pencil",
                        color: .indigo
                    ) {
                        viewModel.editMode = .roomEdit
                    }
                }

                if viewModel.hasZoneCleaning {
                    MapControlButton(
                        title: String(localized: "map.zone"),
                        icon: "rectangle.dashed",
                        color: .orange
                    ) {
                        viewModel.editMode = .zone
                    }
                }

                if viewModel.hasVirtualRestrictions {
                    MapControlButton(
                        title: String(localized: "map.nogo"),
                        icon: "nosign",
                        color: .red
                    ) {
                        viewModel.editMode = .noGoArea
                    }

                    MapControlButton(
                        title: String(localized: "map.wall"),
                        icon: "line.diagonal",
                        color: .purple
                    ) {
                        viewModel.editMode = .virtualWall
                    }

                    // Delete existing restrictions
                    if viewModel.existingRestrictions != nil {
                        MapControlButton(
                            title: String(localized: "map.delete"),
                            icon: "trash",
                            color: .gray
                        ) {
                            viewModel.editMode = .deleteRestriction
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var editModeBar: some View {
        VStack(spacing: 8) {
            Text(editModeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    viewModel.cancelEditMode()
                    currentDrawStart = nil
                    currentDrawEnd = nil
                } label: {
                    Text(viewModel.editMode == .deleteRestriction ? String(localized: "map.done") : String(localized: "settings.cancel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.editMode == .deleteRestriction ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundStyle(viewModel.editMode == .deleteRestriction ? .blue : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Don't show confirm button for deleteRestriction - deletes happen immediately on tap
                if viewModel.editMode != .deleteRestriction {
                    Button {
                        Task { await viewModel.confirmEditMode(currentDrawStart: currentDrawStart, currentDrawEnd: currentDrawEnd) }
                        currentDrawStart = nil
                        currentDrawEnd = nil
                    } label: {
                        Text(confirmButtonTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(editModeColor.opacity(0.15))
                            .foregroundStyle(editModeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canConfirmEditMode)
                    .opacity(canConfirmEditMode ? 1.0 : 0.4)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Room Edit Bar
    @ViewBuilder
    var roomEditBar: some View {
        VStack(spacing: 8) {
            if viewModel.selectedSegmentIds.isEmpty {
                Text(String(localized: "rooms.select_to_edit"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.selectedSegmentIds.count == 1 {
                Text(String(localized: "rooms.one_selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: String(localized: "rooms.multiple_selected %lld"), viewModel.selectedSegmentIds.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Fixed height buttons with consistent sizing
            HStack(spacing: 8) {
                // Cancel button - always visible
                RoomEditButton(
                    title: String(localized: "settings.cancel"),
                    icon: "xmark",
                    color: .gray
                ) {
                    viewModel.cancelEditMode()
                }

                // Action buttons based on selection
                if viewModel.selectedSegmentIds.count == 1 {
                    if viewModel.hasSegmentRename {
                        RoomEditButton(
                            title: String(localized: "rooms.rename"),
                            icon: "pencil",
                            color: .blue
                        ) {
                            if let segmentId = viewModel.selectedSegmentIds.first {
                                viewModel.renameSegmentId = segmentId
                                // Use displayName for initial value
                                viewModel.renameNewName = viewModel.segments.first { $0.id == segmentId }?.displayName ?? ""
                                viewModel.showRenameSheet = true
                            }
                        }
                    }

                    if viewModel.hasSegmentEdit {
                        RoomEditButton(
                            title: String(localized: "rooms.split"),
                            icon: "scissors",
                            color: .orange
                        ) {
                            viewModel.splitSegmentId = viewModel.selectedSegmentIds.first
                            viewModel.editMode = .splitRoom
                        }
                    }
                } else if viewModel.selectedSegmentIds.count == 2 && viewModel.hasSegmentEdit {
                    RoomEditButton(
                        title: String(localized: "rooms.join_action"),
                        icon: "arrow.triangle.merge",
                        color: .green
                    ) {
                        Task { await viewModel.joinRooms(ids: Array(viewModel.selectedSegmentIds)) }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - GoTo Confirm Bar
    @ViewBuilder
    var goToConfirmBar: some View {
        VStack(spacing: 8) {
            Text(viewModel.editingPreset != nil ? String(localized: "map.preset_move_hint") : String(localized: "map.goto_confirm_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    // Cancel
                    viewModel.goToMarkerPosition = nil
                    viewModel.goToApiCoords = nil
                    viewModel.showGoToConfirm = false
                    viewModel.editingPreset = nil
                    viewModel.cancelEditMode()
                } label: {
                    Text(String(localized: "settings.cancel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    if let coords = viewModel.goToApiCoords {
                        if let preset = viewModel.editingPreset {
                            // Update preset position
                            var updatedPreset = preset
                            updatedPreset.x = coords.x
                            updatedPreset.y = coords.y
                            viewModel.presetStore.updatePreset(updatedPreset)
                            viewModel.editingPreset = nil
                            viewModel.goToMarkerPosition = nil
                            viewModel.goToApiCoords = nil
                            viewModel.showGoToConfirm = false
                        } else {
                            // Confirm and go
                            Task {
                                await viewModel.goToPoint(x: coords.x, y: coords.y)
                                viewModel.goToMarkerPosition = nil
                                viewModel.goToApiCoords = nil
                                viewModel.showGoToConfirm = false
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.editingPreset != nil ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        Text(viewModel.editingPreset != nil ? String(localized: "settings.save") : String(localized: "map.goto_go"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.editingPreset != nil ? Color.green : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Save Preset Confirm Bar
    @ViewBuilder
    var savePresetConfirmBar: some View {
        VStack(spacing: 8) {
            Text(String(localized: "map.save_preset_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    // Cancel
                    viewModel.goToMarkerPosition = nil
                    viewModel.pendingGoToX = nil
                    viewModel.pendingGoToY = nil
                    viewModel.cancelEditMode()
                } label: {
                    Text(String(localized: "settings.cancel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    // Show save sheet
                    viewModel.showSavePresetSheet = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(String(localized: "settings.save"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Split Room Bar
    @ViewBuilder
    var splitRoomBar: some View {
        VStack(spacing: 8) {
            Text(String(localized: "rooms.split_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    viewModel.splitSegmentId = nil
                    currentDrawStart = nil
                    currentDrawEnd = nil
                    viewModel.editMode = .roomEdit
                } label: {
                    Text(String(localized: "settings.cancel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    currentDrawStart = nil
                    currentDrawEnd = nil
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(currentDrawStart == nil)
                .opacity(currentDrawStart == nil ? 0.4 : 1.0)

                Button {
                    guard let segmentId = viewModel.splitSegmentId,
                          let start = currentDrawStart,
                          let end = currentDrawEnd else { return }
                    Task {
                        await viewModel.splitRoom(
                            segmentId: segmentId,
                            start: start,
                            end: end,
                            viewSize: currentViewSize,
                            gestureScale: scale,
                            gestureOffset: offset
                        )
                        currentDrawStart = nil
                        currentDrawEnd = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "scissors")
                        Text(String(localized: "rooms.split_action"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(currentDrawStart == nil || currentDrawEnd == nil)
                .opacity(currentDrawStart == nil || currentDrawEnd == nil ? 0.4 : 1.0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    var editModeDescription: String {
        switch viewModel.editMode {
        case .zone: return String(localized: "map.zone_hint")
        case .noGoArea: return String(localized: "map.nogo_hint")
        case .noMopArea: return String(localized: "map.nomop_hint")
        case .virtualWall: return String(localized: "map.wall_hint")
        case .goTo: return String(localized: "map.goto_hint")
        case .savePreset: return String(localized: "map.save_preset_hint")
        case .roomEdit: return String(localized: "rooms.select_to_edit")
        case .splitRoom: return String(localized: "rooms.split_hint")
        case .deleteRestriction: return String(localized: "map.delete_hint")
        case .none: return ""
        }
    }

    var confirmButtonTitle: String {
        switch viewModel.editMode {
        case .zone: return String(localized: "map.clean_zones")
        case .noGoArea, .noMopArea, .virtualWall: return String(localized: "settings.save")
        case .goTo: return String(localized: "map.goto")
        case .savePreset: return String(localized: "settings.save")
        case .roomEdit: return ""
        case .splitRoom: return String(localized: "rooms.split_action")
        case .deleteRestriction: return String(localized: "settings.save")
        case .none: return ""
        }
    }

    var editModeColor: Color {
        switch viewModel.editMode {
        case .zone: return .orange
        case .noGoArea: return .red
        case .noMopArea: return .blue
        case .virtualWall: return .purple
        case .goTo: return .blue
        case .savePreset: return .yellow
        case .roomEdit: return .indigo
        case .splitRoom: return .orange
        case .deleteRestriction: return .red
        case .none: return .gray
        }
    }

    var canConfirmEditMode: Bool {
        switch viewModel.editMode {
        case .zone: return !viewModel.drawnZones.isEmpty
        case .noGoArea: return !viewModel.drawnNoGoAreas.isEmpty || viewModel.existingRestrictions != nil
        case .noMopArea: return !viewModel.drawnNoMopAreas.isEmpty || viewModel.existingRestrictions != nil
        case .virtualWall: return !viewModel.drawnVirtualWalls.isEmpty || viewModel.existingRestrictions != nil
        case .goTo: return currentDrawStart != nil
        case .savePreset: return currentDrawStart != nil
        case .roomEdit: return false
        case .splitRoom: return currentDrawStart != nil && currentDrawEnd != nil
        case .deleteRestriction: return viewModel.restrictionToDelete != nil
        case .none: return false
        }
    }
}
