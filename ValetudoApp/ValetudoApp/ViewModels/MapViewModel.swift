import SwiftUI
import Foundation

// MARK: - MapViewModel

@MainActor
final class MapViewModel: ObservableObject {
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
            // Silently ignore capability check failures
        }

        if hasVirtualRestrictions {
            do {
                let restrictions = try await api.getVirtualRestrictions()
                existingRestrictions = restrictions
            } catch {
                print("Virtual restrictions failed: \(error)")
            }
        }

        do {
            let loadedMap = try await api.getMap()
            var loadedSegments: [Segment] = []
            do {
                loadedSegments = try await api.getSegments()
            } catch {
                print("Segments failed: \(error)")
            }

            map = loadedMap
            segments = loadedSegments
            loadError = nil
            isLoading = false
        } catch {
            loadError = error.localizedDescription
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
            // Silently ignore clean failures
        }
    }

    func cleanZones() async {
        guard let api = api, !drawnZones.isEmpty else { return }
        do {
            try await api.cleanZones(drawnZones)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("[DEBUG] Zone cleaning FAILED: \(error)")
        }
    }

    // MARK: - GoTo Actions
    func goToPoint(x: Int, y: Int) async {
        guard let api = api else { return }
        print("[GoTo DEBUG] Sending coordinates: x=\(x), y=\(y)")
        do {
            try await api.goTo(x: x, y: y)
            print("[GoTo DEBUG] GoTo command sent successfully")
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("[GoTo DEBUG] GoTo failed: \(error)")
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
            print("[DEBUG] renameSegment: No API available")
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("[DEBUG] renameSegment: Name is empty")
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        print("[DEBUG] renameSegment: Calling API with segmentId=\(id), name='\(trimmedName)'")

        do {
            try await api.renameSegment(id: id, name: trimmedName)
            print("[DEBUG] renameSegment: API call successful")

            // Small delay to let the robot process the rename
            try? await Task.sleep(for: .milliseconds(500))

            // Reload segments to get updated names
            let newSegments = try await api.getSegments()
            print("[DEBUG] renameSegment: Segments reloaded, count=\(newSegments.count)")

            segments = newSegments
            mapRefreshId = UUID()
            showRenameSheet = false
            editMode = .none
            selectedSegmentIds.removeAll()
            renameSegmentId = nil
            renameNewName = ""
        } catch {
            print("[DEBUG] renameSegment FAILED: \(error)")
            showRenameSheet = false
            editMode = .none
            selectedSegmentIds.removeAll()
            renameSegmentId = nil
            renameNewName = ""
        }
    }

    func joinRooms(ids: [String]) async {
        guard let api = api, ids.count == 2 else { return }
        print("[DEBUG] joinSelectedSegments: Calling API with segmentA=\(ids[0]), segmentB=\(ids[1])")

        do {
            try await api.joinSegments(segmentAId: ids[0], segmentBId: ids[1])
            print("[DEBUG] joinSelectedSegments: API call successful")
            selectedSegmentIds.removeAll()

            if let newMap = try? await api.getMap() {
                self.map = newMap
            }
            if let newSegments = try? await api.getSegments() {
                self.segments = newSegments
                print("[DEBUG] joinSelectedSegments: Reloaded \(newSegments.count) segments")
            }
        } catch {
            print("[DEBUG] joinSelectedSegments FAILED: \(error)")
        }
    }

    func splitRoom(segmentId: String, start: CGPoint, end: CGPoint, viewSize: CGSize, gestureScale: CGFloat, gestureOffset: CGSize) async {
        guard let api = api else {
            print("[DEBUG] performSplit: No API available")
            return
        }
        guard let map = map, let layers = map.layers else {
            print("[DEBUG] performSplit: No map or layers")
            return
        }

        let pixelSize = map.pixelSize ?? 5
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

        let viewWidth: CGFloat = viewSize.width > 0 ? viewSize.width : 400
        let viewHeight: CGFloat = viewSize.height > 0 ? viewSize.height : 600
        let padding: CGFloat = 20
        let availableWidth = viewWidth - padding * 2
        let availableHeight = viewHeight - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let mapScale = Swift.min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * mapScale) / 2 - CGFloat(minX) * mapScale
        let offsetY = padding + (availableHeight - contentHeight * mapScale) / 2 - CGFloat(minY) * mapScale

        let adjustedStartX = (start.x - gestureOffset.width) / gestureScale
        let adjustedStartY = (start.y - gestureOffset.height) / gestureScale
        let adjustedEndX = (end.x - gestureOffset.width) / gestureScale
        let adjustedEndY = (end.y - gestureOffset.height) / gestureScale

        let pixelAX = Int((adjustedStartX - offsetX) / mapScale)
        let pixelAY = Int((adjustedStartY - offsetY) / mapScale)
        let pixelBX = Int((adjustedEndX - offsetX) / mapScale)
        let pixelBY = Int((adjustedEndY - offsetY) / mapScale)

        let pointA = ZonePoint(x: pixelAX * pixelSize, y: pixelAY * pixelSize)
        let pointB = ZonePoint(x: pixelBX * pixelSize, y: pixelBY * pixelSize)

        print("[DEBUG] performSplit: Pixel coords: A=(\(pixelAX),\(pixelAY)), B=(\(pixelBX),\(pixelBY))")
        print("[DEBUG] performSplit: API coords (x\(pixelSize)): A=(\(pointA.x),\(pointA.y)), B=(\(pointB.x),\(pointB.y))")
        print("[DEBUG] performSplit: Calling API with segmentId=\(segmentId)")

        do {
            try await api.splitSegment(segmentId: segmentId, pointA: pointA, pointB: pointB)
            print("[DEBUG] performSplit: API call successful")

            if let newMap = try? await api.getMap() {
                self.map = newMap
            }
            if let newSegments = try? await api.getSegments() {
                self.segments = newSegments
                print("[DEBUG] performSplit: Reloaded \(newSegments.count) segments")
            }

            splitSegmentId = nil
            selectedSegmentIds.removeAll()
            editMode = .none
        } catch {
            print("[DEBUG] performSplit FAILED: \(error)")
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
            print("[DEBUG] Delete restriction FAILED: \(error)")
        }
    }

    func saveRestrictions() async {
        guard let api = api else { return }

        var restrictions = existingRestrictions ?? VirtualRestrictions()
        restrictions.restrictedZones.append(contentsOf: drawnNoGoAreas)
        restrictions.noMopZones.append(contentsOf: drawnNoMopAreas)
        restrictions.virtualWalls.append(contentsOf: drawnVirtualWalls)

        print("[DEBUG] saveRestrictions: zones=\(restrictions.restrictedZones.count), noMop=\(restrictions.noMopZones.count), walls=\(restrictions.virtualWalls.count)")

        do {
            try await api.setVirtualRestrictions(restrictions)
            print("[DEBUG] saveRestrictions: Saved successfully")
            existingRestrictions = restrictions
        } catch {
            print("[DEBUG] saveRestrictions FAILED: \(error)")
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
        print("[DEBUG] confirmEditMode called, editMode=\(editMode)")

        guard let api = api else {
            print("[DEBUG] confirmEditMode: No API available")
            return
        }

        switch editMode {
        case .zone:
            print("[DEBUG] confirmEditMode: Zone mode, drawnZones count=\(drawnZones.count)")
            if !drawnZones.isEmpty {
                do {
                    try await api.cleanZones(drawnZones)
                    print("[DEBUG] confirmEditMode: Zone cleaning started successfully")
                    await robotManager.refreshRobot(robot.id)
                } catch {
                    print("[DEBUG] confirmEditMode: Zone cleaning FAILED: \(error)")
                }
            }

        case .noGoArea, .noMopArea, .virtualWall:
            print("[DEBUG] confirmEditMode: Restrictions mode")
            print("[DEBUG] drawnNoGoAreas: \(drawnNoGoAreas.count)")
            print("[DEBUG] drawnNoMopAreas: \(drawnNoMopAreas.count)")
            print("[DEBUG] drawnVirtualWalls: \(drawnVirtualWalls.count)")
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
                    print("[DEBUG] Delete restriction FAILED: \(error)")
                }
            }

        case .goTo, .savePreset, .roomEdit, .splitRoom, .none:
            break
        }

        cancelEditMode()
    }
}
