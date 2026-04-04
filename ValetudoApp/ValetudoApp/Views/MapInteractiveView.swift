import SwiftUI
import UIKit

// MARK: - Interactive Map View
struct InteractiveMapView: View {
    let map: RobotMap
    let segments: [Segment]
    @Binding var selectedSegmentIds: [String]
    let viewSize: CGSize
    var staticLayerImage: CGImage?

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
    var segmentPixelSets: [String: Set<Int>] = [:]
    var cachedSegmentInfos: [SegmentInfo] = []

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
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else {
                let text = Text("No map layers")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size)
            guard let p = params else {
                let text = Text("Map calculation failed")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            // STATIC: Pre-rendered floor + segments + walls
            if let img = staticLayerImage {
                context.draw(
                    Image(decorative: img, scale: UIScreen.main.scale),
                    in: CGRect(origin: .zero, size: size)
                )
            } else {
                // Fallback: pixel-by-pixel when CGImage not yet ready
                drawLayersDecompressed(context: context, layers: layers, type: "floor", color: Color(white: 0.92), params: p, pixelSize: pixelSize)
                for layer in layers where layer.type == "segment" {
                    let pixels = layer.decompressedPixels
                    guard !pixels.isEmpty else { continue }
                    let segmentId = layer.metaData?.segmentId
                    let baseColor = segmentColor(segmentId: segmentId)
                    let color = baseColor.opacity(0.6)
                    let material = layer.metaData?.material
                    drawPixelsWithMaterial(context: context, pixels: pixels, color: color, material: material, params: p, pixelSize: pixelSize)
                }
                drawWalls(context: context, layers: layers, color: Color(white: 0.25), params: p, pixelSize: pixelSize)
            }

            // DYNAMIC: Selection borders (only for selected segments, drawn over static image)
            for layer in layers where layer.type == "segment" {
                let segmentId = layer.metaData?.segmentId
                let isSelected = segmentId.map { selectedSegmentIds.contains($0) } ?? false
                if isSelected {
                    let pixels = layer.decompressedPixels
                    guard !pixels.isEmpty else { continue }

                    let baseColor = segmentColor(segmentId: segmentId)
                    let selectedColor = baseColor.opacity(0.9)
                    drawPixels(context: context, pixels: pixels, color: selectedColor, params: p, pixelSize: pixelSize)
                    drawSegmentBorder(context: context, pixels: pixels, params: p, pixelSize: pixelSize)
                }
            }

            // DYNAMIC: Entities (path, charger, robot)
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

            // DYNAMIC: Existing restrictions
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

            // DYNAMIC: New zones/restrictions + drawing preview
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
        .overlay {
            orderBadgesOverlay
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

            if let p = params {
                // Room labels only
                ForEach(cachedSegmentInfos, id: \.id) { info in
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

    // MARK: - Order Badges
    @ViewBuilder
    private var orderBadgesOverlay: some View {
        if editMode == .none, !selectedSegmentIds.isEmpty {
            GeometryReader { geometry in
                let params = calculateMapParams(
                    layers: map.layers ?? [],
                    pixelSize: map.pixelSize ?? 5,
                    size: geometry.size
                )

                if let p = params {
                    ForEach(Array(selectedSegmentIds.enumerated()), id: \.element) { index, segmentId in
                        if let info = cachedSegmentInfos.first(where: { $0.id == segmentId }) {
                            let x = CGFloat(info.midX) * p.scale + p.offsetX
                            let y = CGFloat(info.midY) * p.scale + p.offsetY

                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .position(x: x, y: y - 20)
                        }
                    }
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

        let pixelX = Int(((location.x - p.offsetX) / p.scale).rounded())
        let pixelY = Int(((location.y - p.offsetY) / p.scale).rounded())

        // O(1) lookup per segment statt linearem Pixel-Scan
        let key = pixelX &<< 16 | pixelY
        for (segmentId, pixelSet) in segmentPixelSets {
            if pixelSet.contains(key) {
                toggleSegment(segmentId)
                return
            }
        }
        // No hit — no toggle, no unintended state change
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
