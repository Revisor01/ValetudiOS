import SwiftUI

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

// MARK: - Map Calculation Parameters
struct MapParams {
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let minX: Int
    let minY: Int
}

// MARK: - Map Tab View (for Tab Bar)
struct MapTabView: View {
    @EnvironmentObject var robotManager: RobotManager
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
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig
    @State private var map: RobotMap?
    @State private var restrictions: VirtualRestrictions?
    @State private var isLoading = true
    @State private var refreshTask: Task<Void, Never>?
    @Binding var showFullMap: Bool

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
            print("Failed to load map preview: \(error)")
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

// MARK: - Mini Map View (simplified, no interaction)
struct MiniMapView: View {
    let map: RobotMap
    let viewSize: CGSize
    var restrictions: VirtualRestrictions?

    var body: some View {
        Canvas { context, size in
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else { return }

            guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

            // Draw floor
            drawLayers(context: context, layers: layers, type: "floor", color: Color(white: 0.92), params: params, pixelSize: pixelSize)

            // Draw segments
            for layer in layers where layer.type == "segment" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }
                let segmentId = layer.metaData?.segmentId
                let color = segmentColor(segmentId: segmentId).opacity(0.6)
                drawPixels(context: context, pixels: pixels, color: color, params: params, pixelSize: pixelSize)
            }

