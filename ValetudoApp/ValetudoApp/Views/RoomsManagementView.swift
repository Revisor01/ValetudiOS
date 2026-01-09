import SwiftUI

struct RoomsManagementView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var segments: [Segment] = []
    @State private var isLoading = false
    @State private var editingSegment: Segment?
    @State private var newName = ""
    @State private var showRenameSheet = false

    // Capabilities
    @State private var hasSegmentRename = false
    @State private var hasSegmentEdit = false
    @State private var hasSegmentMaterial = false
    @State private var supportedMaterials: [String] = []

    // Material editing
    @State private var showMaterialSheet = false
    @State private var materialSegment: Segment?

    // Join segments
    @State private var showJoinSheet = false
    @State private var selectedSegmentsToJoin: Set<String> = []

    // Split segment
    @State private var showSplitSheet = false
    @State private var segmentToSplit: Segment?

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if segments.isEmpty && !isLoading {
                Section {
                    Text(String(localized: "rooms.empty"))
                        .foregroundStyle(.secondary)
                }
            } else {
                // Segment Edit Section
                if hasSegmentEdit && segments.count >= 2 {
                    Section {
                        Button {
                            showJoinSheet = true
                        } label: {
                            Label(String(localized: "rooms.join"), systemImage: "arrow.triangle.merge")
                        }

                        Button {
                            showSplitSheet = true
                        } label: {
                            Label(String(localized: "rooms.split"), systemImage: "scissors")
                        }
                    } header: {
                        Label(String(localized: "rooms.edit"), systemImage: "square.and.pencil")
                    } footer: {
                        Text(String(localized: "rooms.edit_hint"))
                    }
                }

                Section {
                    ForEach(segments) { segment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.displayName)
                                    .font(.body)
                                Text("ID: \(segment.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if hasSegmentMaterial {
                                Button {
                                    materialSegment = segment
                                    showMaterialSheet = true
                                } label: {
                                    Image(systemName: "square.fill.on.square.fill")
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }

                            if hasSegmentRename {
                                Button {
                                    editingSegment = segment
                                    newName = segment.name ?? ""
                                    showRenameSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Label(String(localized: "rooms.title"), systemImage: "square.split.2x2")
                } footer: {
                    if hasSegmentRename || hasSegmentMaterial {
                        Text(String(localized: "rooms.edit_actions_hint"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "rooms.manage"))
        .task {
            await loadCapabilities()
            await loadSegments()
        }
        .refreshable {
            await loadSegments()
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSegmentSheet(
                segment: editingSegment,
                newName: $newName,
                onRename: {
                    if let segment = editingSegment {
                        await renameSegment(segment)
                    }
                },
                onCancel: {
                    editingSegment = nil
                    newName = ""
                }
            )
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinSegmentsSheet(
                segments: segments,
                selectedIds: $selectedSegmentsToJoin,
                onJoin: { await joinSelectedSegments() }
            )
        }
        .sheet(isPresented: $showSplitSheet) {
            SplitSegmentSheet(
                robot: robot,
                segments: segments,
                onSplit: { segmentId, pointA, pointB in
                    await splitSegment(segmentId: segmentId, pointA: pointA, pointB: pointB)
                }
            )
        }
        .sheet(isPresented: $showMaterialSheet) {
            if let segment = materialSegment {
                SegmentMaterialSheet(
                    segment: segment,
                    supportedMaterials: supportedMaterials,
                    onSetMaterial: { material in
                        await setSegmentMaterial(segment: segment, material: material)
                    }
                )
            }
        }
        .overlay {
            if isLoading && segments.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadCapabilities() async {
        guard let api = api else { return }
        do {
            let capabilities = try await api.getCapabilities()
            await MainActor.run {
                hasSegmentRename = capabilities.contains("MapSegmentRenameCapability")
                hasSegmentEdit = capabilities.contains("MapSegmentEditCapability")
                hasSegmentMaterial = capabilities.contains("MapSegmentMaterialControlCapability")
            }

            // Load supported materials if capability exists
            if hasSegmentMaterial {
                do {
                    let props = try await api.getSegmentMaterialProperties()
                    await MainActor.run {
                        supportedMaterials = props.supportedMaterials
                    }
                } catch {
                    print("Failed to load material properties: \(error)")
                }
            }
        } catch {
            print("Failed to load capabilities: \(error)")
        }
    }

    private func setSegmentMaterial(segment: Segment, material: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setSegmentMaterial(segmentId: segment.id, material: material)
            showMaterialSheet = false
            materialSegment = nil
        } catch {
            print("Failed to set segment material: \(error)")
        }
    }

    private func loadSegments() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            segments = try await api.getSegments()
        } catch {
            print("Failed to load segments: \(error)")
        }
    }

    private func renameSegment(_ segment: Segment) async {
        guard let api = api, !newName.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.renameSegment(id: segment.id, name: newName)
            await loadSegments()
        } catch {
            print("Failed to rename segment: \(error)")
        }

        editingSegment = nil
        newName = ""
    }

    private func joinSelectedSegments() async {
        guard let api = api, selectedSegmentsToJoin.count == 2 else { return }
        isLoading = true
        defer { isLoading = false }

        let ids = Array(selectedSegmentsToJoin)
        do {
            try await api.joinSegments(segmentAId: ids[0], segmentBId: ids[1])
            selectedSegmentsToJoin.removeAll()
            showJoinSheet = false
            await loadSegments()
        } catch {
            print("Failed to join segments: \(error)")
        }
    }

    private func splitSegment(segmentId: String, pointA: ZonePoint, pointB: ZonePoint) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.splitSegment(segmentId: segmentId, pointA: pointA, pointB: pointB)
            showSplitSheet = false
            await loadSegments()
        } catch {
            print("Failed to split segment: \(error)")
        }
    }
}

