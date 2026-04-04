import SwiftUI

// MARK: - Mini Map View (simplified, no interaction)
struct MiniMapView: View {
    let map: RobotMap
    let viewSize: CGSize
    var restrictions: VirtualRestrictions?

    var body: some View {
        Canvas { context, size in
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else { return }

            guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size, padding: 10) else { return }

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
