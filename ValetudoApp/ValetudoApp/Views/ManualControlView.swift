import SwiftUI

struct ManualControlView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var isEnabled = false
    @State private var useHighRes = false
    @State private var touchOffset: CGSize = .zero
    @State private var isTouching = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    // Touchpad size
    private let padSize: CGFloat = 280
    private let maxOffset: CGFloat = 100

    // Calculate velocity and angle from touch offset
    private var velocity: Int {
        let normalizedY = -touchOffset.height / maxOffset  // Negative because up = forward
        return Int(max(-300, min(300, normalizedY * 300)))
    }

    private var angle: Int {
        let normalizedX = touchOffset.width / maxOffset
        return Int(max(-90, min(90, -normalizedX * 90)))  // Negative for correct rotation direction
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
                        }

                        // Send movement command
                        Task {
                            await sendMovement()
                        }
                    }
                    .onEnded { _ in
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
        } catch {
            print("Failed to check capabilities: \(error)")
        }
    }

    private func enableManualControl() async {
        guard let api = api else { return }
        do {
            if useHighRes {
                try await api.enableHighResManualControl()
            }
            isEnabled = true
        } catch {
            print("Failed to enable manual control: \(error)")
        }
    }

    private func disableManualControl() async {
        guard let api = api, isEnabled else { return }
        do {
            if useHighRes {
                try await api.disableHighResManualControl()
            }
            isEnabled = false
        } catch {
            print("Failed to disable manual control: \(error)")
        }
    }

    @MainActor
    private func sendMovement() async {
        guard let api = api, isEnabled else { return }

        do {
            if useHighRes {
                try await api.highResManualControl(velocity: velocity, angle: angle)
            } else {
                // Fallback for regular ManualControl - determine direction
                let direction: String
                if abs(touchOffset.height) > abs(touchOffset.width) {
                    direction = touchOffset.height < 0 ? "forward" : "backward"
                } else if abs(touchOffset.width) > 20 {
                    direction = touchOffset.width < 0 ? "rotate_counterclockwise" : "rotate_clockwise"
                } else {
                    return
                }
                try await api.manualControl(action: direction, movementSpeed: 100)
            }
        } catch {
            print("Movement failed: \(error)")
        }
    }

    private func stopMovement() async {
        guard let api = api else { return }

        do {
            if useHighRes {
                try await api.highResManualControl(velocity: 0, angle: 0)
            } else {
                try await api.manualControl(action: "stop")
            }
        } catch {
            print("Stop failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ManualControlView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