// MARK: - Rename Segment Sheet
struct RenameSegmentSheet: View {
    let segment: Segment?
    @Binding var newName: String
    let onRename: () async -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "rooms.new_name"), text: $newName)
                        .focused($isNameFocused)
                        .autocorrectionDisabled()
                } header: {
                    if let segment = segment {
                        Text(String(localized: "rooms.rename_message \(segment.displayName)"))
                    }
                }
            }
            .navigationTitle(String(localized: "rooms.rename"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        Task {
                            await onRename()
                            dismiss()
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Join Segments Sheet
struct JoinSegmentsSheet: View {
    let segments: [Segment]
    @Binding var selectedIds: Set<String>
    let onJoin: () async -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(segments) { segment in
                        Button {
                            toggleSelection(segment.id)
                        } label: {
                            HStack {
                                Text(segment.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIds.contains(segment.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(String(localized: "rooms.join_hint"))
                }
            }
            .navigationTitle(String(localized: "rooms.join"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "rooms.join_action")) {
                        Task { await onJoin() }
                    }
                    .disabled(selectedIds.count != 2)
                }
            }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else if selectedIds.count < 2 {
            selectedIds.insert(id)
        } else {
            // Replace the first selected with the new one
            selectedIds.removeFirst()
            selectedIds.insert(id)
        }
    }
}

// MARK: - Split Segment Sheet
struct SplitSegmentSheet: View {
    let robot: RobotConfig
    let segments: [Segment]
    let onSplit: (String, ZonePoint, ZonePoint) async -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var robotManager: RobotManager

    @State private var selectedSegmentId: String?
    @State private var map: RobotMap?
    @State private var isLoading = true
    @State private var splitStart: CGPoint?
    @State private var splitEnd: CGPoint?
    @State private var viewSize: CGSize = .zero

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker(String(localized: "rooms.select_room"), selection: $selectedSegmentId) {
                    Text(String(localized: "rooms.select_room")).tag(nil as String?)
                    ForEach(segments) { segment in
                        Text(segment.displayName).tag(segment.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .padding()

                // Map with drawing
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let map = map {
                    GeometryReader { geometry in
                        ZStack {
                            SplitMapView(
                                map: map,
                                selectedSegmentId: selectedSegmentId,
                                splitStart: splitStart,
                                splitEnd: splitEnd,
                                viewSize: geometry.size
                            )

                            // Drawing overlay
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if splitStart == nil {
                                                splitStart = value.startLocation
                                            }
                                            splitEnd = value.location
                                        }
                                )
                        }
                        .onAppear {
                            viewSize = geometry.size
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            viewSize = newSize
                        }
                    }
                } else {
                    Spacer()
                    Text(String(localized: "map.unavailable"))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Instructions
                Text(String(localized: "rooms.split_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .navigationTitle(String(localized: "rooms.split"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "rooms.split_action")) {
                        Task { await performSplit() }
                    }
                    .disabled(selectedSegmentId == nil || splitStart == nil || splitEnd == nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        splitStart = nil
                        splitEnd = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .disabled(splitStart == nil)
                }
            }
            .task {
                await loadMap()
            }
        }
    }

    private func loadMap() async {
        guard let api = api else {
            isLoading = false
            return
        }
        do {
            map = try await api.getMap()
        } catch {
            print("Failed to load map: \(error)")
        }
        isLoading = false
    }

    private func performSplit() async {
        guard let segmentId = selectedSegmentId,
              let start = splitStart,
              let end = splitEnd,
              let map = map,
              let layers = map.layers,
              viewSize.width > 0, viewSize.height > 0 else { return }

        let pixelSize = map.pixelSize ?? 5

        // Calculate map params
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return }

        // Use actual view size from GeometryReader
        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = viewSize.width - padding * 2
        let availableHeight = viewSize.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        // Convert screen to map coordinates
        let pointA = ZonePoint(
            x: Int((start.x - offsetX) / scale),
            y: Int((start.y - offsetY) / scale)
        )
        let pointB = ZonePoint(
            x: Int((end.x - offsetX) / scale),
            y: Int((end.y - offsetY) / scale)
        )

        await onSplit(segmentId, pointA, pointB)
    }
}

// MARK: - Split Map View
struct SplitMapView: View {
    let map: RobotMap
    let selectedSegmentId: String?
    let splitStart: CGPoint?
    let splitEnd: CGPoint?
    let viewSize: CGSize

    var body: some View {
        Canvas { context, size in
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else { return }

            guard let params = calculateParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

            // Draw floor
            for layer in layers where layer.type == "floor" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }
                drawPixels(context: context, pixels: pixels, color: Color(white: 0.92), params: params, pixelSize: pixelSize)
            }

            // Draw segments
            for layer in layers where layer.type == "segment" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }
                let segmentId = layer.metaData?.segmentId
                let isSelected = segmentId == selectedSegmentId
                let color: Color = isSelected ? .orange.opacity(0.6) : Color(white: 0.85)
                drawPixels(context: context, pixels: pixels, color: color, params: params, pixelSize: pixelSize)
            }

            // Draw walls
            for layer in layers where layer.type == "wall" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }
                drawPixels(context: context, pixels: pixels, color: Color(white: 0.25), params: params, pixelSize: pixelSize)
            }

            // Draw split line
            if let start = splitStart, let end = splitEnd {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            }
        }
        .background(Color(.systemGray6))
    }

    private func calculateParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    private func drawPixels(context: GraphicsContext, pixels: [Int], color: Color, params: MapParams, pixelSize: Int) {
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)
            context.fill(Path(rect), with: .color(color))
            i += 2
        }
    }
}

// MARK: - Segment Material Sheet
struct SegmentMaterialSheet: View {
    let segment: Segment
    let supportedMaterials: [String]
    let onSetMaterial: (String) async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedMaterial: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(supportedMaterials, id: \.self) { material in
                        Button {
                            selectedMaterial = material
                        } label: {
                            HStack {
                                Image(systemName: FloorMaterial(rawValue: material)?.icon ?? "square.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                Text(FloorMaterial(rawValue: material)?.displayName ?? material)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedMaterial == material {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "material.select"))
                } footer: {
                    Text(String(localized: "material.hint"))
                }
            }
            .navigationTitle(segment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        if let material = selectedMaterial {
                            Task {
                                await onSetMaterial(material)
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedMaterial == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RoomsManagementView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
