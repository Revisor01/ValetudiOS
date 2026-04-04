import SwiftUI

// MARK: - Interactive Map View
struct InteractiveMapView: View {
    let map: RobotMap
    let segments: [Segment]
    @Binding var selectedSegmentIds: [String]
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
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    handleCanvasTap(at: value.location, size: viewSize)
                }
        )
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
            selectedSegmentIds.removeAll(where: { $0 == id })
        } else {
            selectedSegmentIds.append(id)
        }
    }

    // MARK: - Canvas Tap Hit-Testing
    private func handleCanvasTap(at location: CGPoint, size: CGSize) {
        guard editMode == .none || editMode == .roomEdit else { return }
        guard let layers = map.layers else { return }

        let pixelSize = map.pixelSize ?? 5
        guard let p = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

        // Reverse transform: Canvas coordinate -> pixel coordinate
        let pixelX = Int(((location.x - p.offsetX) / p.scale).rounded())
        let pixelY = Int(((location.y - p.offsetY) / p.scale).rounded())

        // Segment lookup: first layer wins on overlap (per user decision)
        for layer in layers where layer.type == "segment" {
            let pixels = layer.decompressedPixels
            var i = 0
            while i < pixels.count - 1 {
                if pixels[i] == pixelX && pixels[i + 1] == pixelY {
                    if let segmentId = layer.metaData?.segmentId {
                        toggleSegment(segmentId)
                    }
                    return
                }
                i += 2
            }
        }
        // No hit — no toggle, no unintended state change
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
