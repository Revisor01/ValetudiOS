import SwiftUI
import os

enum MapEditMode: Equatable {
    case none
    case zone           // Draw cleaning zones
    case noGoArea       // Draw no-go zones
    case noMopArea      // Draw no-mop zones
    case virtualWall    // Draw virtual walls
    case goTo           // Tap to go to location
    case savePreset     // Tap to save location as preset
    case roomEdit       // Edit rooms (rename, join, split)
    case splitRoom      // Draw split line on selected room
    case deleteRestriction // Tap to delete restriction
}

// MARK: - Restriction Identifier
enum RestrictionType {
    case virtualWall
    case noGoZone
    case noMopZone
}

struct RestrictionIdentifier: Equatable {
    let type: RestrictionType
    let index: Int
}

// MARK: - Map Tab View (for Tab Bar)
struct MapTabView: View {
    @Environment(RobotManager.self) var robotManager
    let robot: RobotConfig
    @State private var viewId = UUID()

    var body: some View {
        NavigationStack {
            MapContentView(robot: robot, robotManager: robotManager, isFullscreen: true)
                .id(viewId)
                .navigationTitle(String(localized: "map.title"))
                .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: robot.id) { _, _ in
            // Force complete view rebuild when robot changes
            viewId = UUID()
        }
    }
}

// MARK: - Embedded Map Preview (for Detail View)
struct MapPreviewView: View {
    @Environment(RobotManager.self) var robotManager
    let robot: RobotConfig
    @State private var map: RobotMap?
    @State private var restrictions: VirtualRestrictions?
    @State private var isLoading = true
    @State private var refreshTask: Task<Void, Never>?
    @Binding var showFullMap: Bool

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "MapView")

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    var body: some View {
        Button {
            showFullMap = true
        } label: {
            ZStack {
                if isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                        }
                } else if let map = map {
                    GeometryReader { geometry in
                        MiniMapView(map: map, viewSize: geometry.size, restrictions: restrictions)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "map")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text(String(localized: "map.unavailable"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                // Overlay tap hint
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2)
                            Text(String(localized: "map.tap_to_expand"))
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadMap()
            startLiveRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }

    private func loadMap() async {
        guard let api = api else {
            isLoading = false
            return
        }

        do {
            async let mapTask = api.getMap()
            async let restrictionsTask = api.getVirtualRestrictions()

            map = try await mapTask
            restrictions = try? await restrictionsTask
        } catch {
            logger.error("Failed to load map preview: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func startLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled, let api = api {
                    if let newMap = try? await api.getMap() {
                        await MainActor.run { map = newMap }
                    }
                }
            }
        }
    }
}

// MARK: - Map Content View (shared between Tab and Sheet)
struct MapContentView: View {
    @Environment(RobotManager.self) var robotManager
    @Environment(ErrorRouter.self) var errorRouter
    let robot: RobotConfig
    let isFullscreen: Bool

    @State var viewModel: MapViewModel

    // MARK: - Gesture / View-local state (inherently view-bound)
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0
    @State var offset: CGSize = .zero
    @State var lastOffset: CGSize = .zero

    // Drawing state (gesture-local, frame-dependent)
    @State var currentDrawStart: CGPoint?
    @State var currentDrawEnd: CGPoint?
    @State var isDraggingSplitStart = false
    @State var isDraggingSplitEnd = false

    // Store current view size for coordinate calculations
    @State var currentViewSize: CGSize = .zero

