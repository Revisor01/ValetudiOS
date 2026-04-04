import SwiftUI

// MARK: - Map Calculation Parameters
struct MapParams {
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let minX: Int
    let minY: Int
}

// MARK: - Map Parameter Calculation

/// Calculates scale and offset needed to fit all map layers into the given view size.
/// - Parameters:
///   - layers: All map layers (floor, walls, segments)
///   - pixelSize: Map pixel size from RobotMap.pixelSize (typically 5)
///   - size: Available view size in points
///   - padding: Padding around the map content (default 20; use 10 for mini-map)
/// - Returns: MapParams with scale and offsets, or nil if no pixel data found
func calculateMapParams(
    layers: [MapLayer],
    pixelSize: Int,
    size: CGSize,
    padding: CGFloat = 20
) -> MapParams? {
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
    let availableWidth = size.width - padding * 2
    let availableHeight = size.height - padding * 2
    let scaleX = availableWidth / contentWidth
    let scaleY = availableHeight / contentHeight
    let scale = min(scaleX, scaleY)
    let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
    let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

    return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
}

// MARK: - Coordinate Transforms

/// Converts a screen coordinate (accounting for pinch/pan gesture state) to map canvas coordinates.
func screenToMapCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint {
    let centerX = viewSize.width / 2
    let centerY = viewSize.height / 2
    let mapX = (point.x - offset.width - centerX) / scale + centerX
    let mapY = (point.y - offset.height - centerY) / scale + centerY
    return CGPoint(x: mapX, y: mapY)
}

/// Converts a map canvas coordinate to screen coordinates (accounting for pinch/pan gesture state).
func mapToScreenCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint {
    let centerX = viewSize.width / 2
    let centerY = viewSize.height / 2
    let screenX = (point.x - centerX) * scale + centerX + offset.width
    let screenY = (point.y - centerY) * scale + centerY + offset.height
    return CGPoint(x: screenX, y: screenY)
}
