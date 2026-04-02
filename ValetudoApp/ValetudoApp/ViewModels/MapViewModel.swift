import SwiftUI
import Foundation
import os

// MARK: - MapViewModel

@MainActor
final class MapViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MapViewModel")
    // MARK: - Configuration
    let robot: RobotConfig
    private let robotManager: RobotManager
    let isFullscreen: Bool

    // MARK: - Map Data State
    @Published var map: RobotMap?
    @Published var segments: [Segment] = []
    @Published var isLoading = true
    @Published var mapRefreshId = UUID()
    @Published var loadError: String?

    // MARK: - Capabilities
    @Published var hasZoneCleaning = false
    @Published var hasVirtualRestrictions = false
    @Published var hasGoTo = false
    @Published var hasSegmentRename = false
    @Published var hasSegmentEdit = false

    // MARK: - Edit Mode State
    @Published var editMode: MapEditMode = .none
    @Published var drawnZones: [CleaningZone] = []
    @Published var drawnNoGoAreas: [NoGoArea] = []
    @Published var drawnNoMopAreas: [NoMopArea] = []
    @Published var drawnVirtualWalls: [VirtualWall] = []

    // MARK: - Existing Restrictions
    @Published var existingRestrictions: VirtualRestrictions?
    @Published var restrictionToDelete: RestrictionIdentifier?

    // MARK: - Room Editing State
    @Published var showRenameSheet = false
    @Published var renameSegmentId: String?
    @Published var renameNewName = ""
    @Published var splitSegmentId: String?
    @Published var selectedSegmentIds: Set<String> = []

    // MARK: - GoTo State
    @Published var goToMarkerPosition: CGPoint?
    @Published var goToApiCoords: (x: Int, y: Int)?
    @Published var showGoToConfirm = false

    // MARK: - GoTo Presets
    @Published var presetStore = GoToPresetStore()
    @Published var showSavePresetSheet = false
    @Published var pendingGoToX: Int?
    @Published var pendingGoToY: Int?
    @Published var newPresetName = ""
    @Published var showPresetsSheet = false
    @Published var showPresetsOnMap = false
    @Published var editingPreset: GoToPreset?

    // MARK: - Cleaning State
    @Published var isCleaning = false
    @Published var selectedIterations: Int = 1

    // MARK: - UI State
    @Published var showRoomLabels: Bool = true

    // MARK: - Error State
    @Published var errorMessage: String? = nil

    // MARK: - Offline State
    @Published var isOffline: Bool = false

    // MARK: - Task Management
    private var refreshTask: Task<Void, Never>?

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

            // Poll map every 2 seconds
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    if let newMap = try? await api.getMap() {
                        self.map = newMap
                        self.isOffline = false
                        await MapCacheService.shared.save(newMap, for: robot.id)
                    } else {
                        // getMap() fehlgeschlagen — Cache laden falls noch keine Karte vorhanden
                        if self.map == nil, let cachedMap = await MapCacheService.shared.load(for: robot.id) {
                            self.map = cachedMap
                            self.isOffline = true
                        } else if self.map != nil {
                            // Karte bereits sichtbar — Offline-Indikator setzen
                            self.isOffline = true
                        }
                    }
                }
            }
        }
    }

    func stopMapRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Cleaning Actions
    func cleanSelectedRooms() async {
        guard let api = api, !selectedSegmentIds.isEmpty else { return }
        isCleaning = true
        defer { isCleaning = false }

        do {
            try await api.cleanSegments(ids: Array(selectedSegmentIds), iterations: selectedIterations)
            selectedSegmentIds.removeAll()
            selectedIterations = 1
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("cleanSelectedRooms FAILED: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func cleanZones() async {
        guard let api = api, !drawnZones.isEmpty else { return }
        do {
            try await api.cleanZones(drawnZones)
            await robotManager.refreshRobot(robot.id)
        } catch {
            logger.error("Zone cleaning FAILED: \(error, privacy: .public)")
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
            mapRefreshId = UUID()
            showRenameSheet = false
            editMode = .none
            selectedSegmentIds.removeAll()
            renameSegmentId = nil
            renameNewName = ""
        } catch {
            logger.error("renameSegment FAILED: \(error, privacy: .public)")
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

            if let newMap = try? await api.getMap() {
                self.map = newMap
            }
            if let newSegments = try? await api.getSegments() {
                self.segments = newSegments
                logger.debug("joinSelectedSegments: Reloaded \(newSegments.count, privacy: .public) segments")
            }
        } catch {
            logger.error("joinSelectedSegments FAILED: \(error, privacy: .public)")
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

        // Calculate map params the same way as finishDrawing/calculateMapParams
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            var i = 0
            while i < pixels.count - 1 {
                minX = Swift.min(minX, pixels[i])
                maxX = Swift.max(maxX, pixels[i])
                minY = Swift.min(minY, pixels[i + 1])
                maxY = Swift.max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = viewSize.width - padding * 2
        let availableHeight = viewSize.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let mapScale = Swift.min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * mapScale) / 2 - CGFloat(minX) * mapScale
        let offsetY = padding + (availableHeight - contentHeight * mapScale) / 2 - CGFloat(minY) * mapScale

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

            if let newMap = try? await api.getMap() {
                self.map = newMap
            }
            if let newSegments = try? await api.getSegments() {
                self.segments = newSegments
                logger.debug("performSplit: Reloaded \(newSegments.count, privacy: .public) segments")
            }

            splitSegmentId = nil
            selectedSegmentIds.removeAll()
            editMode = .none
        } catch {
            logger.error("performSplit FAILED: \(error, privacy: .public)")
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