            // Draw walls (thinner for minimap)
            for layer in layers where layer.type == "wall" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }
                drawThinWalls(context: context, pixels: pixels, color: Color(white: 0.25), params: params, pixelSize: pixelSize)
            }

            // Draw restrictions
            if let restrictions = restrictions {
                let ps = CGFloat(pixelSize)
                // Virtual walls
                for wall in restrictions.virtualWalls {
                    drawVirtualWall(context: context, wall: wall, params: params, pixelSize: ps)
                }
                // No-go zones
                for zone in restrictions.restrictedZones {
                    drawRestrictedZone(context: context, zone: zone, params: params, pixelSize: ps, color: .red.opacity(0.3))
                }
                // No-mop zones
                for zone in restrictions.noMopZones {
                    drawNoMopZone(context: context, zone: zone, params: params, pixelSize: ps, color: .blue.opacity(0.3))
                }
            }

            // Draw entities
            if let entities = map.entities {
                // Draw path first (under robot)
                for entity in entities where entity.type == "path" || entity.type == "predicted_path" {
                    drawPath(context: context, entity: entity, params: params, pixelSize: pixelSize)
                }
                for entity in entities where entity.type == "charger_location" {
                    drawCharger(context: context, entity: entity, params: params, pixelSize: pixelSize)
                }
                for entity in entities where entity.type == "robot_position" {
                    drawRobot(context: context, entity: entity, params: params, pixelSize: pixelSize)
                }
            }
        }
        .background(Color(.systemGray6))
    }

    private func drawVirtualWall(context: GraphicsContext, wall: VirtualWall, params: MapParams, pixelSize: CGFloat) {
        let p = wall.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / pixelSize * params.scale + params.offsetY
        ))
        context.stroke(path, with: .color(.purple), style: StrokeStyle(lineWidth: 2))
    }

    private func drawRestrictedZone(context: GraphicsContext, zone: NoGoArea, params: MapParams, pixelSize: CGFloat, color: Color) {
        let p = zone.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) / pixelSize * params.scale + params.offsetY
        ))
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color.opacity(1.0)), lineWidth: 1)
    }

    private func drawNoMopZone(context: GraphicsContext, zone: NoMopArea, params: MapParams, pixelSize: CGFloat, color: Color) {
        let p = zone.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) / pixelSize * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) / pixelSize * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) / pixelSize * params.scale + params.offsetY
        ))
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color.opacity(1.0)), lineWidth: 1)
    }

    private func drawPath(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 4 else { return }
        let ps = CGFloat(pixelSize)

        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(points[0]) / ps * params.scale + params.offsetX,
            y: CGFloat(points[1]) / ps * params.scale + params.offsetY
        ))

        var i = 2
        while i < points.count - 1 {
            path.addLine(to: CGPoint(
                x: CGFloat(points[i]) / ps * params.scale + params.offsetX,
                y: CGFloat(points[i + 1]) / ps * params.scale + params.offsetY
            ))
            i += 2
        }

        let isPredicted = entity.type == "predicted_path"
        let color = isPredicted ? Color(white: 0.4).opacity(0.5) : Color(white: 0.35).opacity(0.8)
        context.stroke(path, with: .color(color), lineWidth: 0.75)
    }

    private let segmentColors: [Color] = [
        Color(red: 0.65, green: 0.80, blue: 0.92),  // Soft sky blue
        Color(red: 0.70, green: 0.88, blue: 0.75),  // Soft mint green
        Color(red: 0.92, green: 0.78, blue: 0.72),  // Soft peach
        Color(red: 0.82, green: 0.75, blue: 0.90),  // Soft lavender
    ]

    private func segmentColor(segmentId: String?) -> Color {
        if let id = segmentId, let num = Int(id) {
            return segmentColors[num % segmentColors.count]
        }
        return segmentColors[0]
    }

    private func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 10
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    private func drawLayers(context: GraphicsContext, layers: [MapLayer], type: String, color: Color, params: MapParams, pixelSize: Int) {
        for layer in layers where layer.type == type {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            drawPixels(context: context, pixels: pixels, color: color, params: params, pixelSize: pixelSize)
        }
    }

    private func drawPixels(context: GraphicsContext, pixels: [Int], color: Color, params: MapParams, pixelSize: Int) {
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)
            context.fill(Path(rect), with: .color(color))
            i += 2
        }
    }

    private func drawThinWalls(context: GraphicsContext, pixels: [Int], color: Color, params: MapParams, pixelSize: Int) {
        // Draw walls at 30% of normal size for cleaner minimap appearance
        let pixelScale = params.scale * CGFloat(pixelSize) * 0.3
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: max(pixelScale, 1), height: max(pixelScale, 1))
            context.fill(Path(rect), with: .color(color))
            i += 2
        }
    }

    private func drawRobot(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 2 else { return }
        let ps = CGFloat(pixelSize)
        let x = CGFloat(points[0]) / ps * params.scale + params.offsetX
        let y = CGFloat(points[1]) / ps * params.scale + params.offsetY
        let size: CGFloat = 18

        // Pulsing glow effect
        let glowRect = CGRect(x: x - size/2 - 4, y: y - size/2 - 4, width: size + 8, height: size + 8)
        context.fill(Circle().path(in: glowRect), with: .color(Color(white: 0.2).opacity(0.3)))

        // Outer ring
        let outerRect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(Circle().path(in: outerRect), with: .color(Color(white: 0.2)))

        // Inner body
        let innerSize: CGFloat = 12
        let innerRect = CGRect(x: x - innerSize/2, y: y - innerSize/2, width: innerSize, height: innerSize)
        context.fill(Circle().path(in: innerRect), with: .color(Color(white: 0.3)))

        // Vacuum pattern (small circle)
        let dotSize: CGFloat = 4
        let dotRect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
        context.fill(Circle().path(in: dotRect), with: .color(.white))
    }

    private func drawCharger(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 2 else { return }
        let ps = CGFloat(pixelSize)
        let x = CGFloat(points[0]) / ps * params.scale + params.offsetX
        let y = CGFloat(points[1]) / ps * params.scale + params.offsetY
        let size: CGFloat = 16

        // Glow
        let glowRect = CGRect(x: x - size/2 - 3, y: y - size/2 - 3, width: size + 6, height: size + 6)
        context.fill(RoundedRectangle(cornerRadius: 5).path(in: glowRect), with: .color(Color(white: 0.2).opacity(0.3)))

        // Base
        let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(RoundedRectangle(cornerRadius: 4).path(in: rect), with: .color(Color(white: 0.2)))

        // House shape for dock
        var house = Path()
        house.move(to: CGPoint(x: x, y: y - 5))
        house.addLine(to: CGPoint(x: x + 5, y: y))
        house.addLine(to: CGPoint(x: x + 3, y: y))
        house.addLine(to: CGPoint(x: x + 3, y: y + 4))
        house.addLine(to: CGPoint(x: x - 3, y: y + 4))
        house.addLine(to: CGPoint(x: x - 3, y: y))
        house.addLine(to: CGPoint(x: x - 5, y: y))
        house.closeSubpath()
        context.fill(house, with: .color(.white))
    }
}

// MARK: - Map Content View (shared between Tab and Sheet)
struct MapContentView: View {
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig
    let isFullscreen: Bool

    @StateObject private var viewModel: MapViewModel

