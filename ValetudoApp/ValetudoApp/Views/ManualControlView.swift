import SwiftUI
import os

struct ManualControlView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "ManualControlView")
    let robot: RobotConfig
    @Environment(RobotManager.self) var robotManager

    @State private var isEnabled = false
    @State private var useHighRes = false
    @State private var touchOffset: CGSize = .zero
    @State private var isTouching = false
    @State private var heartbeatTask: Task<Void, Never>? = nil

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    // Touchpad size
    private let padSize: CGFloat = 280
    private let maxOffset: CGFloat = 100

    // RC-Car steering: joystick direction = where the robot goes
    // Y-axis (up/down) = forward/backward speed
    // X-axis (left/right) = steering direction (not pure rotation)
    //
    // When pushing straight up: velocity=1, angle=0 (forward)
    // When pushing left: velocity is low, angle is high (tight turn left)
    // When pushing diagonal up-left: velocity is high, angle moderate (drive + steer)
    // This feels like walking behind the robot and steering it

    private var velocityNormalized: Double {
        let normalizedY = -touchOffset.height / maxOffset  // up = positive = forward
        return max(-1, min(1, normalizedY))
    }

    private var angleNormalized: Double {
        let normalizedX = touchOffset.width / maxOffset  // right = positive
        let normalizedY = -touchOffset.height / maxOffset

        // Angle scales with X offset, but also consider the "intent":
        // - Pure horizontal (Y≈0): full rotation (±120°) for on-the-spot turning
        // - Diagonal (Y strong): moderate angle for steering while driving
        let absY = abs(normalizedY)
        let absX = abs(normalizedX)

        // Dead-zone: if barely touching, no angle
        guard absX > 0.05 else { return 0 }

        // Base angle from X position (0..120°)
        let baseAngle = normalizedX * 120.0

        // When driving forward/backward (high Y), reduce angle for smoother steering
        // When stationary (low Y), allow full rotation
        let steeringFactor = absY > 0.3 ? (1.0 - absY * 0.5) : 1.0

        return max(-120, min(120, -baseAngle * steeringFactor))
    }

    // Display values for UI
    private var velocity: Int {
        Int(velocityNormalized * 100)
    }

    private var angle: Int {
        Int(angleNormalized)
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isTouching ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                Text(isTouching ? String(localized: "manual.active") : String(localized: "manual.ready"))
                    .font(.subheadline)
                    .foregroundStyle(isTouching ? .primary : .secondary)
            }

            // Touchpad
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 40)
                    .fill(Color(.systemGray6))
                    .frame(width: padSize, height: padSize)

                // Direction indicators (subtle)
                VStack {
                    Image(systemName: "chevron.up")
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.tertiary)
                }
                .frame(height: padSize - 60)

                HStack {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .frame(width: padSize - 60)

                // Center dot (resting position)
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)

                // Touch indicator (follows finger)
                Circle()
                    .fill(isTouching ? Color.blue : Color.blue.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .shadow(color: isTouching ? .blue.opacity(0.4) : .clear, radius: 10)
                    .offset(touchOffset)
                    .animation(.interactiveSpring(response: 0.15), value: touchOffset)
            }
            .frame(width: padSize, height: padSize)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Clamp offset to maxOffset
                        let x = max(-maxOffset, min(maxOffset, value.translation.width))
                        let y = max(-maxOffset, min(maxOffset, value.translation.height))
                        touchOffset = CGSize(width: x, height: y)

                        if !isTouching {
                            isTouching = true
                            // Start heartbeat: send move commands every 500ms while touching.
                            // Valetudo auto-disables manual control if no move command arrives
                            // within its watchdog window (~1-2s), so we must send continuously.
                            heartbeatTask = Task {
                                while !Task.isCancelled {
                                    await sendMovement()
                                    try? await Task.sleep(nanoseconds: 150_000_000)
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        // Cancel heartbeat first, then stop
                        heartbeatTask?.cancel()
                        heartbeatTask = nil
                        // Reset and stop
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            touchOffset = .zero
                        }
                        isTouching = false
                        Task {
                            await stopMovement()
                        }
                    }
            )

            // Speed indicator
            if isTouching {
                VStack(spacing: 4) {
                    Text("v: \(velocity) • ∠: \(angle)°")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            Spacer()

            // Instructions
            Text(String(localized: "manual.touchpad_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom)
        }
        .navigationTitle(String(localized: "manual.title"))
        .task {
            await checkCapabilities()
            await enableManualControl()
        }
        .onDisappear {
            Task {
                await disableManualControl()
            }
        }
    }

    private func checkCapabilities() async {
        guard let api = api else { return }
        do {
            let capabilities = try await api.getCapabilities()
            useHighRes = capabilities.contains("HighResolutionManualControlCapability")
            logger.info("ManualControl capability check: useHighRes=\(useHighRes, privacy: .public), capabilities=\(capabilities.joined(separator: ","), privacy: .public)")
        } catch {
            logger.error("Failed to check capabilities: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enableManualControl() async {
        guard let api = api else { return }
        do {
            logger.info("Enabling manual control (useHighRes=\(useHighRes, privacy: .public))")
            if useHighRes {
                try await api.enableHighResManualControl()
            } else {
                try await api.enableManualControl()
            }
            isEnabled = true
            logger.info("Manual control enabled successfully")
        } catch {
            logger.error("Failed to enable manual control: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func disableManualControl() async {
        guard let api = api, isEnabled else { return }
        do {
            if useHighRes {
                try await api.disableHighResManualControl()
            } else {
                try await api.disableManualControl()
            }
            isEnabled = false
        } catch {
            logger.error("Failed to disable manual control: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func sendMovement() async {
        guard let api = api else {
            logger.warning("sendMovement: api is nil, skipping")
            return
        }
        guard isEnabled else {
            logger.warning("sendMovement: isEnabled=false, skipping (enable may still be in progress)")
            return
        }

        do {
            if useHighRes {
                logger.info("sendMovement: highRes velocity=\(velocityNormalized, privacy: .public) angle=\(angleNormalized, privacy: .public)")
                try await api.highResManualControl(velocity: velocityNormalized, angle: angleNormalized)
            } else {
                // Fallback for regular ManualControl - determine direction
                let movementCommand: String
                if abs(touchOffset.height) > abs(touchOffset.width) {
                    movementCommand = touchOffset.height < 0 ? "forward" : "backward"
                } else if abs(touchOffset.width) > 20 {
                    movementCommand = touchOffset.width < 0 ? "rotate_counterclockwise" : "rotate_clockwise"
                } else {
                    logger.info("sendMovement: standard, offset too small, skipping")
                    return
                }
                logger.info("sendMovement: standard movementCommand=\(movementCommand, privacy: .public)")
                try await api.manualControl(movementCommand: movementCommand)
            }
        } catch {
            logger.error("Movement failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopMovement() async {
        guard let api = api else { return }

        do {
            if useHighRes {
                try await api.highResManualControl(velocity: 0.0, angle: 0.0)
            }
            // Standard ManualControl: no "stop" movementCommand exists in Valetudo.
            // Valid commands are only: forward, backward, rotate_clockwise, rotate_counterclockwise.
            // The robot stops on its own after the last discrete command — just cancel the
            // heartbeat task (done in onEnded before calling here) and do nothing else.
        } catch {
            logger.error("Stop failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    NavigationStack {
        ManualControlView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environment(RobotManager())
    }
}
