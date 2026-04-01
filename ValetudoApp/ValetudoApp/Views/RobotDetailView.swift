import SwiftUI

struct RobotDetailView: View {
    @StateObject private var viewModel: RobotDetailViewModel

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
        _viewModel = StateObject(wrappedValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }

    var body: some View {
        List {
            // Update available banner
            if case .updateAvailable = viewModel.updateService?.phase {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.available"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(viewModel.updateService?.currentVersion ?? "?") → \(viewModel.updateService?.latestVersion ?? "?")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            // GitHub release link
                            if let urlStr = viewModel.updateService?.updateUrl, let releaseURL = URL(string: urlStr) {
                                Link(destination: releaseURL) {
                                    Image(systemName: "arrow.up.forward.square")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button {
                            showUpdateWarning = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.to.line")
                                Text(String(localized: "update.install"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            } else if case .downloading = viewModel.updateService?.phase {
                // Download in progress: linear ProgressView with percentage
                Section {
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.updateService?.downloadProgress ?? 0.0)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                        HStack {
                            Text(String(localized: "update.downloading"))
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int((viewModel.updateService?.downloadProgress ?? 0.0) * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                        Text(String(localized: "update.do_not_disconnect"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else if case .readyToApply = viewModel.updateService?.phase {
                Section {
                    Button {
                        showUpdateWarning = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(.green)
                            Text(String(localized: "update.apply"))
                            Spacer()
                        }
                    }
                }
            } else if viewModel.updateInProgress {
                // Update in progress banner for checking/applying/rebooting
                Section {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(String(localized: "update.in_progress"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "update.in_progress_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else if case .error(let message) = viewModel.updateService?.phase {
                // Error banner with retry button
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.error"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Button {
                            viewModel.updateService?.reset()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(String(localized: "update.retry"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            } else if let currentVersion = viewModel.updateService?.currentVersion,
                      let latestVersion = viewModel.updateService?.latestVersion,
                      currentVersion != latestVersion,
                      let updateUrl = viewModel.updateService?.updateUrl {
                // Fallback: GitHub-based update check (if Valetudo updater not available)
                Section {
                    if let url = URL(string: updateUrl) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text(String(localized: "update.available"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(currentVersion) → \(latestVersion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Compact status header + Map Preview + Stats
            Section {
                compactStatusHeader
                    .listRowSeparator(.hidden)

                if viewModel.status?.isOnline == true {
                    MapPreviewView(robot: viewModel.robot, showFullMap: $showFullMap)
                        .listRowSeparator(.hidden)

                    // Attachments (left) + Stats chip (right) in one row
                    HStack(spacing: 8) {
                        // Attachments on left
                        if hasAnyAttachmentInfo {
                            attachmentChips
                        }

                        Spacer()

                        // Stats chip on right
                        liveStatsChip
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            // Control Section
            if viewModel.status?.isOnline == true {
                controlSection

                // Clean Route Picker (capability-gated)
                cleanRouteSection

                // Rooms (moved up)
                roomsSection

                // Consumables (moved down)
                consumablesPreviewSection

                // Events Section (capability-gated)
                eventsSection

                // Obstacle Photos Section (capability-gated)
                obstaclesSection

                // Statistics (Accordion)
                statisticsSection

                // Settings Section
                Section {
                    // Roboter (Robot Settings)
                    NavigationLink {
                        RobotSettingsView(robot: viewModel.robot, robotManager: viewModel.robotManager, updateService: viewModel.updateService)
                    } label: {
                        Label(String(localized: "settings.section_robot"), systemImage: "poweroutlet.type.b")
                    }

                    // Station (Dock Settings)
                    NavigationLink {
                        StationSettingsView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "settings.section_station"), systemImage: "dock.rectangle")
                    }

                    // Timer
                    NavigationLink {
                        TimersView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "timers.title"), systemImage: "clock")
                    }

                    // Nicht stören (DND)
                    NavigationLink {
                        DoNotDisturbView(robot: viewModel.robot)
                    } label: {
                        Label(String(localized: "dnd.title"), systemImage: "moon.fill")
                    }

                    // Manual Control (if available)
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

                // Device Info (ganz unten)
                DeviceInfoSection(viewModel: viewModel)
            }
        }
        .navigationTitle(viewModel.robot.name)
        .sheet(isPresented: $showFullMap) {
            MapView(robot: viewModel.robot)
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
                updateOverlayView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showUpdateOverlay)
        .navigationBarBackButtonHidden(showUpdateOverlay)
        .interactiveDismissDisabled(showUpdateOverlay)
        .task {
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

    // MARK: - Update Overlay

    @ViewBuilder
    private var updateOverlayView: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(updateOverlayTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(updateOverlaySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private var updateOverlayTitle: String {
        if case .rebooting = viewModel.updateService?.phase {
            return String(localized: "update.rebooting_title")
        }
        return String(localized: "update.applying_title")
    }

    private var updateOverlaySubtitle: String {
        if case .rebooting = viewModel.updateService?.phase {
            return String(localized: "update.rebooting_hint")
        }
        return String(localized: "update.applying_hint")
    }

    // MARK: - Compact Status Header
    @ViewBuilder
    private var compactStatusHeader: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(viewModel.status?.isOnline == true ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Status text
            if let statusValue = viewModel.status?.statusValue {
                Text(localizedStatus(statusValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor(statusValue))
            } else {
                Text(String(localized: "robot.offline"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }

            // Model name (after status)
            if let model = viewModel.status?.info?.modelName {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Consumable warning
            if viewModel.hasConsumableWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Locate button (compact, before battery)
            if viewModel.status?.isOnline == true {
                Button {
                    Task { await viewModel.locate() }
                } label: {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Battery pill (rightmost)
            if let battery = viewModel.status?.batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(level: battery, charging: viewModel.status?.batteryStatus == "charging"))
                        .font(.caption)
                    Text("\(battery)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(batteryColor(level: battery))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(batteryColor(level: battery).opacity(0.12))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "idle": return String(localized: "status.idle")
        case "cleaning": return String(localized: "status.cleaning")
        case "paused": return String(localized: "status.paused")
        case "returning": return String(localized: "status.returning")
        case "docked": return String(localized: "status.docked")
        case "error": return String(localized: "status.error")
        default: return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "cleaning": return .blue
        case "paused": return .orange
        case "returning": return .purple
        case "error": return .red
        default: return .green
        }
    }

    private func batteryIcon(level: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }

    // MARK: - Control Section
    @ViewBuilder
    private var controlSection: some View {
        Section {
            // Main control buttons - 3 buttons: Start/Pause (toggle), Stop, Home
            HStack(spacing: 12) {
                // Start/Pause toggle button
                if viewModel.isRunning {
                    // Show Pause when robot is running
                    ControlButton(
                        title: String(localized: "action.pause"),
                        icon: "pause.fill",
                        color: .orange
                    ) {
                        await viewModel.performAction(.pause)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Show Start/Resume when idle or paused
                    ControlButton(
                        title: viewModel.isPaused ? String(localized: "action.resume") : String(localized: "action.start"),
                        icon: "play.fill",
                        color: .green,
                        badge: "\(viewModel.selectedIterations)×"
                    ) {
                        await viewModel.performAction(.start)
                    } menu: {
                        ForEach(1...3, id: \.self) { count in
                            Button {
                                viewModel.selectedIterations = count
                            } label: {
                                HStack {
                                    Text(count == 1 ? String(localized: "iterations.single") : String(localized: "iterations.multiple \(count)"))
                                    if viewModel.selectedIterations == count {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ControlButton(title: String(localized: "action.stop"), icon: "stop.fill", color: .red) {
                    await viewModel.performAction(.stop)
                }
                .buttonStyle(.plain)

                ControlButton(title: String(localized: "action.home"), icon: "house.fill", color: .blue) {
                    await viewModel.performAction(.home)
                }
                .buttonStyle(.plain)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

            // Intensity Controls (Operation Mode, Fan Speed, Water Usage) - Always Centered
            if !viewModel.fanSpeedPresets.isEmpty || !viewModel.waterUsagePresets.isEmpty || !viewModel.operationModePresets.isEmpty {
                HStack(spacing: 8) {
                    Spacer()

                    // Operation Mode
                    if !viewModel.operationModePresets.isEmpty {
                        Menu {
                            ForEach(viewModel.operationModePresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setOperationMode(preset) }
                                } label: {
                                    HStack {
                                        Image(systemName: iconForOperationMode(preset))
                                        Text(displayNameForOperationMode(preset))
                                        if viewModel.currentOperationMode == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.currentOperationMode.map { iconForOperationMode($0) } ?? "gearshape")
                                    .font(.caption)
                                Text(viewModel.currentOperationMode.map { displayNameForOperationMode($0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                        }
                    }

                    // Fan Speed
                    if !viewModel.fanSpeedPresets.isEmpty {
                        Menu {
                            ForEach(viewModel.fanSpeedPresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setFanSpeed(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if viewModel.currentFanSpeed == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "fan")
                                    .font(.caption)
                                Text(viewModel.currentFanSpeed.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                    }

                    // Water Usage
                    if !viewModel.waterUsagePresets.isEmpty {
                        Menu {
                            ForEach(viewModel.waterUsagePresets, id: \.self) { preset in
                                Button {
                                    Task { await viewModel.setWaterUsage(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if viewModel.currentWaterUsage == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                Text(viewModel.currentWaterUsage.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundStyle(.cyan)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

            // Dock Actions (if available)
            if viewModel.hasAutoEmptyTrigger || viewModel.hasMopDockClean || viewModel.hasMopDockDry {
                HStack(spacing: 12) {
                    if viewModel.hasAutoEmptyTrigger {
                        DockActionButton(title: String(localized: "dock.empty"), icon: "arrow.up.bin", color: .purple) {
                            await viewModel.triggerAutoEmpty()
                        }
                    }
                    if viewModel.hasMopDockClean {
                        DockActionButton(title: String(localized: "dock.clean"), icon: "drop.triangle", color: .blue) {
                            await viewModel.triggerMopDockClean()
                        }
                    }
                    if viewModel.hasMopDockDry {
                        DockActionButton(title: String(localized: "dock.dry"), icon: "wind", color: .cyan) {
                            await viewModel.triggerMopDockDry()
                        }
                    }
                }
                .buttonStyle(.plain)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

        }
    }

    // MARK: - Live Stats Chip (under map, right aligned - battery style)
    @ViewBuilder
    private var liveStatsChip: some View {
        let isCleaning = viewModel.status?.statusValue?.lowercased() == "cleaning"
        let timeStat = viewModel.lastCleaningStats.first(where: { $0.statType == .time })
        let areaStat = viewModel.lastCleaningStats.first(where: { $0.statType == .area })

        HStack(spacing: 4) {
            // Live indicator when cleaning
            if isCleaning {
                Circle()
                    .fill(.red)
                    .frame(width: 5, height: 5)
                    .modifier(PulseAnimation())
            }

            // Time
            HStack(spacing: 1) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                Text(timeStat?.formattedTime ?? "--:--")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            Text("•")
                .font(.system(size: 8))
                .opacity(0.5)

            // Area
            HStack(spacing: 1) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 8))
                Text(areaStat?.formattedArea ?? "-- m²")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.12))
        .clipShape(Capsule())
    }
}

extension RobotDetailView {

    // MARK: - Attachment Status
    private var hasAnyAttachmentInfo: Bool {
        DebugConfig.showAllCapabilities || viewModel.status?.dustbinAttached != nil || viewModel.status?.mopAttached != nil || viewModel.status?.waterTankAttached != nil
    }

    // MARK: - Attachment Chips (battery style: colored content, matte background)
    @ViewBuilder
    private var attachmentChips: some View {
        // Dust bin
        let dustbinAttached = viewModel.status?.dustbinAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
        if let attached = dustbinAttached {
            attachmentChip(
                icon: "trash.fill",
                label: String(localized: "attachment.dustbin_short"),
                attached: attached
            )
        }

        // Water tank
        let waterTankAttached = viewModel.status?.waterTankAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
        if let attached = waterTankAttached {
            attachmentChip(
                icon: "drop.fill",
                label: String(localized: "attachment.watertank_short"),
                attached: attached
            )
        }

        // Mop
        let mopAttached = viewModel.status?.mopAttached ?? (DebugConfig.showAllCapabilities ? false : nil)
        if let attached = mopAttached {
            attachmentChip(
                icon: "rectangle.portrait.bottomhalf.filled",
                label: String(localized: "attachment.mop_short"),
                attached: attached
            )
        }
    }

    @ViewBuilder
    private func attachmentChip(icon: String, label: String, attached: Bool) -> some View {
        let color: Color = attached ? .green : .gray
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Consumables Section (Accordion)
    @ViewBuilder
    private var consumablesPreviewSection: some View {
        if !viewModel.consumables.isEmpty {
            Section {
                DisclosureGroup {
                    ForEach(viewModel.consumables) { consumable in
                        HStack(spacing: 12) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(consumable.iconColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: consumable.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(consumable.iconColor)
                            }

                            // Name & Progress
                            VStack(alignment: .leading, spacing: 4) {
                                Text(consumable.displayName)
                                    .font(.subheadline)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(consumable.iconColor)
                                            .frame(width: geometry.size.width * CGFloat(min(consumable.remainingPercent, 100)) / 100, height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }

                            // Value
                            Text(consumable.remainingDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(consumable.iconColor)
                                .frame(minWidth: 40, alignment: .trailing)

                            // Reset button
                            Button {
                                Task { await viewModel.resetConsumable(consumable) }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                } label: {
                    HStack {
                        Label(String(localized: "consumables.title"), systemImage: "wrench.and.screwdriver")
                        Spacer()
                        if viewModel.consumables.contains(where: { $0.remainingPercent < 20 }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Statistics Section (Accordion)
    @ViewBuilder
    private var statisticsSection: some View {
        Section {
            DisclosureGroup {
                // Last/Current cleaning stats
                if !viewModel.lastCleaningStats.isEmpty {
                    Text(String(localized: "stats.current"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(viewModel.lastCleaningStats) { stat in
                        statisticRow(stat: stat)
                    }
                }

                // Total stats
                if !viewModel.totalStats.isEmpty {
                    Text(String(localized: "stats.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    ForEach(viewModel.totalStats) { stat in
                        statisticRow(stat: stat)
                    }
                }

                // Debug fallback when no stats
                if viewModel.lastCleaningStats.isEmpty && viewModel.totalStats.isEmpty && DebugConfig.showAllCapabilities {
                    Text(String(localized: "stats.current"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(String(localized: "stats.time"))
                        Spacer()
                        Text("1:23:45")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text(String(localized: "stats.area"))
                        Spacer()
                        Text("87.5 m²")
                            .foregroundStyle(.secondary)
                    }

                    Text(String(localized: "stats.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(String(localized: "stats.time"))
                        Spacer()
                        Text("234:56:12")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text(String(localized: "stats.area"))
                        Spacer()
                        Text("4.523 m²")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text(String(localized: "stats.count"))
                        Spacer()
                        Text("127")
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label(String(localized: "stats.title"), systemImage: "chart.bar")
            }
        }
    }

    @ViewBuilder
    private func statisticRow(stat: StatisticEntry) -> some View {
        HStack {
            Image(systemName: iconForStatType(stat.statType))
                .foregroundStyle(colorForStatType(stat.statType))
                .frame(width: 24)
            Text(labelForStatType(stat.statType, fallback: stat.type))
            Spacer()
            Text(formattedValue(for: stat))
                .foregroundStyle(.secondary)
        }
    }

    private func iconForStatType(_ type: StatisticEntry.StatType?) -> String {
        switch type {
        case .time: return "clock"
        case .area: return "square.dashed"
        case .count: return "number"
        case .none: return "questionmark"
        }
    }

    private func colorForStatType(_ type: StatisticEntry.StatType?) -> Color {
        switch type {
        case .time: return .blue
        case .area: return .green
        case .count: return .orange
        case .none: return .gray
        }
    }

    private func labelForStatType(_ type: StatisticEntry.StatType?, fallback: String) -> String {
        switch type {
        case .time: return String(localized: "stats.time")
        case .area: return String(localized: "stats.area")
        case .count: return String(localized: "stats.count")
        case .none: return fallback
        }
    }

    private func formattedValue(for stat: StatisticEntry) -> String {
        switch stat.statType {
        case .time: return stat.formattedTime
        case .area: return stat.formattedArea
        case .count: return stat.formattedCount
        case .none: return String(Int(stat.value))
        }
    }

    // MARK: - Rooms Section (Accordion)
    @ViewBuilder
    private var roomsSection: some View {
        if !viewModel.segments.isEmpty {
            Section {
                DisclosureGroup {
                    ForEach(viewModel.segments) { segment in
                        Button {
                            viewModel.toggleSegment(segment.id)
                        } label: {
                            HStack {
                                Text(segment.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedSegments.contains(segment.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label(String(localized: "rooms.title"), systemImage: "square.grid.2x2")
                        Spacer()
                        if !viewModel.selectedSegments.isEmpty {
                            Text("\(viewModel.selectedSegments.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Clean button with iterations picker - visible when rooms are selected
                if !viewModel.selectedSegments.isEmpty {
                    HStack(spacing: 8) {
                        // Clean button
                        Button {
                            Task { await viewModel.cleanSelectedRooms() }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(String(localized: "rooms.clean_selected"))
                            }
                            .foregroundStyle(.green)
                        }

                        // Iterations picker (after clean text)
                        Menu {
                            ForEach(1...3, id: \.self) { count in
                                Button {
                                    viewModel.selectedIterations = count
                                } label: {
                                    HStack {
                                        Text("\(count)×")
                                        if viewModel.selectedIterations == count {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                Text("\(viewModel.selectedIterations)×")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        }

                        Spacer()

                        // Room count badge
                        Text("\(viewModel.selectedSegments.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    // MARK: - Events Section
    @ViewBuilder
    private var eventsSection: some View {
        if viewModel.hasEvents && !viewModel.events.isEmpty {
            Section {
                ForEach(viewModel.events) { event in
                    HStack {
                        Image(systemName: event.iconName)
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let message = event.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.timestamp)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if !event.processed {
                            Button {
                                Task { await viewModel.dismissEvent(event) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text(String(localized: "detail.events"))
            }
        }
    }

    // MARK: - Clean Route Section
    @ViewBuilder
    private var cleanRouteSection: some View {
        if viewModel.hasCleanRoute && !viewModel.cleanRoutePresets.isEmpty {
            Section {
                Picker(String(localized: "detail.clean_route"), selection: Binding(
                    get: { viewModel.currentCleanRoute },
                    set: { newValue in
                        Task { await viewModel.setCleanRoute(newValue) }
                    }
                )) {
                    ForEach(viewModel.cleanRoutePresets, id: \.self) { preset in
                        Text(preset.capitalized).tag(preset)
                    }
                }
            } header: {
                Text(String(localized: "detail.clean_route"))
            }
        }
    }

    // MARK: - Obstacles Section
    @ViewBuilder
    private var obstaclesSection: some View {
        if viewModel.hasObstacleImages && !viewModel.obstacles.isEmpty {
            Section {
                ForEach(viewModel.obstacles, id: \.id) { obstacle in
                    NavigationLink {
                        if let api = viewModel.api {
                            ObstaclePhotoView(obstacleId: obstacle.id, label: obstacle.label, api: api)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text(obstacle.label ?? String(localized: "obstacle.unknown"))
                                .font(.subheadline)
                        }
                    }
                }
            } header: {
                Text(String(localized: "detail.obstacles"))
            }
        }
    }

    private func displayNameForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return String(localized: "mode.vacuum")
        case "mop": return String(localized: "mode.mop")
        case "vacuum_and_mop": return String(localized: "mode.vacuum_and_mop")
        case "vacuum_then_mop": return String(localized: "mode.vacuum_then_mop")
        default: return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func iconForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return "tornado"
        case "mop": return "drop.fill"
        case "vacuum_and_mop", "vacuum_then_mop": return "sparkles"
        default: return "gearshape"
        }
    }
}

#Preview {
    NavigationStack {
        RobotDetailView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"), robotManager: RobotManager())
    }
}
