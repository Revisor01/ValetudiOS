import XCTest
@testable import ValetudoApp

final class MapCacheServiceTests: XCTestCase {

    // Use unique robot IDs per test to avoid cross-test contamination
    private var robotId: UUID!
    private let service = MapCacheService.shared

    override func setUp() async throws {
        try await super.setUp()
        robotId = UUID()
    }

    override func tearDown() async throws {
        // Clean up cache files written during this test
        service.deleteCache(for: robotId)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeMinimalMap() -> RobotMap {
        RobotMap(
            size: MapSize(x: 100, y: 100),
            pixelSize: 5,
            layers: [],
            entities: []
        )
    }

    private func makeMapWithLayer() -> RobotMap {
        let layer = try! JSONDecoder().decode(
            MapLayer.self,
            from: #"{"type": "floor", "pixels": [0, 0, 10, 0, 20, 0]}"#.data(using: .utf8)!
        )
        return RobotMap(
            size: MapSize(x: 200, y: 200),
            pixelSize: 5,
            layers: [layer],
            entities: []
        )
    }

    // MARK: - Load Returns Nil When No Cache

    func testLoadReturnsNilWhenNoCacheExists() async {
        let result = await service.load(for: robotId)
        XCTAssertNil(result, "Should return nil when no cache file exists for robot")
    }

    func testLoadReturnsNilForFreshUUID() async {
        // Any new UUID should have no cached data
        let freshId = UUID()
        defer { service.deleteCache(for: freshId) }
        let result = await service.load(for: freshId)
        XCTAssertNil(result)
    }

    // MARK: - Save and Load Roundtrip

    func testSaveAndLoadRoundtrip() async {
        let map = makeMinimalMap()
        await service.save(map, for: robotId)
        let loaded = await service.load(for: robotId)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.size?.x, map.size?.x)
        XCTAssertEqual(loaded?.size?.y, map.size?.y)
        XCTAssertEqual(loaded?.pixelSize, map.pixelSize)
    }

    func testSaveAndLoadPreservesLayers() async {
        let map = makeMapWithLayer()
        await service.save(map, for: robotId)
        let loaded = await service.load(for: robotId)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.layers?.count, 1)
        XCTAssertEqual(loaded?.layers?.first?.type, "floor")
    }

    func testSaveAndLoadPreservesPixelData() async {
        let map = makeMapWithLayer()
        await service.save(map, for: robotId)
        let loaded = await service.load(for: robotId)

        let originalPixels = map.layers?.first?.pixels
        let loadedPixels = loaded?.layers?.first?.pixels
        XCTAssertEqual(loadedPixels, originalPixels)
    }

    func testSaveAndLoadPreservesNilEntities() async {
        let map = RobotMap(size: nil, pixelSize: nil, layers: nil, entities: nil)
        await service.save(map, for: robotId)
        let loaded = await service.load(for: robotId)

        XCTAssertNotNil(loaded)
        XCTAssertNil(loaded?.size)
        XCTAssertNil(loaded?.pixelSize)
        XCTAssertNil(loaded?.layers)
        XCTAssertNil(loaded?.entities)
    }

    // MARK: - Overwrite Existing Cache

    func testSaveOverwritesPreviousCache() async {
        // Save first version
        let map1 = RobotMap(size: MapSize(x: 100, y: 100), pixelSize: 5, layers: [], entities: [])
        await service.save(map1, for: robotId)

        // Overwrite with second version
        let map2 = RobotMap(size: MapSize(x: 500, y: 500), pixelSize: 10, layers: [], entities: [])
        await service.save(map2, for: robotId)

        let loaded = await service.load(for: robotId)
        XCTAssertEqual(loaded?.size?.x, 500)
        XCTAssertEqual(loaded?.size?.y, 500)
        XCTAssertEqual(loaded?.pixelSize, 10)
    }

    // MARK: - Delete Cache

    func testDeleteCacheRemovesFile() async {
        let map = makeMinimalMap()
        await service.save(map, for: robotId)

        // Verify it exists
        let beforeDelete = await service.load(for: robotId)
        XCTAssertNotNil(beforeDelete)

        // Delete and verify it's gone
        service.deleteCache(for: robotId)
        let afterDelete = await service.load(for: robotId)
        XCTAssertNil(afterDelete)
    }

    func testDeleteNonexistentCacheDoesNotCrash() {
        // Should not throw or crash
        let unknownId = UUID()
        service.deleteCache(for: unknownId)
    }

    func testDeleteTwiceDoesNotCrash() async {
        let map = makeMinimalMap()
        await service.save(map, for: robotId)
        service.deleteCache(for: robotId)
        // Second delete on already-removed file should not crash
        service.deleteCache(for: robotId)
    }

    // MARK: - Corrupted Cache

    func testLoadReturnsNilForCorruptedCache() async throws {
        // Write corrupted (non-JSON) data to the cache location
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cacheDir = docs.appendingPathComponent("MapCache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cacheFile = cacheDir.appendingPathComponent("\(robotId.uuidString).json")
        let corruptData = "THIS IS NOT VALID JSON {{{".data(using: .utf8)!
        try corruptData.write(to: cacheFile, options: .atomic)

        let result = await service.load(for: robotId)
        XCTAssertNil(result, "Corrupted cache should return nil, not crash")
    }

    func testLoadReturnsNilForEmptyFile() async throws {
        // Write an empty file to the cache location
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cacheDir = docs.appendingPathComponent("MapCache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cacheFile = cacheDir.appendingPathComponent("\(robotId.uuidString).json")
        try Data().write(to: cacheFile, options: .atomic)

        let result = await service.load(for: robotId)
        XCTAssertNil(result, "Empty cache file should return nil, not crash")
    }

    func testLoadReturnsNilForWrongTypeJSON() async throws {
        // Write valid JSON but wrong type (e.g., an array instead of an object)
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cacheDir = docs.appendingPathComponent("MapCache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cacheFile = cacheDir.appendingPathComponent("\(robotId.uuidString).json")
        let wrongTypeData = "[1, 2, 3]".data(using: .utf8)!
        try wrongTypeData.write(to: cacheFile, options: .atomic)

        let result = await service.load(for: robotId)
        XCTAssertNil(result, "Wrong JSON type should return nil, not crash")
    }

    // MARK: - Multiple Robots Isolation

    func testCachesAreIsolatedByRobotId() async {
        let robotId2 = UUID()
        defer { service.deleteCache(for: robotId2) }

        let map1 = RobotMap(size: MapSize(x: 100, y: 100), pixelSize: 5, layers: [], entities: [])
        let map2 = RobotMap(size: MapSize(x: 999, y: 999), pixelSize: 1, layers: [], entities: [])

        await service.save(map1, for: robotId)
        await service.save(map2, for: robotId2)

        let loaded1 = await service.load(for: robotId)
        let loaded2 = await service.load(for: robotId2)

        XCTAssertEqual(loaded1?.size?.x, 100)
        XCTAssertEqual(loaded2?.size?.x, 999)
    }
}
