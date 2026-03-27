import XCTest
@testable import ValetudoApp

final class MapLayerTests: XCTestCase {

    // MARK: - Helpers

    private func makeLayer(json: String) throws -> MapLayer {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(MapLayer.self, from: data)
    }

    // MARK: - decompressedPixels

    func testDecompressEmptyCompressedPixels() throws {
        let layer = try makeLayer(json: #"{"compressedPixels": []}"#)
        XCTAssertEqual(layer.decompressedPixels, [])
    }

    func testDecompressSingleRun() throws {
        // [5, 10, 3] means: starting at (5, 10), draw 3 horizontal pixels
        // => (5,10), (6,10), (7,10) = [5, 10, 6, 10, 7, 10]
        let layer = try makeLayer(json: #"{"compressedPixels": [5, 10, 3]}"#)
        XCTAssertEqual(layer.decompressedPixels, [5, 10, 6, 10, 7, 10])
    }

    func testDecompressMultipleRuns() throws {
        // [0, 0, 2, 10, 5, 1]
        // Run 1: (0,0) count=2 => (0,0),(1,0) = [0,0,1,0]
        // Run 2: (10,5) count=1 => (10,5) = [10,5]
        let layer = try makeLayer(json: #"{"compressedPixels": [0, 0, 2, 10, 5, 1]}"#)
        XCTAssertEqual(layer.decompressedPixels, [0, 0, 1, 0, 10, 5])
    }

    func testPlainPixelsUsedWhenAvailable() throws {
        // When pixels is set, it takes priority over compressedPixels
        let layer = try makeLayer(json: #"{"pixels": [1, 2, 3, 4], "compressedPixels": [99, 99, 1]}"#)
        XCTAssertEqual(layer.decompressedPixels, [1, 2, 3, 4])
    }

    func testDecompressNilCompressedPixels() throws {
        // No compressedPixels and no pixels: should return []
        let layer = try makeLayer(json: #"{}"#)
        XCTAssertEqual(layer.decompressedPixels, [])
    }

    func testDecompressSinglePixel() throws {
        // [3, 7, 1] => (3,7) = [3, 7]
        let layer = try makeLayer(json: #"{"compressedPixels": [3, 7, 1]}"#)
        XCTAssertEqual(layer.decompressedPixels, [3, 7])
    }
}
