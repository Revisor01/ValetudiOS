import Foundation

struct RobotMap: Codable {
    let size: MapSize?
    let pixelSize: Int?
    let layers: [MapLayer]?
    let entities: [MapEntity]?
}

struct MapSize: Codable {
    let x: Int
    let y: Int
}

/// Cache class for MapLayer pixel decompression.
/// Using a class (reference type) allows caching on structs passed as `let` in SwiftUI Canvas closures,
/// where `lazy var` (mutating) would not compile.
final class MapLayerCache {
    private var cachedPixels: [Int]?

    func decompressedPixels(from layer: MapLayer) -> [Int] {
        if let cached = cachedPixels { return cached }
        let result = layer.computeDecompressedPixels()
        cachedPixels = result
        return result
    }

    func invalidate() { cachedPixels = nil }
}

struct MapLayer: Codable {
    let `__class`: String?
    let type: String?
    let pixels: [Int]?
    let compressedPixels: [Int]?
    let metaData: LayerMetaData?
    let dimensions: LayerDimensions?
    let cache = MapLayerCache()

    enum CodingKeys: String, CodingKey {
        case `__class`, type, pixels, compressedPixels, metaData, dimensions
    }

    /// Returns decompressed pixels - cached via MapLayerCache to avoid recomputation per frame.
    /// Cache is naturally invalidated when new map data arrives (new MapLayer instances = fresh cache).
    var decompressedPixels: [Int] {
        cache.decompressedPixels(from: self)
    }

    /// Computes decompressed pixels from raw data. Called only by MapLayerCache on first access.
    /// Valetudo uses run-length encoding: [x1, y1, count1, x2, y2, count2, ...]
    /// Each entry means: starting at (x,y), draw 'count' pixels horizontally.
    fileprivate func computeDecompressedPixels() -> [Int] {
        // If regular pixels exist, use them
        if let pixels = pixels, !pixels.isEmpty {
            return pixels
        }

        // Otherwise decompress
        guard let compressed = compressedPixels, !compressed.isEmpty else {
            return []
        }

        var result: [Int] = []
        var i = 0

        while i < compressed.count - 2 {
            let x = compressed[i]
            let y = compressed[i + 1]
            let count = compressed[i + 2]

            // Generate pixels for this run
            for offset in 0..<count {
                result.append(x + offset)
                result.append(y)
            }

            i += 3
        }

        return result
    }
}

struct LayerMetaData: Codable {
    let segmentId: String?
    let name: String?
    let active: Bool?
    let material: String?  // Floor material: generic, tile, wood, wood_horizontal, wood_vertical
}

// MARK: - Floor Material Types
enum FloorMaterial: String, CaseIterable, Codable {
    case generic = "generic"
    case tile = "tile"
    case wood = "wood"
    case woodHorizontal = "wood_horizontal"
    case woodVertical = "wood_vertical"

    var displayName: String {
        switch self {
        case .generic: return String(localized: "material.generic")
        case .tile: return String(localized: "material.tile")
        case .wood: return String(localized: "material.wood")
        case .woodHorizontal: return String(localized: "material.wood_horizontal")
        case .woodVertical: return String(localized: "material.wood_vertical")
        }
    }

    var icon: String {
        switch self {
        case .generic: return "square.fill"
        case .tile: return "square.grid.2x2.fill"
        case .wood: return "line.3.horizontal"
        case .woodHorizontal: return "line.3.horizontal"
        case .woodVertical: return "line.3.horizontal"
        }
    }
}

struct LayerDimensions: Codable {
    let x: DimensionRange?
    let y: DimensionRange?
}

struct DimensionRange: Codable {
    let min: Int?
    let max: Int?
    let mid: Int?
}

struct MapEntity: Codable {
    let `__class`: String?
    let type: String?
    let points: [Int]?
    let metaData: EntityMetaData?

    enum CodingKeys: String, CodingKey {
        case `__class`, type, points, metaData
    }
}

struct EntityMetaData: Codable {
    let angle: Int?
}

// MARK: - Map Layer Types
enum MapLayerType: String {
    case floor, wall, segment
}

// MARK: - Map Entity Types
enum MapEntityType: String {
    case robotPosition = "robot_position"
    case chargerLocation = "charger_location"
    case path
    case predictedPath = "predicted_path"
    case virtualWall = "virtual_wall"
    case noGoArea = "no_go_area"
    case noMopArea = "no_mop_area"
    case goToTarget = "go_to_target"
    case activeZone = "active_zone"
}