    // MARK: - Gesture / View-local state (inherently view-bound)
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Drawing state (gesture-local, frame-dependent)
    @State private var currentDrawStart: CGPoint?
    @State private var currentDrawEnd: CGPoint?
    @State private var isDraggingSplitStart = false
    @State private var isDraggingSplitEnd = false

    // Store current view size for coordinate calculations
    @State private var currentViewSize: CGSize = .zero

    init(robot: RobotConfig, robotManager: RobotManager, isFullscreen: Bool = false) {
        self.robot = robot
        self.isFullscreen = isFullscreen
        _viewModel = StateObject(wrappedValue: MapViewModel(robot: robot, robotManager: robotManager, isFullscreen: isFullscreen))
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
                                                let pixelX = Int((mapPos.x - p.offsetX) / p.scale)
                                                let pixelY = Int((mapPos.y - p.offsetY) / p.scale)
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

    // MARK: - Bottom Control Bar
    @ViewBuilder
    private var selectedRoomsBar: some View {
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
    private var normalControlBar: some View {
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
    private var editModeBar: some View {
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
    private var roomEditBar: some View {
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
    private var goToConfirmBar: some View {
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
    private var savePresetConfirmBar: some View {
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
    private var splitRoomBar: some View {
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

    private var editModeDescription: String {
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

    private var confirmButtonTitle: String {
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

    private var editModeColor: Color {
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

    private var canConfirmEditMode: Bool {
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

    // MARK: - Coordinate Transformation
    // Convert screen coordinates to map coordinates (accounting for zoom/pan)
    private func screenToMapCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        // Inverse of scaleEffect(scale).offset(offset)
        // Screen coord = (map coord * scale) + offset + center adjustment
        // Map coord = (screen coord - offset - center adjustment) / scale
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        let mapX = (point.x - offset.width - centerX) / scale + centerX
        let mapY = (point.y - offset.height - centerY) / scale + centerY

        return CGPoint(x: mapX, y: mapY)
    }

    private func mapToScreenCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        let screenX = (point.x - centerX) * scale + centerX + offset.width
        let screenY = (point.y - centerY) * scale + centerY + offset.height

        return CGPoint(x: screenX, y: screenY)
    }

    // MARK: - Drawing Overlay
    @ViewBuilder
    private func drawingOverlay(geometry: GeometryProxy) -> some View {
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
    private func splitLineHandles(geometry: GeometryProxy) -> some View {
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
    private func restrictionDeleteOverlay(params: MapParams, restrictions: VirtualRestrictions, viewSize: CGSize) -> some View {
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

    private func finishDrawing(in size: CGSize) {
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
        let pixelStartX = Int((start.x - params.offsetX) / params.scale)
        let pixelStartY = Int((start.y - params.offsetY) / params.scale)
        let pixelEndX = Int((end.x - params.offsetX) / params.scale)
        let pixelEndY = Int((end.y - params.offsetY) / params.scale)

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

    private func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    // MARK: - Gestures
    private var combinedGesture: some Gesture {
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
    @EnvironmentObject var robotManager: RobotManager
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

// MARK: - Interactive Map View
struct InteractiveMapView: View {
    let map: RobotMap
    let segments: [Segment]
    @Binding var selectedSegmentIds: Set<String>
    let viewSize: CGSize

    // Drawing overlays
    var drawnZones: [CleaningZone] = []
    var drawnNoGoAreas: [NoGoArea] = []
    var drawnNoMopAreas: [NoMopArea] = []
    var drawnVirtualWalls: [VirtualWall] = []
    var existingRestrictions: VirtualRestrictions?
    var currentDrawStart: CGPoint?
    var currentDrawEnd: CGPoint?
    var editMode: MapEditMode = .none
    var showRoomLabels: Bool = true

    // Soft pastel room colors
    private let segmentColors: [Color] = [
        Color(red: 0.65, green: 0.80, blue: 0.92),  // Soft sky blue
        Color(red: 0.70, green: 0.88, blue: 0.75),  // Soft mint green
        Color(red: 0.92, green: 0.78, blue: 0.72),  // Soft peach
        Color(red: 0.82, green: 0.75, blue: 0.90),  // Soft lavender
        Color(red: 0.90, green: 0.85, blue: 0.65),  // Soft gold
        Color(red: 0.70, green: 0.85, blue: 0.85),  // Soft teal
        Color(red: 0.90, green: 0.72, blue: 0.78),  // Soft rose
        Color(red: 0.78, green: 0.88, blue: 0.72),  // Soft sage
    ]

    var body: some View {
        Canvas { context, size in
            // Use default pixelSize of 5 if not provided
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else {
                // Draw "no data" indicator
                let text = Text("No map layers")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size)
            guard let p = params else {
                // Draw "calculation failed" indicator
                let text = Text("Map calculation failed")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            // Draw floor
            drawLayersDecompressed(context: context, layers: layers, type: "floor", color: Color(white: 0.92), params: p, pixelSize: pixelSize)

            // Draw segments
            for layer in layers where layer.type == "segment" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }

                let segmentId = layer.metaData?.segmentId
                let isSelected = segmentId.map { selectedSegmentIds.contains($0) } ?? false
                let baseColor = segmentColor(segmentId: segmentId)
                let color = isSelected ? baseColor.opacity(0.9) : baseColor.opacity(0.6)
                let material = layer.metaData?.material

                drawPixelsWithMaterial(context: context, pixels: pixels, color: color, material: material, params: p, pixelSize: pixelSize)

                // Draw selection border
                if isSelected {
                    drawSegmentBorder(context: context, pixels: pixels, params: p, pixelSize: pixelSize)
                }
            }

            // Draw walls (thinner)
            drawWalls(context: context, layers: layers, color: Color(white: 0.25), params: p, pixelSize: pixelSize)

            // Draw entities
            if let entities = map.entities {
                for entity in entities where entity.type == "path" || entity.type == "predicted_path" {
                    drawPath(context: context, entity: entity, params: p, pixelSize: pixelSize)
                }
                for entity in entities where entity.type == "charger_location" {
                    drawCharger(context: context, entity: entity, params: p, pixelSize: pixelSize)
                }
                for entity in entities where entity.type == "robot_position" {
                    drawRobot(context: context, entity: entity, params: p, pixelSize: pixelSize)
                }
            }

            // Draw existing restrictions (API coordinates are in mm, need to convert to pixels)
            if let restrictions = existingRestrictions {
                for wall in restrictions.virtualWalls {
                    drawVirtualWall(context: context, wall: wall, params: p, pixelSize: pixelSize, isNew: false)
                }
                for area in restrictions.restrictedZones {
                    drawRestrictedZone(context: context, area: area, params: p, pixelSize: pixelSize, color: .red.opacity(0.3), isNew: false)
                }
                for area in restrictions.noMopZones {
                    drawRestrictedZone(context: context, area: area, params: p, pixelSize: pixelSize, color: .blue.opacity(0.3), isNew: false)
                }
            }

            // Draw newly created zones/restrictions (these are already in API mm coords)
            for zone in drawnZones {
                drawCleaningZone(context: context, zone: zone, params: p, pixelSize: pixelSize)
            }
            for area in drawnNoGoAreas {
                drawRestrictedZone(context: context, area: area, params: p, pixelSize: pixelSize, color: .red.opacity(0.4), isNew: true)
            }
            for area in drawnNoMopAreas {
                drawRestrictedZone(context: context, area: area, params: p, pixelSize: pixelSize, color: .blue.opacity(0.4), isNew: true)
            }
            for wall in drawnVirtualWalls {
                drawVirtualWall(context: context, wall: wall, params: p, pixelSize: pixelSize, isNew: true)
            }

            // Draw current drawing preview (not for goTo/savePreset - those use SwiftUI overlay)
            if let start = currentDrawStart, let end = currentDrawEnd, editMode != .goTo && editMode != .savePreset {
                drawCurrentDrawing(context: context, start: start, end: end, mode: editMode, size: size)
            }
        }
        .overlay {
            // Tap targets and labels (only when visible)
            if showRoomLabels {
                tapTargetsOverlay
            }
        }
    }

    // MARK: - Tap Targets
    @ViewBuilder
    private var tapTargetsOverlay: some View {
        GeometryReader { geometry in
            let params = calculateMapParams(
                layers: map.layers ?? [],
                pixelSize: map.pixelSize ?? 5,
                size: geometry.size
            )

            if let p = params, let layers = map.layers {
                // Room labels only
                ForEach(segmentInfos(from: layers), id: \.id) { info in
                    let x = CGFloat(info.midX) * p.scale + p.offsetX
                    let y = CGFloat(info.midY) * p.scale + p.offsetY
                    let isSelected = selectedSegmentIds.contains(info.id)

                    Button {
                        toggleSegment(info.id)
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white, .blue)
                            }
                            Text(info.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                                ? Color.blue
                                : Color(.systemBackground).opacity(0.9)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y)
                }
            }
        }
    }

    private func toggleSegment(_ id: String) {
        if selectedSegmentIds.contains(id) {
            selectedSegmentIds.remove(id)
        } else {
            selectedSegmentIds.insert(id)
        }
    }

    // MARK: - Segment Info
    private struct SegmentInfo: Identifiable {
        let id: String
        let name: String
        let midX: Int
        let midY: Int
    }

    private func segmentInfos(from layers: [MapLayer]) -> [SegmentInfo] {
        var infos: [SegmentInfo] = []

        for layer in layers where layer.type == "segment" {
            guard let segmentId = layer.metaData?.segmentId else { continue }

            // Try to get mid point from dimensions first
            var midX: Int? = layer.dimensions?.x?.mid
            var midY: Int? = layer.dimensions?.y?.mid

            // If no dimensions, calculate from decompressed pixels
            if midX == nil || midY == nil {
                let pixels = layer.decompressedPixels
                if pixels.count >= 2 {
                    var sumX = 0, sumY = 0, count = 0
                    var i = 0
                    while i < pixels.count - 1 {
                        sumX += pixels[i]
                        sumY += pixels[i + 1]
                        count += 1
                        i += 2
                    }
                    if count > 0 {
                        midX = midX ?? (sumX / count)
                        midY = midY ?? (sumY / count)
                    }
                }
            }

            guard let finalMidX = midX, let finalMidY = midY else { continue }

            // Get name from segments array or use ID
            let name = segments.first { $0.id == segmentId }?.displayName
                ?? layer.metaData?.name
                ?? String(localized: "map.room") + " \(segmentId)"

            infos.append(SegmentInfo(id: segmentId, name: name, midX: finalMidX, midY: finalMidY))
        }

        return infos
    }

    // MARK: - Map Calculations
    private func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    // MARK: - Drawing Functions
    private func drawLayersDecompressed(context: GraphicsContext, layers: [MapLayer], type: String, color: Color, params: MapParams, pixelSize: Int) {
        for layer in layers where layer.type == type {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            drawPixels(context: context, pixels: pixels, color: color, params: params, pixelSize: pixelSize)
        }
    }

    private func drawWalls(context: GraphicsContext, layers: [MapLayer], color: Color, params: MapParams, pixelSize: Int) {
        // Draw walls as thin lines
        let normalScale = params.scale * CGFloat(pixelSize)
        let wallScale = normalScale * 0.2  // 20% - very thin
        for layer in layers where layer.type == "wall" {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                let x = CGFloat(pixels[i]) * params.scale + params.offsetX + normalScale * 0.4
                let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY + normalScale * 0.4
                let rect = CGRect(x: x, y: y, width: wallScale, height: wallScale)
                context.fill(Path(rect), with: .color(color))
                i += 2
            }
        }
    }

    private func drawPixels(context: GraphicsContext, pixels: [Int], color: Color, params: MapParams, pixelSize: Int) {
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)
            context.fill(Path(rect), with: .color(color))
            i += 2
        }
    }

    private func drawPixelsWithMaterial(context: GraphicsContext, pixels: [Int], color: Color, material: String?, params: MapParams, pixelSize: Int) {
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0

        // Determine texture pattern based on material
        let textureInterval: Int
        let isHorizontal: Bool
        let isVertical: Bool

        switch material {
        case "tile":
            textureInterval = 4  // Grid pattern every 4 pixels
            isHorizontal = true
            isVertical = true
        case "wood", "wood_horizontal":
            textureInterval = 3  // Horizontal lines every 3 pixels
            isHorizontal = true
            isVertical = false
        case "wood_vertical":
            textureInterval = 3  // Vertical lines every 3 pixels
            isHorizontal = false
            isVertical = true
        default:
            // Generic or unknown - just draw plain pixels
            textureInterval = 0
            isHorizontal = false
            isVertical = false
        }

        let accentColor = color.opacity(0.85)  // Slightly darker for texture lines

        while i < pixels.count - 1 {
            let px = pixels[i]
            let py = pixels[i + 1]
            let x = CGFloat(px) * params.scale + params.offsetX
            let y = CGFloat(py) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)

            // Check if this pixel should be accented for texture
            let shouldAccent: Bool
            if textureInterval > 0 {
                let hMatch = isHorizontal && (py % textureInterval == 0)
                let vMatch = isVertical && (px % textureInterval == 0)
                shouldAccent = hMatch || vMatch
            } else {
                shouldAccent = false
            }

            context.fill(Path(rect), with: .color(shouldAccent ? accentColor : color))
            i += 2
        }
    }

    private func drawSegmentBorder(context: GraphicsContext, pixels: [Int], params: MapParams, pixelSize: Int) {
        // Simple approach: draw a subtle glow around selected segments
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x - 1, y: y - 1, width: pixelScale + 2, height: pixelScale + 2)
            context.stroke(Path(rect), with: .color(.blue.opacity(0.3)), lineWidth: 0.5)
            i += 2
        }
    }

    private func segmentColor(segmentId: String?) -> Color {
        if let id = segmentId, let num = Int(id) {
            return segmentColors[num % segmentColors.count]
        }
        return segmentColors[0]
    }

    private func drawPath(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 4 else { return }
        let ps = CGFloat(pixelSize)

        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(points[0]) / ps * params.scale + params.offsetX,
            y: CGFloat(points[1]) / ps * params.scale + params.offsetY
        ))

        var i = 2
        while i < points.count - 1 {
            path.addLine(to: CGPoint(
                x: CGFloat(points[i]) / ps * params.scale + params.offsetX,
                y: CGFloat(points[i + 1]) / ps * params.scale + params.offsetY
            ))
            i += 2
        }

        let isPredicted = entity.type == "predicted_path"
        let color = isPredicted ? Color(white: 0.4).opacity(0.5) : Color(white: 0.35).opacity(0.8)
        let style = isPredicted ?
            StrokeStyle(lineWidth: 1, dash: [3, 2]) :
            StrokeStyle(lineWidth: 1)

        context.stroke(path, with: .color(color), style: style)
    }

    private func drawCharger(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 2 else { return }
        let ps = CGFloat(pixelSize)

        let x = CGFloat(points[0]) / ps * params.scale + params.offsetX
        let y = CGFloat(points[1]) / ps * params.scale + params.offsetY
        let size: CGFloat = 14

        // Glow
        let glowRect = CGRect(x: x - size/2 - 2, y: y - size/2 - 2, width: size + 4, height: size + 4)
        context.fill(RoundedRectangle(cornerRadius: 4).path(in: glowRect), with: .color(Color(white: 0.2).opacity(0.3)))

        // Base
        let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(RoundedRectangle(cornerRadius: 3).path(in: rect), with: .color(Color(white: 0.2)))

        // House shape for dock
        var house = Path()
        house.move(to: CGPoint(x: x, y: y - 4))
        house.addLine(to: CGPoint(x: x + 4, y: y))
        house.addLine(to: CGPoint(x: x + 2.5, y: y))
        house.addLine(to: CGPoint(x: x + 2.5, y: y + 3))
        house.addLine(to: CGPoint(x: x - 2.5, y: y + 3))
        house.addLine(to: CGPoint(x: x - 2.5, y: y))
        house.addLine(to: CGPoint(x: x - 4, y: y))
        house.closeSubpath()
        context.fill(house, with: .color(.white))
    }

    private func drawRobot(context: GraphicsContext, entity: MapEntity, params: MapParams, pixelSize: Int) {
        guard let points = entity.points, points.count >= 2 else { return }
        let ps = CGFloat(pixelSize)

        let x = CGFloat(points[0]) / ps * params.scale + params.offsetX
        let y = CGFloat(points[1]) / ps * params.scale + params.offsetY
        let size: CGFloat = 16

        // Glow effect
        let glowRect = CGRect(x: x - size/2 - 3, y: y - size/2 - 3, width: size + 6, height: size + 6)
        context.fill(Circle().path(in: glowRect), with: .color(Color(white: 0.2).opacity(0.3)))

        // Outer ring
        let outerRect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(Circle().path(in: outerRect), with: .color(Color(white: 0.2)))

        // Inner body
        let innerSize: CGFloat = 10
        let innerRect = CGRect(x: x - innerSize/2, y: y - innerSize/2, width: innerSize, height: innerSize)
        context.fill(Circle().path(in: innerRect), with: .color(Color(white: 0.3)))

        // Vacuum pattern (small circle)
        let dotSize: CGFloat = 4
        let dotRect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
        context.fill(Circle().path(in: dotRect), with: .color(.white))
    }

    // MARK: - Zone Drawing
    // Note: All API coordinates are in mm, need to divide by pixelSize to get pixel coordinates
    private func drawCleaningZone(context: GraphicsContext, zone: CleaningZone, params: MapParams, pixelSize: Int) {
        let p = zone.points
        let ps = CGFloat(pixelSize)
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) / ps * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(.orange.opacity(0.3)))
        context.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }

    private func drawRestrictedZone(context: GraphicsContext, area: NoGoArea, params: MapParams, pixelSize: Int, color: Color, isNew: Bool) {
        let p = area.points
        let ps = CGFloat(pixelSize)
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) / ps * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(color))
        let strokeColor: Color = color.opacity(1.0)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: isNew ? 2 : 1))
    }

