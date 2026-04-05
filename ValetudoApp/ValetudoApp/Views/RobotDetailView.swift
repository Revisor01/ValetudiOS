import SwiftUI

struct RobotDetailView: View {
    @State private var viewModel: RobotDetailViewModel
    @Environment(ErrorRouter.self) var errorRouter

    @State private var showFullMap = false
    @State private var showUpdateWarning = false

    private var showUpdateOverlay: Bool {
        guard let phase = viewModel.updateService?.phase else { return false }
        switch phase {
        case .applying, .rebooting:
            return true
        default:
            return false
        }
    }

    init(robot: RobotConfig, robotManager: RobotManager) {
        _viewModel = State(initialValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }

    var body: some View {
        List {
            UpdateStatusBannerView(viewModel: viewModel, showUpdateWarning: $showUpdateWarning)

            Section {
                RobotStatusHeaderView(viewModel: viewModel)
                    .listRowSeparator(.hidden)

                if viewModel.status?.isOnline == true {
                    MapPreviewView(robot: viewModel.robot, showFullMap: $showFullMap)
                        .listRowSeparator(.hidden)

                    HStack(spacing: 8) {
                        if AttachmentChipsView.hasAnyAttachmentInfo(viewModel) {
                            AttachmentChipsView(viewModel: viewModel)
                        }
                        Spacer()
                        LiveStatsChipView(viewModel: viewModel)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            if viewModel.status?.isOnline == true {
                RobotControlSectionView(viewModel: viewModel)
                CleanRouteSectionView(viewModel: viewModel)
                RoomsSectionView(viewModel: viewModel)
                ConsumablesPreviewSectionView(viewModel: viewModel)
                EventsSectionView(viewModel: viewModel)
                ObstaclesSectionView(viewModel: viewModel)
                StatisticsSectionView(viewModel: viewModel)

                Section {
                    NavigationLink {
                        RobotSettingsView(robot: viewModel.robot, robotManager: viewModel.robotManager, updateService: viewModel.updateService)
                    } label: {
                        Label(String(localized: "settings.section_robot"), systemImage: "poweroutlet.type.b")
                    }

                    NavigationLink {
                        StationSettingsView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "settings.section_station"), systemImage: "dock.rectangle")
                    }

                    NavigationLink {
                        TimersView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "timers.title"), systemImage: "clock")
                    }

                    NavigationLink {
                        DoNotDisturbView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "dnd.title"), systemImage: "moon.fill")
                    }

                    if viewModel.hasManualControl {
                        NavigationLink {
                            ManualControlView(robot: viewModel.robot)
                        } label: {
                            Label(String(localized: "manual.title"), systemImage: "dpad")
                        }
                    }
                } header: {
                    Text(String(localized: "settings.title"))
                }
            }
        }
        .navigationTitle(viewModel.robot.name)
        .sheet(isPresented: $showFullMap) {
            Text("SHEET TEST")
                .font(.largeTitle)
        }
        .alert(String(localized: "update.warning_title"), isPresented: $showUpdateWarning) {
            Button(String(localized: "update.cancel"), role: .cancel) { }
            Button(String(localized: "update.confirm"), role: .destructive) {
                Task { await viewModel.startUpdate() }
            }
        } message: {
            Text(String(localized: "update.warning_message"))
        }
        .overlay {
            if showUpdateOverlay {
                UpdateOverlayView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showUpdateOverlay)
        .navigationBarBackButtonHidden(showUpdateOverlay)
        .interactiveDismissDisabled(showUpdateOverlay)
        .task {
            viewModel.errorRouter = errorRouter
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .onChange(of: viewModel.isCleaning) { _, newValue in
            if newValue {
                viewModel.startStatsPolling()
            } else {
                viewModel.stopStatsPolling()
            }
        }
        .onAppear {
            if viewModel.isCleaning {
                viewModel.startStatsPolling()
            }
        }
        .onDisappear {
            viewModel.stopStatsPolling()
        }
    }
}

#Preview {
    NavigationStack {
        RobotDetailView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"), robotManager: RobotManager())
    }
}