    init(robot: RobotConfig, robotManager: RobotManager, isFullscreen: Bool = false) {
        self.robot = robot
        self.isFullscreen = isFullscreen
        _viewModel = State(initialValue: MapViewModel(robot: robot, robotManager: robotManager, isFullscreen: isFullscreen))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map
            GeometryReader { geometry in
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()

                    if viewModel.isLoading && viewModel.map == nil {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else if let map = viewModel.map {
                        let pixelSize = map.pixelSize ?? 5
                        let params = calculateMapParams(
                            layers: map.layers ?? [],
                            pixelSize: pixelSize,
                            size: geometry.size
                        )

                        ZStack {
                            InteractiveMapView(
                                map: map,
                                segments: viewModel.segments,
                                selectedSegmentIds: $viewModel.selectedSegmentIds,
                                viewSize: geometry.size,
                                drawnZones: viewModel.drawnZones,
                                drawnNoGoAreas: viewModel.drawnNoGoAreas,
                                drawnNoMopAreas: viewModel.drawnNoMopAreas,
                                drawnVirtualWalls: viewModel.drawnVirtualWalls,
                                existingRestrictions: viewModel.existingRestrictions,
                                currentDrawStart: currentDrawStart,
                                currentDrawEnd: currentDrawEnd,
                                editMode: viewModel.editMode,
                                showRoomLabels: viewModel.showRoomLabels
                            )
                            .id(viewModel.mapRefreshId) // Force redraw when segments change
                            .scaleEffect(scale)
                            .offset(offset)

                            // Drawing overlay for edit modes
                            if viewModel.editMode != .none && viewModel.editMode != .roomEdit && viewModel.editMode != .deleteRestriction {
                                // For splitRoom with existing line, show drag handles
                                if viewModel.editMode == .splitRoom && currentDrawStart != nil && currentDrawEnd != nil {
                                    splitLineHandles(geometry: geometry)
                                } else if viewModel.editMode != .splitRoom || currentDrawStart == nil {
                                    drawingOverlay(geometry: geometry)
                                }
                            }

                            // GoTo/SavePreset marker (draggable circle)
                            // goToMarkerPosition is stored in map coordinates
                            if let markerPos = viewModel.goToMarkerPosition, (viewModel.showGoToConfirm || viewModel.editMode == .savePreset), let p = params {
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
                                                let pixelX = Int(((mapPos.x - p.offsetX) / p.scale).rounded())
                                                let pixelY = Int(((mapPos.y - p.offsetY) / p.scale).rounded())
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

                            // Preset markers (when toggled visible)
                            if viewModel.showPresetsOnMap && !viewModel.showGoToConfirm && viewModel.editMode == .none, let p = params {
                                ForEach(viewModel.presetStore.presets(for: robot.id)) { preset in
                                    // Calculate position in map coordinates
                                    let mapX = CGFloat(preset.x / pixelSize) * p.scale + p.offsetX
                                    let mapY = CGFloat(preset.y / pixelSize) * p.scale + p.offsetY
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

                            // Restriction delete targets
                            if viewModel.editMode == .deleteRestriction, let p = params, let restrictions = viewModel.existingRestrictions {
                                restrictionDeleteOverlay(params: p, restrictions: restrictions, viewSize: geometry.size)
                            }

                            // Offline banner
                            if viewModel.isOffline {
                                VStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wifi.slash")
                                            .font(.caption)
                                        Text(String(localized: "map.offline"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .padding(.top, 8)
                                    Spacer()
                                }
                            }
                        }
                        .gesture(combinedGesture)
                    } else {
                        ContentUnavailableView(
                            viewModel.loadError ?? String(localized: "map.unavailable"),
                            systemImage: "map"
                        )
                    }

                }
                .onAppear {
                    currentViewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    currentViewSize = newSize
                }
            }

            // Bottom bar
            selectedRoomsBar
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showRoomLabels.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.showRoomLabels ? "tag.fill" : "tag")
                            .font(.system(size: 14))
                    }

                    Button {
                        withAnimation(.spring) {
                            scale = 1.0
                            offset = .zero
                            lastScale = 1.0
                            lastOffset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                    }
                }
            }
        }
        .task {
            viewModel.errorRouter = errorRouter
            await viewModel.loadMap()
            viewModel.startMapRefresh()
        }
        .onDisappear {
            viewModel.stopMapRefresh()
        }
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
                        if let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: currentViewSize) {
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

    // MARK: - Coordinate Transformation
    // Convert screen coordinates to map coordinates (accounting for zoom/pan)
    // Delegates to free function screenToMapCoords(_:scale:offset:viewSize:) in MapGeometry.swift
    func screenToMapCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - offset.width - viewSize.width / 2) / scale + viewSize.width / 2,
            y: (point.y - offset.height - viewSize.height / 2) / scale + viewSize.height / 2
        )
    }

    // Delegates to free function mapToScreenCoords(_:scale:offset:viewSize:) in MapGeometry.swift
    func mapToScreenCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - viewSize.width / 2) * scale + viewSize.width / 2 + offset.width,
            y: (point.y - viewSize.height / 2) * scale + viewSize.height / 2 + offset.height
        )
    }

    // MARK: - Drawing Overlay
    @ViewBuilder
    func drawingOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Convert screen coordinates to map coordinates
                        let mapStart = screenToMapCoords(value.startLocation, viewSize: geometry.size)
                        let mapEnd = screenToMapCoords(value.location, viewSize: geometry.size)

                        // For goTo/savePreset: always update to new tap position
                        // For other modes: only set start once (for drag drawing)
                        if viewModel.editMode == .goTo || viewModel.editMode == .savePreset {
                            currentDrawStart = mapStart
                        } else if currentDrawStart == nil {
                            currentDrawStart = mapStart
                        }
                        currentDrawEnd = mapEnd
                    }
                    .onEnded { _ in
                        finishDrawing(in: geometry.size)
                    }
            )
    }

    // MARK: - Split Line Handles
    @ViewBuilder
    func splitLineHandles(geometry: GeometryProxy) -> some View {
        let viewSize = geometry.size

        ZStack {
            // Tap area to draw new line (resets existing)
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let mapStart = screenToMapCoords(value.startLocation, viewSize: viewSize)
                            let mapEnd = screenToMapCoords(value.location, viewSize: viewSize)

                            if currentDrawStart == nil || (currentDrawStart != nil && currentDrawEnd != nil && !isDraggingSplitStart && !isDraggingSplitEnd) {
                                // Start new line
                                currentDrawStart = mapStart
                                currentDrawEnd = mapEnd
                            } else {
                                currentDrawEnd = mapEnd
                            }
                        }
                        .onEnded { _ in
                            // Line drawn, handles will appear
                        }
                )

            // Start handle (converted to screen coords for display)
            if let start = currentDrawStart {
                let screenStart = mapToScreenCoords(start, viewSize: viewSize)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(radius: 3)
                    .position(screenStart)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingSplitStart = true
                                currentDrawStart = screenToMapCoords(value.location, viewSize: viewSize)
                            }
                            .onEnded { _ in
                                isDraggingSplitStart = false
                            }
                    )
            }

            // End handle (converted to screen coords for display)
            if let end = currentDrawEnd {
                let screenEnd = mapToScreenCoords(end, viewSize: viewSize)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(radius: 3)
                    .position(screenEnd)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingSplitEnd = true
                                currentDrawEnd = screenToMapCoords(value.location, viewSize: viewSize)
                            }
                            .onEnded { _ in
                                isDraggingSplitEnd = false
                            }
                    )
            }

            // Draw the line preview (converted to screen coords)
            if let start = currentDrawStart, let end = currentDrawEnd {
                let screenStart = mapToScreenCoords(start, viewSize: viewSize)
                let screenEnd = mapToScreenCoords(end, viewSize: viewSize)
                Path { path in
                    path.move(to: screenStart)
                    path.addLine(to: screenEnd)
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
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
            .buttonStyle(.plain)
            .position(screenPos)
        }
    }

    func finishDrawing(in size: CGSize) {
        guard let start = currentDrawStart, let end = currentDrawEnd else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        guard let map = viewModel.map, let layers = map.layers else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        let pixelSize = map.pixelSize ?? 5
        guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        // start/end are already in map coordinates (from screenToMapCoords in drawingOverlay)
        // We just need to convert from map view coordinates to pixel coordinates
        let pixelStartX = Int(((start.x - params.offsetX) / params.scale).rounded())
        let pixelStartY = Int(((start.y - params.offsetY) / params.scale).rounded())
        let pixelEndX = Int(((end.x - params.offsetX) / params.scale).rounded())
        let pixelEndY = Int(((end.y - params.offsetY) / params.scale).rounded())

        // API coordinates are pixel coordinates multiplied by pixelSize
        let apiStartX = pixelStartX * pixelSize
        let apiStartY = pixelStartY * pixelSize
        let apiEndX = pixelEndX * pixelSize
        let apiEndY = pixelEndY * pixelSize

        let minX = min(apiStartX, apiEndX)
        let maxX = max(apiStartX, apiEndX)
        let minY = min(apiStartY, apiEndY)
        let maxY = max(apiStartY, apiEndY)

        switch viewModel.editMode {
        case .zone:
            let zone = CleaningZone(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnZones.append(zone)

        case .noGoArea:
            let area = NoGoArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnNoGoAreas.append(area)

        case .noMopArea:
            let area = NoMopArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnNoMopAreas.append(area)

        case .virtualWall:
            let wall = VirtualWall(
                points: VirtualWallPoints(
                    pA: ZonePoint(x: apiStartX, y: apiStartY),
                    pB: ZonePoint(x: apiEndX, y: apiEndY)
                )
            )
            viewModel.drawnVirtualWalls.append(wall)

        case .goTo:
            // Tap places/moves marker to new position
            viewModel.goToMarkerPosition = start
            viewModel.goToApiCoords = (x: apiStartX, y: apiStartY)
            viewModel.showGoToConfirm = true
            return

        case .savePreset:
            // Tap places/moves marker to new position
            viewModel.goToMarkerPosition = start
            viewModel.pendingGoToX = apiStartX
            viewModel.pendingGoToY = apiStartY
            return

        case .splitRoom:
            // Split line drawing is handled, don't clear yet
            return

        case .roomEdit, .deleteRestriction, .none:
            break
        }

        currentDrawStart = nil
        currentDrawEnd = nil
    }

    // Delegates to free function calculateMapParams(layers:pixelSize:size:padding:) in MapGeometry.swift with padding: 20
    func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        let padding: CGFloat = 20
        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i]); maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1]); maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }
        guard minX < Int.max else { return nil }
        let cW = CGFloat(maxX - minX + pixelSize), cH = CGFloat(maxY - minY + pixelSize)
        let aW = size.width - padding * 2, aH = size.height - padding * 2
        let scale = min(aW / cW, aH / cH)
        return MapParams(
            scale: scale,
            offsetX: padding + (aW - cW * scale) / 2 - CGFloat(minX) * scale,
            offsetY: padding + (aH - cH * scale) / 2 - CGFloat(minY) * scale,
            minX: minX, minY: minY
        )
    }

    // MARK: - Gestures
    var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                    scale = max(0.5, min(8.0, scale))
                }
                .onEnded { _ in
                    lastScale = scale
                },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }
}

// MARK: - Map View (Sheet/Modal version - uses MapContentView)
struct MapView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(RobotManager.self) var robotManager
    let robot: RobotConfig

    var body: some View {
        NavigationStack {
            MapContentView(robot: robot, robotManager: robotManager, isFullscreen: true)
                .navigationTitle(String(localized: "map.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .fontWeight(.semibold)
                        }
                    }
                }
        }
    }
}

#Preview {
    MapView(robot: RobotConfig(name: "Test", host: "192.168.0.35"))
        .environment(RobotManager())
}