    private func drawRestrictedZone(context: GraphicsContext, area: NoMopArea, params: MapParams, pixelSize: Int, color: Color, isNew: Bool) {
        let p = area.points
        let ps = CGFloat(pixelSize)
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) / ps * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(color))
        let strokeColor: Color = color.opacity(1.0)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: isNew ? 2 : 1))
    }

    private func drawVirtualWall(context: GraphicsContext, wall: VirtualWall, params: MapParams, pixelSize: Int, isNew: Bool) {
        let p = wall.points
        let ps = CGFloat(pixelSize)
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) / ps * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) / ps * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) / ps * params.scale + params.offsetY
        ))

        context.stroke(path, with: .color(.purple), style: StrokeStyle(lineWidth: isNew ? 4 : 3))
    }

    private func drawCurrentDrawing(context: GraphicsContext, start: CGPoint, end: CGPoint, mode: MapEditMode, size: CGSize) {
        let color: Color
        switch mode {
        case .zone: color = .orange
        case .noGoArea: color = .red
        case .noMopArea: color = .blue
        case .virtualWall: color = .purple
        case .goTo: color = .blue
        case .savePreset: color = .yellow
        case .splitRoom: color = .red
        case .roomEdit, .deleteRestriction, .none: return
        }

        if mode == .virtualWall || mode == .splitRoom {
            // Draw line with start and end markers
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 4))

            // Start point marker (larger, draggable indicator)
            let startSize: CGFloat = 16
            context.fill(Circle().path(in: CGRect(
                x: start.x - startSize/2,
                y: start.y - startSize/2,
                width: startSize,
                height: startSize
            )), with: .color(color))
            context.stroke(Circle().path(in: CGRect(
                x: start.x - startSize/2,
                y: start.y - startSize/2,
                width: startSize,
                height: startSize
            )), with: .color(.white), lineWidth: 2)

            // End point marker
            let endSize: CGFloat = 16
            context.fill(Circle().path(in: CGRect(
                x: end.x - endSize/2,
                y: end.y - endSize/2,
                width: endSize,
                height: endSize
            )), with: .color(color))
            context.stroke(Circle().path(in: CGRect(
                x: end.x - endSize/2,
                y: end.y - endSize/2,
                width: endSize,
                height: endSize
            )), with: .color(.white), lineWidth: 2)
        } else if mode == .goTo || mode == .savePreset {
            // Draw target marker
            let targetSize: CGFloat = 20
            context.fill(Circle().path(in: CGRect(
                x: start.x - targetSize/2,
                y: start.y - targetSize/2,
                width: targetSize,
                height: targetSize
            )), with: .color(color.opacity(0.5)))
            context.stroke(Circle().path(in: CGRect(
                x: start.x - targetSize/2,
                y: start.y - targetSize/2,
                width: targetSize,
                height: targetSize
            )), with: .color(color), lineWidth: 2)
        } else {
            // Draw rectangle
            let minX = min(start.x, end.x)
            let maxX = max(start.x, end.x)
            let minY = min(start.y, end.y)
            let maxY = max(start.y, end.y)
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            context.fill(Path(rect), with: .color(color.opacity(0.3)))
            context.stroke(Path(rect), with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
    }
}

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

#Preview {
    MapView(robot: RobotConfig(name: "Test", host: "192.168.0.35"))
        .environmentObject(RobotManager())
}
