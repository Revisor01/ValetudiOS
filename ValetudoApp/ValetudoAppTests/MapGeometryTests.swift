import XCTest
@testable import ValetudoApp

final class MapGeometryTests: XCTestCase {

    // MARK: - Helpers

    private func makeLayer(pixels: [Int]) -> MapLayer {
        let json = #"{"pixels": \#(pixels)}"#
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(MapLayer.self, from: data)
    }

    // MARK: - calculateMapParams

    func testCalculateMapParamsReturnsNilForEmptyLayers() {
        let result = calculateMapParams(layers: [], pixelSize: 5, size: CGSize(width: 400, height: 400))
        XCTAssertNil(result)
    }

    func testCalculateMapParamsReturnsNilForLayersWithNoPixels() {
        let layer = makeLayer(pixels: [])
        let result = calculateMapParams(layers: [layer], pixelSize: 5, size: CGSize(width: 400, height: 400))
        XCTAssertNil(result)
    }

    func testCalculateMapParamsSinglePixel() {
        // Single pixel at (10, 20)
        let layer = makeLayer(pixels: [10, 20])
        let size = CGSize(width: 400, height: 400)
        let result = calculateMapParams(layers: [layer], pixelSize: 5, size: size)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.minX, 10)
        XCTAssertEqual(result?.minY, 20)
    }

    func testCalculateMapParamsScaleIsPositive() {
        let layer = makeLayer(pixels: [0, 0, 100, 100])
        let result = calculateMapParams(layers: [layer], pixelSize: 5, size: CGSize(width: 400, height: 400))
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.scale, 0)
    }

    func testCalculateMapParamsWithPadding() {
        // 2x2 map (pixels at 0,0 and 10,10), should fit into 400x400 with padding
        let layer = makeLayer(pixels: [0, 0, 10, 10])
        let size = CGSize(width: 400, height: 400)
        let resultDefault = calculateMapParams(layers: [layer], pixelSize: 5, size: size, padding: 20)
        let resultNoPadding = calculateMapParams(layers: [layer], pixelSize: 5, size: size, padding: 0)
        XCTAssertNotNil(resultDefault)
        XCTAssertNotNil(resultNoPadding)
        // With padding, the scale must be smaller (less available space)
        XCTAssertLessThan(resultDefault!.scale, resultNoPadding!.scale)
    }

    func testCalculateMapParamsMinXMinYCorrect() {
        // Pixels at (5,3), (15,7), (10,1)
        let layer = makeLayer(pixels: [5, 3, 15, 7, 10, 1])
        let result = calculateMapParams(layers: [layer], pixelSize: 5, size: CGSize(width: 400, height: 400))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.minX, 5)
        XCTAssertEqual(result?.minY, 1)
    }

    func testCalculateMapParamsNonSquareViewUsesMinScale() {
        // Map is 100x100, view is 200x400 — should use scaleX (smaller axis)
        let layer = makeLayer(pixels: [0, 0, 100, 100])
        let size = CGSize(width: 200, height: 400)
        let result = calculateMapParams(layers: [layer], pixelSize: 5, size: size, padding: 0)
        XCTAssertNotNil(result)
        // Scale should be limited by the narrower axis (width=200)
        let expectedScale = 200.0 / CGFloat(100 + 5)  // (maxX-minX+pixelSize) = 105
        XCTAssertEqual(result!.scale, expectedScale, accuracy: 0.001)
    }

    func testCalculateMapParamsMultipleLayers() {
        // First layer has pixels at (0, 0), second at (100, 100)
        let layer1 = makeLayer(pixels: [0, 0])
        let layer2 = makeLayer(pixels: [100, 100])
        let result = calculateMapParams(layers: [layer1, layer2], pixelSize: 5, size: CGSize(width: 400, height: 400))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.minX, 0)
        XCTAssertEqual(result?.minY, 0)
        // maxX = 100, maxY = 100, so content = 105x105
        let expectedScale = (400.0 - 40) / 105.0  // (400 - 2*20) / 105
        XCTAssertEqual(result!.scale, expectedScale, accuracy: 0.001)
    }

    // MARK: - screenToMapCoords

    func testScreenToMapCoordsIdentityAtCenter() {
        // When scale=1, offset=.zero, a point at view center maps to itself
        let viewSize = CGSize(width: 400, height: 400)
        let center = CGPoint(x: 200, y: 200)
        let result = screenToMapCoords(center, scale: 1.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 200, accuracy: 0.001)
        XCTAssertEqual(result.y, 200, accuracy: 0.001)
    }

    func testScreenToMapCoordsZeroOffset() {
        // With no offset and scale=1, any point should map to itself
        let viewSize = CGSize(width: 400, height: 400)
        let point = CGPoint(x: 100, y: 150)
        let result = screenToMapCoords(point, scale: 1.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 100, accuracy: 0.001)
        XCTAssertEqual(result.y, 150, accuracy: 0.001)
    }

    func testScreenToMapCoordsWithScale2() {
        // Scale=2, offset=.zero, viewSize=400x400
        // A point at (300, 300): mapX = (300 - 0 - 200) / 2 + 200 = 100/2 + 200 = 250
        let viewSize = CGSize(width: 400, height: 400)
        let point = CGPoint(x: 300, y: 300)
        let result = screenToMapCoords(point, scale: 2.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 250, accuracy: 0.001)
        XCTAssertEqual(result.y, 250, accuracy: 0.001)
    }

    func testScreenToMapCoordsWithOffset() {
        // Scale=1, offset=CGSize(50, 50), viewSize=400x400
        // point=(100, 100): mapX = (100 - 50 - 200) / 1 + 200 = -150 + 200 = 50
        let viewSize = CGSize(width: 400, height: 400)
        let offset = CGSize(width: 50, height: 50)
        let point = CGPoint(x: 100, y: 100)
        let result = screenToMapCoords(point, scale: 1.0, offset: offset, viewSize: viewSize)
        XCTAssertEqual(result.x, 50, accuracy: 0.001)
        XCTAssertEqual(result.y, 50, accuracy: 0.001)
    }

    // MARK: - mapToScreenCoords

    func testMapToScreenCoordsIdentityAtCenter() {
        // Scale=1, offset=.zero, center maps to itself
        let viewSize = CGSize(width: 400, height: 400)
        let center = CGPoint(x: 200, y: 200)
        let result = mapToScreenCoords(center, scale: 1.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 200, accuracy: 0.001)
        XCTAssertEqual(result.y, 200, accuracy: 0.001)
    }

    func testMapToScreenCoordsZeroOffset() {
        // Scale=1, no offset — identity transform
        let viewSize = CGSize(width: 400, height: 400)
        let point = CGPoint(x: 100, y: 150)
        let result = mapToScreenCoords(point, scale: 1.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 100, accuracy: 0.001)
        XCTAssertEqual(result.y, 150, accuracy: 0.001)
    }

    func testMapToScreenCoordsWithScale2() {
        // Scale=2, offset=.zero, viewSize=400x400
        // point=(250, 250): screenX = (250 - 200) * 2 + 200 + 0 = 100 + 200 = 300
        let viewSize = CGSize(width: 400, height: 400)
        let point = CGPoint(x: 250, y: 250)
        let result = mapToScreenCoords(point, scale: 2.0, offset: .zero, viewSize: viewSize)
        XCTAssertEqual(result.x, 300, accuracy: 0.001)
        XCTAssertEqual(result.y, 300, accuracy: 0.001)
    }

    func testMapToScreenCoordsWithOffset() {
        // Scale=1, offset=CGSize(50, 50), viewSize=400x400
        // point=(50, 50): screenX = (50 - 200) * 1 + 200 + 50 = -150 + 250 = 100
        let viewSize = CGSize(width: 400, height: 400)
        let offset = CGSize(width: 50, height: 50)
        let point = CGPoint(x: 50, y: 50)
        let result = mapToScreenCoords(point, scale: 1.0, offset: offset, viewSize: viewSize)
        XCTAssertEqual(result.x, 100, accuracy: 0.001)
        XCTAssertEqual(result.y, 100, accuracy: 0.001)
    }

    // MARK: - Roundtrip Tests

    func testScreenToMapAndBackIsIdentity() {
        // screenToMapCoords and mapToScreenCoords must be inverse of each other
        let viewSize = CGSize(width: 400, height: 400)
        let scale = 1.5
        let offset = CGSize(width: 30, height: -20)
        let original = CGPoint(x: 150, y: 250)

        let mapCoords = screenToMapCoords(original, scale: scale, offset: offset, viewSize: viewSize)
        let backToScreen = mapToScreenCoords(mapCoords, scale: scale, offset: offset, viewSize: viewSize)

        XCTAssertEqual(backToScreen.x, original.x, accuracy: 0.001)
        XCTAssertEqual(backToScreen.y, original.y, accuracy: 0.001)
    }

    func testMapToScreenAndBackIsIdentity() {
        // mapToScreenCoords and screenToMapCoords must be inverse of each other
        let viewSize = CGSize(width: 600, height: 800)
        let scale = 2.5
        let offset = CGSize(width: -10, height: 40)
        let original = CGPoint(x: 320, y: 180)

        let screenCoords = mapToScreenCoords(original, scale: scale, offset: offset, viewSize: viewSize)
        let backToMap = screenToMapCoords(screenCoords, scale: scale, offset: offset, viewSize: viewSize)

        XCTAssertEqual(backToMap.x, original.x, accuracy: 0.001)
        XCTAssertEqual(backToMap.y, original.y, accuracy: 0.001)
    }
}
