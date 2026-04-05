import SwiftUI

// MARK: - MapContentView Overlay Extensions
extension MapContentView {

    // MARK: - GoTo Marker Overlay

    @ViewBuilder
    func goToMarkerOverlay(params: MapParams, pixelSize: Int, geometry: GeometryProxy) -> some View {
        if let markerPos = viewModel.goToMarkerPosition, (viewModel.showGoToConfirm || viewModel.editMode == .savePreset) {
            let screenPos = mapToScreenCoords(markerPos, viewSize: geometry.size)
            // Yellow for preset save/edit, blue for regular goTo
            let markerColor: Color = (viewModel.editMode == .savePreset || viewModel.editingPreset != nil) ? .yellow : .blue

            Circle()
                .fill(markerColor.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(markerColor, lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .fill(markerColor)
                        .frame(width: 12, height: 12)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                .position(screenPos)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Convert screen position to map coordinates
                            let mapPos = screenToMapCoords(value.location, viewSize: geometry.size)
                            viewModel.goToMarkerPosition = mapPos
                            // Update API coordinates
                            let pixelX = Int(((mapPos.x - params.offsetX) / params.scale).rounded())
                            let pixelY = Int(((mapPos.y - params.offsetY) / params.scale).rounded())
                            let apiX = pixelX * pixelSize
                            let apiY = pixelY * pixelSize
                            viewModel.goToApiCoords = (x: apiX, y: apiY)
                            // Also update pending preset coordinates
                            if viewModel.editMode == .savePreset {
                                viewModel.pendingGoToX = apiX
                                viewModel.pendingGoToY = apiY
                            }
                        }
                )
        }
    }

    // MARK: - Preset Markers Overlay

    @ViewBuilder
    func presetMarkersOverlay(params: MapParams, pixelSize: Int, geometry: GeometryProxy) -> some View {
        if viewModel.showPresetsOnMap && !viewModel.showGoToConfirm && viewModel.editMode == .none {
            ForEach(viewModel.presetStore.presets(for: robot.id)) { preset in
                // Calculate position in map coordinates
                let mapX = CGFloat(preset.x / pixelSize) * params.scale + params.offsetX
                let mapY = CGFloat(preset.y / pixelSize) * params.scale + params.offsetY
                // Convert to screen coordinates
                let screenPos = mapToScreenCoords(CGPoint(x: mapX, y: mapY), viewSize: geometry.size)

                Button {
                    Task { await viewModel.goToPoint(x: preset.x, y: preset.y) }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.yellow)
                        Text(preset.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(.systemBackground).opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .position(screenPos)
            }
        }
    }

    // MARK: - Restriction Delete Overlay

    @ViewBuilder
    func restrictionDeleteOverlay(params: MapParams, restrictions: VirtualRestrictions, viewSize: CGSize) -> some View {
        let ps = CGFloat(viewModel.map?.pixelSize ?? 5)

        // Virtual walls
        ForEach(Array(restrictions.virtualWalls.enumerated()), id: \.offset) { index, wall in
            let startX = CGFloat(wall.points.pA.x) / ps * params.scale + params.offsetX
            let startY = CGFloat(wall.points.pA.y) / ps * params.scale + params.offsetY
            let endX = CGFloat(wall.points.pB.x) / ps * params.scale + params.offsetX
            let endY = CGFloat(wall.points.pB.y) / ps * params.scale + params.offsetY
            let midX = (startX + endX) / 2
            let midY = (startY + endY) / 2
            let screenPos = mapToScreenCoords(CGPoint(x: midX, y: midY), viewSize: viewSize)

            Button {
                Task {
                    await viewModel.deleteRestriction(type: .virtualWall, index: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.purple)
                }
            }
            .accessibilityLabel(String(localized: "map.delete_virtual_wall"))
            .buttonStyle(.plain)
            .position(screenPos)
        }

        // No-go zones
        ForEach(Array(restrictions.restrictedZones.enumerated()), id: \.offset) { index, zone in
            let centerX = CGFloat(zone.points.pA.x + zone.points.pC.x) / 2 / ps * params.scale + params.offsetX
            let centerY = CGFloat(zone.points.pA.y + zone.points.pC.y) / 2 / ps * params.scale + params.offsetY
            let screenPos = mapToScreenCoords(CGPoint(x: centerX, y: centerY), viewSize: viewSize)

            Button {
                Task {
                    await viewModel.deleteRestriction(type: .noGoZone, index: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            .accessibilityLabel(String(localized: "map.delete_nogo_zone"))
            .buttonStyle(.plain)
            .position(screenPos)
        }

        // No-mop zones
        ForEach(Array(restrictions.noMopZones.enumerated()), id: \.offset) { index, zone in
            let centerX = CGFloat(zone.points.pA.x + zone.points.pC.x) / 2 / ps * params.scale + params.offsetX
            let centerY = CGFloat(zone.points.pA.y + zone.points.pC.y) / 2 / ps * params.scale + params.offsetY
            let screenPos = mapToScreenCoords(CGPoint(x: centerX, y: centerY), viewSize: viewSize)

            Button {
                Task {
                    await viewModel.deleteRestriction(type: .noMopZone, index: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .accessibilityLabel(String(localized: "map.delete_nomop_zone"))
            .buttonStyle(.plain)
            .position(screenPos)
        }
    }
}

// MARK: - Map Sheets Modifier

struct MapSheetsModifier: ViewModifier {
    @Bindable var viewModel: MapViewModel
    let robot: RobotConfig
    let currentViewSize: CGSize
    let calculateMapParams: ([MapLayer], Int, CGSize) -> MapParams?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showRenameSheet) {
                MapRenameSheet(
                    segmentName: viewModel.segments.first { $0.id == viewModel.renameSegmentId }?.displayName ?? "",
                    newName: $viewModel.renameNewName,
                    onRename: {
                        Task { await viewModel.renameRoom(id: viewModel.renameSegmentId ?? "", name: viewModel.renameNewName) }
                    },
                    onCancel: {
                        viewModel.renameSegmentId = nil
                        viewModel.renameNewName = ""
                    }
                )
            }
            .sheet(isPresented: $viewModel.showSavePresetSheet) {
                SaveGoToPresetSheet(
                    presetName: $viewModel.newPresetName,
                    onSave: {
                        viewModel.saveCurrentLocationAsPreset()
                    },
                    onCancel: {
                        viewModel.pendingGoToX = nil
                        viewModel.pendingGoToY = nil
                        viewModel.newPresetName = ""
                    }
                )
            }
            .sheet(isPresented: $viewModel.showPresetsSheet) {
                GoToPresetsSheet(
                    robot: robot,
                    presetStore: viewModel.presetStore,
                    onSelect: { preset in
                        Task { await viewModel.goToPoint(x: preset.x, y: preset.y) }
                    },
                    onEdit: { preset in
                        viewModel.editingPreset = preset
                        // Show the preset on map and allow repositioning
                        if let map = viewModel.map, let layers = map.layers {
                            let pixelSize = map.pixelSize ?? 5
                            if let params = calculateMapParams(layers, pixelSize, currentViewSize) {
                                let mapX = CGFloat(preset.x / pixelSize) * params.scale + params.offsetX
                                let mapY = CGFloat(preset.y / pixelSize) * params.scale + params.offsetY
                                viewModel.goToMarkerPosition = CGPoint(x: mapX, y: mapY)
                                viewModel.goToApiCoords = (x: preset.x, y: preset.y)
                                viewModel.showGoToConfirm = true
                            }
                        }
                    }
                )
            }
    }
}
