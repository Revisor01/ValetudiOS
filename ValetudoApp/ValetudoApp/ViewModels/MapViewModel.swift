import SwiftUI
import Foundation
import UIKit
import os
import Observation

// MARK: - SegmentInfo

struct SegmentInfo: Identifiable {
    let id: String
    let name: String
    let midX: Int
    let midY: Int
}

// MARK: - MapViewModel

@MainActor
@Observable
final class MapViewModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MapViewModel")
    // MARK: - Configuration
    let robot: RobotConfig
    private let robotManager: RobotManager
    let isFullscreen: Bool

    // MARK: - Map Data State
    var map: RobotMap?
    var segments: [Segment] = []
    var isLoading = true
    var mapRefreshId = UUID()
    var loadError: String?

    // MARK: - Cached Computations (PERF-01, PERF-03)
    @ObservationIgnored var segmentPixelSets: [String: Set<Int>] = [:]
    var cachedSegmentInfos: [SegmentInfo] = []

    // MARK: - Static Layer Pre-rendering (PERF-04)
    var staticLayerImage: CGImage?
    @ObservationIgnored private var lastRenderSize: CGSize = .zero

    // MARK: - Capabilities
    var hasZoneCleaning = false
    var hasVirtualRestrictions = false
    var hasGoTo = false
    var hasSegmentRename = false
    var hasSegmentEdit = false

    // MARK: - Edit Mode State
    var editMode: MapEditMode = .none
    var drawnZones: [CleaningZone] = []
    var drawnNoGoAreas: [NoGoArea] = []
    var drawnNoMopAreas: [NoMopArea] = []
    var drawnVirtualWalls: [VirtualWall] = []

    // MARK: - Existing Restrictions
    var existingRestrictions: VirtualRestrictions?
    var restrictionToDelete: RestrictionIdentifier?

    // MARK: - Room Editing State
    var showRenameSheet = false
    var renameSegmentId: String?
    var renameNewName = ""
    var splitSegmentId: String?
    var selectedSegmentIds: [String] = [] {
        didSet { robotManager.roomSelections[robot.id] = selectedSegmentIds }
    }

    // MARK: - GoTo State
    var goToMarkerPosition: CGPoint?
    var goToApiCoords: (x: Int, y: Int)?
    var showGoToConfirm = false

    // MARK: - GoTo Presets
    var presetStore = GoToPresetStore()
    var showSavePresetSheet = false
    var pendingGoToX: Int?
    var pendingGoToY: Int?
    var newPresetName = ""
    var showPresetsSheet = false
    var showPresetsOnMap = false
    var editingPreset: GoToPreset?

    // MARK: - Cleaning State
    var isCleaning = false
    var selectedIterations: Int = 1 {
        didSet { robotManager.iterationSelections[robot.id] = selectedIterations }
    }

    // MARK: - UI State
    var showRoomLabels: Bool = true

    // MARK: - Error State
    var errorMessage: String? = nil

    // MARK: - ErrorRouter
    var errorRouter: ErrorRouter?

    // MARK: - Offline State
    var isOffline: Bool = false

    // MARK: - Task Management
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    // MARK: - Init
    init(robot: RobotConfig, robotManager: RobotManager, isFullscreen: Bool) {
        self.robot = robot
        self.robotManager = robotManager
        self.isFullscreen = isFullscreen
        self.selectedSegmentIds = robotManager.selectedRooms(for: robot.id)
        self.selectedIterations = robotManager.selectedIterationCount(for: robot.id)
    }

    // MARK: - Data Loading
    func loadMap() async {
        guard let api = api else {
            loadError = "No API available"
            isLoading = false
            return
        }

        if map == nil { isLoading = true }

        do {
            let capabilities = try await api.getCapabilities()
            hasZoneCleaning = capabilities.contains("ZoneCleaningCapability")
            hasVirtualRestrictions = capabilities.contains("CombinedVirtualRestrictionsCapability")
            hasGoTo = capabilities.contains("GoToLocationCapability")
            hasSegmentRename = capabilities.contains("MapSegmentRenameCapability")
            hasSegmentEdit = capabilities.contains("MapSegmentEditCapability")
        } catch {
            logger.warning("loadMap: Capability check failed: \(error.localizedDescription, privacy: .public)")
        }

        if hasVirtualRestrictions {
            do {
                let restrictions = try await api.getVirtualRestrictions()
                existingRestrictions = restrictions
            } catch {
                logger.error("Virtual restrictions failed: \(error, privacy: .public)")
            }
        }

        do {
            let loadedMap = try await api.getMap()
            var loadedSegments: [Segment] = []
            do {
                loadedSegments = try await api.getSegments()
            } catch {
                logger.error("Segments failed: \(error, privacy: .public)")
            }

            map = loadedMap
            segments = loadedSegments
            rebuildSegmentPixelSets()
            updateCachedSegmentInfos()
            if lastRenderSize.width > 0 {
                rebuildStaticLayerImage(size: lastRenderSize)
            }
            loadError = nil
            isOffline = false
            isLoading = false
            await MapCacheService.shared.save(loadedMap, for: robot.id)
        } catch {
            // Kein erfolgreicher Load — Cache laden falls vorhanden
            if let cachedMap = await MapCacheService.shared.load(for: robot.id), self.map == nil {
                self.map = cachedMap
                self.isOffline = true
                self.loadError = nil
            } else {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }

    func startMapRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            guard let api = self.api else { return }

            var retryCount = 0

            while !Task.isCancelled {
                do {
                    let bytes = try await api.streamMapLines()
                    retryCount = 0
                    logger.info("Map SSE connected for \(self.robot.id, privacy: .public)")

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard !jsonString.isEmpty,
                              let jsonData = jsonString.data(using: .utf8) else { continue }

                        do {
                            let newMap = try JSONDecoder().decode(RobotMap.self, from: jsonData)
                            self.map = newMap
                            self.rebuildSegmentPixelSets()
                            self.updateCachedSegmentInfos()
                            if self.lastRenderSize.width > 0 {
                                self.rebuildStaticLayerImage(size: self.lastRenderSize)
                            }
                            self.isOffline = false
                            await MapCacheService.shared.saveIfChanged(newMap, for: self.robot.id)
                        } catch {
                            // SSE event war kein vollstaendiges RobotMap — fallback: einzelner HTTP-GET
                            logger.warning("Map SSE decode failed, falling back to HTTP GET: \(error.localizedDescription, privacy: .public)")
                            if let fallbackMap = try? await api.getMap() {
                                self.map = fallbackMap
                                self.rebuildSegmentPixelSets()
                                self.updateCachedSegmentInfos()
                                if self.lastRenderSize.width > 0 {
                                    self.rebuildStaticLayerImage(size: self.lastRenderSize)
                                }
                                self.isOffline = false
                                await MapCacheService.shared.saveIfChanged(fallbackMap, for: self.robot.id)
                            }
                        }
                    }

                } catch is CancellationError {
                    break
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // URLSession task was cancelled (view dismissed) — exit cleanly
                    break
                } catch {
                    logger.warning("Map SSE error: \(error.localizedDescription, privacy: .public) — falling back to HTTP poll")
                    // Einmaliger HTTP-Poll als Fallback
                    if let newMap = try? await api.getMap() {
                        self.map = newMap
                        self.rebuildSegmentPixelSets()
                        self.updateCachedSegmentInfos()
                        if self.lastRenderSize.width > 0 {
                            self.rebuildStaticLayerImage(size: self.lastRenderSize)
                        }
                        self.isOffline = false
                        await MapCacheService.shared.saveIfChanged(newMap, for: self.robot.id)
                    } else {
                        // HTTP-Poll auch fehlgeschlagen
                        if self.map == nil, let cachedMap = await MapCacheService.shared.load(for: self.robot.id) {
                            self.map = cachedMap
                            self.isOffline = true
                        } else if self.map != nil {
                            self.isOffline = true
                        }
                    }

                    retryCount += 1
                    let delay: Double = retryCount == 1 ? 2 : retryCount == 2 ? 5 : 30
                    logger.info("Map SSE retry \(retryCount, privacy: .public) — waiting \(delay, privacy: .public)s")
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch is CancellationError {
                        break
                    } catch {
                        break
                    }
                }
            }
        }
    }

    func stopMapRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Performance Caching

    private func rebuildSegmentPixelSets() {
        guard let layers = map?.layers else {
            segmentPixelSets = [:]
            return
        }
        var sets: [String: Set<Int>] = [:]
        for layer in layers where layer.type == "segment" {
            guard let id = layer.metaData?.segmentId else { continue }
            let pixels = layer.decompressedPixels
            var set = Set<Int>(minimumCapacity: pixels.count / 2)
            var i = 0
            while i < pixels.count - 1 {
                set.insert(pixels[i] &<< 16 | pixels[i + 1])
                i += 2
            }
            sets[id] = set
        }
        segmentPixelSets = sets
    }

    private func updateCachedSegmentInfos() {
        guard let layers = map?.layers else {
            cachedSegmentInfos = []
            return
        }
        var infos: [SegmentInfo] = []
        for layer in layers where layer.type == "segment" {
            guard let segmentId = layer.metaData?.segmentId else { continue }
            var midX: Int? = layer.dimensions?.x?.mid
            var midY: Int? = layer.dimensions?.y?.mid
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
            let name = segments.first { $0.id == segmentId }?.displayName
                ?? layer.metaData?.name
                ?? String(localized: "map.room") + " \(segmentId)"
            infos.append(SegmentInfo(id: segmentId, name: name, midX: finalMidX, midY: finalMidY))
        }
        cachedSegmentInfos = infos
    }

    // MARK: - Static Layer Segment Colors

    private static let segmentUIColors: [UIColor] = [
        UIColor(red: 0.65, green: 0.80, blue: 0.92, alpha: 1),
        UIColor(red: 0.70, green: 0.88, blue: 0.75, alpha: 1),
        UIColor(red: 0.92, green: 0.78, blue: 0.72, alpha: 1),
        UIColor(red: 0.82, green: 0.75, blue: 0.90, alpha: 1),
        UIColor(red: 0.90, green: 0.85, blue: 0.65, alpha: 1),
        UIColor(red: 0.70, green: 0.85, blue: 0.85, alpha: 1),
        UIColor(red: 0.90, green: 0.72, blue: 0.78, alpha: 1),
        UIColor(red: 0.78, green: 0.88, blue: 0.72, alpha: 1),
    ]

    private static func segmentUIColor(segmentId: String?) -> UIColor {
        if let id = segmentId, let num = Int(id) {
            return segmentUIColors[num % segmentUIColors.count]
        }
        return segmentUIColors[0]
    }

    // MARK: - Static Layer Pre-rendering

    func rebuildStaticLayerImage(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard let map = map, let layers = map.layers, !layers.isEmpty else {
            staticLayerImage = nil
            return
        }

        lastRenderSize = size
        let pixelSize = map.pixelSize ?? 5
        guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

        let layersCopy = layers
        let scale = params.scale
        let offsetX = params.offsetX
        let offsetY = params.offsetY
        let pxSize = pixelSize

        Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: size)
            let uiImage = renderer.image { ctx in
                let cgCtx = ctx.cgContext

                let pixelScale = scale * CGFloat(pxSize)

                // Floor
                for layer in layersCopy where layer.type == "floor" {
                    let pixels = layer.decompressedPixels
                    cgCtx.setFillColor(UIColor(white: 0.92, alpha: 1).cgColor)
                    var i = 0
                    while i < pixels.count - 1 {
                        let x = CGFloat(pixels[i]) * scale + offsetX
                        let y = CGFloat(pixels[i + 1]) * scale + offsetY
                        cgCtx.fill(CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5))
                        i += 2
                    }
                }

                // Segments (unselected base color with material texture)
                for layer in layersCopy where layer.type == "segment" {
                    let pixels = layer.decompressedPixels
                    guard !pixels.isEmpty else { continue }
                    let baseColor = MapViewModel.segmentUIColor(segmentId: layer.metaData?.segmentId).withAlphaComponent(0.6)
                    let material = layer.metaData?.material

                    let textureInterval: Int
                    let isHorizontal: Bool
                    let isVertical: Bool
                    switch material {
                    case "tile":
                        textureInterval = 4; isHorizontal = true; isVertical = true
                    case "wood", "wood_horizontal":
                        textureInterval = 3; isHorizontal = true; isVertical = false
                    case "wood_vertical":
                        textureInterval = 3; isHorizontal = false; isVertical = true
                    default:
                        textureInterval = 0; isHorizontal = false; isVertical = false
                    }

                    let accentColor = baseColor.withAlphaComponent(0.85 * 0.6)

                    var i = 0
                    while i < pixels.count - 1 {
                        let px = pixels[i]
                        let py = pixels[i + 1]
                        let x = CGFloat(px) * scale + offsetX
                        let y = CGFloat(py) * scale + offsetY
                        let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)

                        let shouldAccent: Bool
                        if textureInterval > 0 {
                            shouldAccent = (isHorizontal && py % textureInterval == 0) || (isVertical && px % textureInterval == 0)
                        } else {
                            shouldAccent = false
                        }

                        cgCtx.setFillColor(shouldAccent ? accentColor.cgColor : baseColor.cgColor)
                        cgCtx.fill(rect)
                        i += 2
                    }
                }

                // Walls (thin, matching InteractiveMapView.drawWalls)
                let wallColor = UIColor(white: 0.25, alpha: 1).cgColor
                let normalScale = scale * CGFloat(pxSize)
                let wallScale = normalScale * 0.2
                cgCtx.setFillColor(wallColor)
                for layer in layersCopy where layer.type == "wall" {
                    let pixels = layer.decompressedPixels
                    guard !pixels.isEmpty else { continue }
                    var i = 0
                    while i < pixels.count - 1 {
                        let x = CGFloat(pixels[i]) * scale + offsetX + normalScale * 0.4
                        let y = CGFloat(pixels[i + 1]) * scale + offsetY + normalScale * 0.4
                        cgCtx.fill(CGRect(x: x, y: y, width: wallScale, height: wallScale))
                        i += 2
                    }
                }
            }

            await MainActor.run { [weak self] in
                self?.staticLayerImage = uiImage.cgImage
            }
        }
    }

    // MARK: - Cleaning Actions
    func cleanSelectedRooms() async {
        guard let api = api, !selectedSegmentIds.isEmpty else { return }
        isCleaning = true
        defer { isCleaning = false }

        do {
            try await api.cleanSegments(ids: selectedSegmentIds, iterations: selectedIterations, customOrder: selectedSegmentIds.count > 1)
            selectedSegmentIds.removeAll()
            selectedIterations = 1
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("cleanSelectedRooms FAILED: \(error.localizedDescription, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    func cleanZones() async {
        guard let api = api, !drawnZones.isEmpty else { return }
        do {
            try await api.cleanZones(drawnZones)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Zone cleaning FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    // MARK: - GoTo Actions
    func goToPoint(x: Int, y: Int) async {
        guard let api = api else { return }
        logger.debug("Sending GoTo coordinates: x=\(x, privacy: .public), y=\(y, privacy: .public)")
        do {
            try await api.goTo(x: x, y: y)
            logger.debug("GoTo command sent successfully")
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("GoTo failed: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
        cancelEditMode()
    }

    func saveCurrentLocationAsPreset() {
        guard let x = pendingGoToX, let y = pendingGoToY else { return }
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let preset = GoToPreset(name: trimmedName, x: x, y: y, robotId: robot.id)
        presetStore.addPreset(preset)

        pendingGoToX = nil
        pendingGoToY = nil
        newPresetName = ""
        goToMarkerPosition = nil
        cancelEditMode()
    }

    // MARK: - Room Editing
    func renameRoom(id: String, name: String) async {
        guard let api = api else {
            logger.error("renameSegment: No API available")
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.debug("renameSegment: Name is empty")
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        logger.debug("renameSegment: Calling API with segmentId=\(id, privacy: .public), name='\(trimmedName, privacy: .public)'")

        do {
            try await api.renameSegment(id: id, name: trimmedName)
            logger.debug("renameSegment: API call successful")

            // Small delay to let the robot process the rename
            try? await Task.sleep(for: .milliseconds(500))

            // Reload segments to get updated names
            let newSegments = try await api.getSegments()
            logger.debug("renameSegment: Segments reloaded, count=\(newSegments.count, privacy: .public)")

            segments = newSegments
            updateCachedSegmentInfos()
            if lastRenderSize.width > 0 {
                rebuildStaticLayerImage(size: lastRenderSize)
            }
            mapRefreshId = UUID()
            showRenameSheet = false
            editMode = .none
            selectedSegmentIds.removeAll()
            renameSegmentId = nil
            renameNewName = ""
        } catch {
            logger.error("renameSegment FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
            showRenameSheet = false
            editMode = .none
            selectedSegmentIds.removeAll()
            renameSegmentId = nil
            renameNewName = ""
        }
    }

    func joinRooms(ids: [String]) async {
        guard let api = api, ids.count == 2 else { return }
        logger.debug("joinSelectedSegments: Calling API with segmentA=\(ids[0], privacy: .public), segmentB=\(ids[1], privacy: .public)")

        do {
            try await api.joinSegments(segmentAId: ids[0], segmentBId: ids[1])
            logger.debug("joinSelectedSegments: API call successful")
            selectedSegmentIds.removeAll()

            do {
                let newMap = try await api.getMap()
                self.map = newMap
                self.rebuildSegmentPixelSets()
                self.updateCachedSegmentInfos()
                if self.lastRenderSize.width > 0 {
                    self.rebuildStaticLayerImage(size: self.lastRenderSize)
                }
            } catch {
                logger.error("Map reload after join failed: \(error, privacy: .public)")
                errorRouter?.show(error)
            }
            do {
                let newSegments = try await api.getSegments()
                self.segments = newSegments
                self.updateCachedSegmentInfos()
                if self.lastRenderSize.width > 0 {
                    self.rebuildStaticLayerImage(size: self.lastRenderSize)
                }
                logger.debug("joinSelectedSegments: Reloaded \(newSegments.count, privacy: .public) segments")
            } catch {
                logger.error("Segments reload after join failed: \(error, privacy: .public)")
                errorRouter?.show(error)
            }
        } catch {
            logger.error("joinSelectedSegments FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    func splitRoom(segmentId: String, start: CGPoint, end: CGPoint, viewSize: CGSize) async {
        guard let api = api else {
            logger.error("performSplit: No API available")
            return
        }
        guard let map = map, let layers = map.layers else {
            logger.error("performSplit: No map or layers")
            return
        }

        let pixelSize = map.pixelSize ?? 5

        guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: viewSize) else { return }
        let mapScale = params.scale
        let offsetX = params.offsetX
        let offsetY = params.offsetY

        // start/end are already in map coordinates (from screenToMapCoords)
        // Convert directly to pixel coordinates — no gesture transform removal needed
        let pixelAX = Int(((start.x - offsetX) / mapScale).rounded())
        let pixelAY = Int(((start.y - offsetY) / mapScale).rounded())
        let pixelBX = Int(((end.x - offsetX) / mapScale).rounded())
        let pixelBY = Int(((end.y - offsetY) / mapScale).rounded())

        let pointA = ZonePoint(x: pixelAX * pixelSize, y: pixelAY * pixelSize)
        let pointB = ZonePoint(x: pixelBX * pixelSize, y: pixelBY * pixelSize)

        logger.debug("performSplit: Pixel coords: A=(\(pixelAX, privacy: .public),\(pixelAY, privacy: .public)), B=(\(pixelBX, privacy: .public),\(pixelBY, privacy: .public))")
        logger.debug("performSplit: API coords (x\(pixelSize, privacy: .public)): A=(\(pointA.x, privacy: .public),\(pointA.y, privacy: .public)), B=(\(pointB.x, privacy: .public),\(pointB.y, privacy: .public))")
        logger.debug("performSplit: Calling API with segmentId=\(segmentId, privacy: .public)")

        do {
            try await api.splitSegment(segmentId: segmentId, pointA: pointA, pointB: pointB)
            logger.debug("performSplit: API call successful")

            do {
                let newMap = try await api.getMap()
                self.map = newMap
                self.rebuildSegmentPixelSets()
                self.updateCachedSegmentInfos()
                if self.lastRenderSize.width > 0 {
                    self.rebuildStaticLayerImage(size: self.lastRenderSize)
                }
            } catch {
                logger.error("Map reload after split failed: \(error, privacy: .public)")
                errorRouter?.show(error)
            }
            do {
                let newSegments = try await api.getSegments()
                self.segments = newSegments
                self.updateCachedSegmentInfos()
                if self.lastRenderSize.width > 0 {
                    self.rebuildStaticLayerImage(size: self.lastRenderSize)
                }
                logger.debug("performSplit: Reloaded \(newSegments.count, privacy: .public) segments")
            } catch {
                logger.error("Segments reload after split failed: \(error, privacy: .public)")
                errorRouter?.show(error)
            }

            splitSegmentId = nil
            selectedSegmentIds.removeAll()
            editMode = .none
        } catch {
            logger.error("performSplit FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    // MARK: - Restriction Actions
    func deleteRestriction(type: RestrictionType, index: Int) async {
        guard let api = api, var restrictions = existingRestrictions else { return }

        switch type {
        case .virtualWall:
            if index < restrictions.virtualWalls.count {
                restrictions.virtualWalls.remove(at: index)
            }
        case .noGoZone:
            if index < restrictions.restrictedZones.count {
                restrictions.restrictedZones.remove(at: index)
            }
        case .noMopZone:
            if index < restrictions.noMopZones.count {
                restrictions.noMopZones.remove(at: index)
            }
        }

        do {
            try await api.setVirtualRestrictions(restrictions)
            existingRestrictions = restrictions
        } catch {
            logger.error("Delete restriction FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    func saveRestrictions() async {
        guard let api = api else { return }

        var restrictions = existingRestrictions ?? VirtualRestrictions()
        restrictions.restrictedZones.append(contentsOf: drawnNoGoAreas)
        restrictions.noMopZones.append(contentsOf: drawnNoMopAreas)
        restrictions.virtualWalls.append(contentsOf: drawnVirtualWalls)

        logger.debug("saveRestrictions: zones=\(restrictions.restrictedZones.count, privacy: .public), noMop=\(restrictions.noMopZones.count, privacy: .public), walls=\(restrictions.virtualWalls.count, privacy: .public)")

        do {
            try await api.setVirtualRestrictions(restrictions)
            logger.debug("saveRestrictions: Saved successfully")
            existingRestrictions = restrictions
        } catch {
            logger.error("saveRestrictions FAILED: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }

    // MARK: - Edit Mode Control
    func cancelEditMode() {
        editMode = .none
        drawnZones.removeAll()
        drawnNoGoAreas.removeAll()
        drawnNoMopAreas.removeAll()
        drawnVirtualWalls.removeAll()
        splitSegmentId = nil
        selectedSegmentIds.removeAll()
        restrictionToDelete = nil
    }

    func confirmEditMode(currentDrawStart: CGPoint?, currentDrawEnd: CGPoint?) async {
        logger.debug("confirmEditMode called, editMode=\(String(describing: self.editMode), privacy: .public)")

        guard let api = api else {
            logger.error("confirmEditMode: No API available")
            return
        }

        switch editMode {
        case .zone:
            logger.debug("confirmEditMode: Zone mode, drawnZones count=\(self.drawnZones.count, privacy: .public)")
            if !drawnZones.isEmpty {
                do {
                    try await api.cleanZones(drawnZones)
                    logger.debug("confirmEditMode: Zone cleaning started successfully")
                    await robotManager.refreshRobot(robot.id)
                } catch {
                    logger.error("confirmEditMode: Zone cleaning FAILED: \(error, privacy: .public)")
                    errorRouter?.show(error)
                }
            }

        case .noGoArea, .noMopArea, .virtualWall:
            logger.debug("confirmEditMode: Restrictions mode")
            logger.debug("drawnNoGoAreas: \(self.drawnNoGoAreas.count, privacy: .public)")
            logger.debug("drawnNoMopAreas: \(self.drawnNoMopAreas.count, privacy: .public)")
            logger.debug("drawnVirtualWalls: \(self.drawnVirtualWalls.count, privacy: .public)")
            await saveRestrictions()

        case .deleteRestriction:
            if let toDelete = restrictionToDelete, var restrictions = existingRestrictions {
                switch toDelete.type {
                case .virtualWall:
                    if toDelete.index < restrictions.virtualWalls.count {
                        restrictions.virtualWalls.remove(at: toDelete.index)
                    }
                case .noGoZone:
                    if toDelete.index < restrictions.restrictedZones.count {
                        restrictions.restrictedZones.remove(at: toDelete.index)
                    }
                case .noMopZone:
                    if toDelete.index < restrictions.noMopZones.count {
                        restrictions.noMopZones.remove(at: toDelete.index)
                    }
                }

                do {
                    try await api.setVirtualRestrictions(restrictions)
                    existingRestrictions = restrictions
                    restrictionToDelete = nil
                } catch {
                    logger.error("Delete restriction FAILED: \(error, privacy: .public)")
                }
            }

        case .goTo, .savePreset, .roomEdit, .splitRoom, .none:
            break
        }

        cancelEditMode()
    }
}
