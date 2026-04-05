import SwiftUI

// MARK: - MapContentView Drawing & Gesture Extensions
extension MapContentView {

    // MARK: - Coordinate Transformation

    /// Convert screen coordinates to map coordinates (accounting for zoom/pan)
    func screenToMapCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - offset.width - viewSize.width / 2) / scale + viewSize.width / 2,
            y: (point.y - offset.height - viewSize.height / 2) / scale + viewSize.height / 2
        )
    }

    /// Convert map coordinates to screen coordinates (accounting for zoom/pan)
    func mapToScreenCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - viewSize.width / 2) * scale + viewSize.width / 2 + offset.width,
            y: (point.y - viewSize.height / 2) * scale + viewSize.height / 2 + offset.height
        )
    }

    // MARK: - Drawing Overlay

    @ViewBuilder
    func drawingOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Convert screen coordinates to map coordinates
                        let mapStart = screenToMapCoords(value.startLocation, viewSize: geometry.size)
                        let mapEnd = screenToMapCoords(value.location, viewSize: geometry.size)

                        // For goTo/savePreset: always update to new tap position
                        // For other modes: only set start once (for drag drawing)
                        if viewModel.editMode == .goTo || viewModel.editMode == .savePreset {
                            currentDrawStart = mapStart
                        } else if currentDrawStart == nil {
                            currentDrawStart = mapStart
                        }
                        currentDrawEnd = mapEnd
                    }
                    .onEnded { _ in
                        finishDrawing(in: geometry.size)
                    }
            )
    }

    // MARK: - Split Line Handles

    @ViewBuilder
    func splitLineHandles(geometry: GeometryProxy) -> some View {
        let viewSize = geometry.size

        ZStack {
            // Tap area to draw new line (resets existing)
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let mapStart = screenToMapCoords(value.startLocation, viewSize: viewSize)
                            let mapEnd = screenToMapCoords(value.location, viewSize: viewSize)

                            if currentDrawStart == nil || (currentDrawStart != nil && currentDrawEnd != nil && !isDraggingSplitStart && !isDraggingSplitEnd) {
                                // Start new line
                                currentDrawStart = mapStart
                                currentDrawEnd = mapEnd
                            } else {
                                currentDrawEnd = mapEnd
                            }
                        }
                        .onEnded { _ in
                            // Line drawn, handles will appear
                        }
                )

            // Start handle (converted to screen coords for display)
            if let start = currentDrawStart {
                let screenStart = mapToScreenCoords(start, viewSize: viewSize)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(radius: 3)
                    .position(screenStart)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingSplitStart = true
                                currentDrawStart = screenToMapCoords(value.location, viewSize: viewSize)
                            }
                            .onEnded { _ in
                                isDraggingSplitStart = false
                            }
                    )
            }

            // End handle (converted to screen coords for display)
            if let end = currentDrawEnd {
                let screenEnd = mapToScreenCoords(end, viewSize: viewSize)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(radius: 3)
                    .position(screenEnd)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingSplitEnd = true
                                currentDrawEnd = screenToMapCoords(value.location, viewSize: viewSize)
                            }
                            .onEnded { _ in
                                isDraggingSplitEnd = false
                            }
                    )
            }

            // Draw the line preview (converted to screen coords)
            if let start = currentDrawStart, let end = currentDrawEnd {
                let screenStart = mapToScreenCoords(start, viewSize: viewSize)
                let screenEnd = mapToScreenCoords(end, viewSize: viewSize)
                Path { path in
                    path.move(to: screenStart)
                    path.addLine(to: screenEnd)
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            }
        }
    }

    // MARK: - Finish Drawing

    func finishDrawing(in size: CGSize) {
        guard let start = currentDrawStart, let end = currentDrawEnd else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        guard let map = viewModel.map, let layers = map.layers else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        let pixelSize = map.pixelSize ?? 5
        guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        // start/end are already in map coordinates (from screenToMapCoords in drawingOverlay)
        // We just need to convert from map view coordinates to pixel coordinates
        let pixelStartX = Int(((start.x - params.offsetX) / params.scale).rounded())
        let pixelStartY = Int(((start.y - params.offsetY) / params.scale).rounded())
        let pixelEndX = Int(((end.x - params.offsetX) / params.scale).rounded())
        let pixelEndY = Int(((end.y - params.offsetY) / params.scale).rounded())

        // API coordinates are pixel coordinates multiplied by pixelSize
        let apiStartX = pixelStartX * pixelSize
        let apiStartY = pixelStartY * pixelSize
        let apiEndX = pixelEndX * pixelSize
        let apiEndY = pixelEndY * pixelSize

        let minX = min(apiStartX, apiEndX)
        let maxX = max(apiStartX, apiEndX)
        let minY = min(apiStartY, apiEndY)
        let maxY = max(apiStartY, apiEndY)

        switch viewModel.editMode {
        case .zone:
            let zone = CleaningZone(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnZones.append(zone)

        case .noGoArea:
            let area = NoGoArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnNoGoAreas.append(area)

        case .noMopArea:
            let area = NoMopArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            viewModel.drawnNoMopAreas.append(area)

        case .virtualWall:
            let wall = VirtualWall(
                points: VirtualWallPoints(
                    pA: ZonePoint(x: apiStartX, y: apiStartY),
                    pB: ZonePoint(x: apiEndX, y: apiEndY)
                )
            )
            viewModel.drawnVirtualWalls.append(wall)

        case .goTo:
            // Tap places/moves marker to new position
            viewModel.goToMarkerPosition = start
            viewModel.goToApiCoords = (x: apiStartX, y: apiStartY)
            viewModel.showGoToConfirm = true
            return

        case .savePreset:
            // Tap places/moves marker to new position
            viewModel.goToMarkerPosition = start
            viewModel.pendingGoToX = apiStartX
            viewModel.pendingGoToY = apiStartY
            return

        case .splitRoom:
            // Split line drawing is handled, don't clear yet
            return

        case .roomEdit, .deleteRestriction, .none:
            break
        }

        currentDrawStart = nil
        currentDrawEnd = nil
    }

    // MARK: - Combined Gesture

    var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                    scale = max(0.5, min(8.0, scale))
                }
                .onEnded { _ in
                    lastScale = scale
                },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }
}
