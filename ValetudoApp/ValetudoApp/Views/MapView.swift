import SwiftUI
import os

enum MapEditMode: Equatable {
    case none
    case zone           // Draw cleaning zones
    case noGoArea       // Draw no-go zones
    case noMopArea      // Draw no-mop zones
    case virtualWall    // Draw virtual walls
    case goTo           // Tap to go to location
    case savePreset     // Tap to save location as preset
    case roomEdit       // Edit rooms (rename, join, split)
    case splitRoom      // Draw split line on selected room
    case deleteRestriction // Tap to delete restriction
}

// MARK: - Restriction Identifier
enum RestrictionType {
    case virtualWall
    case noGoZone
    case noMopZone
}

struct RestrictionIdentifier: Equatable {
    let type: RestrictionType
    let index: Int
}

// MARK: - Map Tab View (for Tab Bar)
struct MapTabView: View {
    @Environment(RobotManager.self) var robotManager
    let robot: RobotConfig
    @State private var viewId = UUID()

    var body: some View {
        NavigationStack {
            MapContentView(robot: robot, robotManager: robotManager, isFullscreen: true)
                .id(viewId)
                .navigationTitle(String(localized: "map.title"))
                .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: robot.id) { _, _ in
            // Force complete view rebuild when robot changes
            viewId = UUID()
        }
    }
}

// MARK: - Embedded Map Preview (for Detail View)
struct MapPreviewView: View {
    @Environment(RobotManager.self) var robotManager
    let robot: RobotConfig
    @State private var map: RobotMap?
    @State private var restrictions: VirtualRestrictions?
    @State private var isLoading = true
    @State private var refreshTask: Task<Void, Never>?
    @Binding var showFullMap: Bool

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "MapView")

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    var body: some View {
        Button {
            showFullMap = true
        } label: {
            ZStack {
                if isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                        }
                } else if let map = map {
                    GeometryReader { geometry in
                        MiniMapView(map: map, viewSize: geometry.size, restrictions: restrictions)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "map")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text(String(localized: "map.unavailable"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                // Overlay tap hint
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2)
                            Text(String(localized: "map.tap_to_expand"))
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadMap()
            startLiveRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
        .onChange(of: showFullMap) { _, isShowing in
            if isShowing {
                refreshTask?.cancel()
            } else {
                startLiveRefresh()
            }
        }
    }

    private func loadMap() async {
        guard let api = api else {
            isLoading = false
            return
        }

        do {
            async let mapTask = api.getMap()
            async let restrictionsTask = api.getVirtualRestrictions()

            map = try await mapTask
            restrictions = try? await restrictionsTask
        } catch {
            logger.error("Failed to load map preview: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func startLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled, let api = api {
                    if let newMap = try? await api.getMap() {
                        map = newMap
                    }
                }
            }
        }
    }
}

// MARK: - Map Content View (shared between Tab and Sheet)
struct MapContentView: View {
    @Environment(ErrorRouter.self) var errorRouter
    let robot: RobotConfig
    let isFullscreen: Bool

    @State var viewModel: MapViewModel

    // MARK: - Gesture / View-local state (inherently view-bound)
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0
    @State var offset: CGSize = .zero
    @State var lastOffset: CGSize = .zero

    // Drawing state (gesture-local, frame-dependent)
    @State var currentDrawStart: CGPoint?
    @State var currentDrawEnd: CGPoint?
    @State var isDraggingSplitStart = false
    @State var isDraggingSplitEnd = false

    // Store current view size for coordinate calculations
    @State var currentViewSize: CGSize = .zero

    init(robot: RobotConfig, robotManager: RobotManager, isFullscreen: Bool = false) {
        self.robot = robot
        self.isFullscreen = isFullscreen
        _viewModel = State(initialValue: MapViewModel(robot: robot, robotManager: robotManager, isFullscreen: isFullscreen))
    }

    var body: some View {
        Text("MAP TEST — sheet opened successfully")
            .font(.title)
            .padding()
            .task {
                print(">>> SIMPLE BODY .task START — NOT calling loadMap")
                // viewModel.errorRouter = errorRouter
                // await viewModel.loadMap()
                // viewModel.startMapRefresh()
                print(">>> SIMPLE BODY .task END")
            }
            .onDisappear {
                viewModel.stopMapRefresh()
            }
    }

}

// MARK: - Map View (Sheet/Modal version - uses MapContentView)
struct MapView: View {
    @Environment(\.dismiss) var dismiss
    let robot: RobotConfig
    let robotManager: RobotManager

    var body: some View {
        NavigationStack {
            MapContentView(robot: robot, robotManager: robotManager, isFullscreen: true)
                .navigationTitle(String(localized: "map.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .fontWeight(.semibold)
                        }
                    }
                }
        }
    }
}

#Preview {
    MapView(robot: RobotConfig(name: "Test", host: "192.168.0.35"), robotManager: RobotManager())
        .environment(RobotManager())
}
