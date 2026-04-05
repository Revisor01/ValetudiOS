import SwiftUI

struct UpdateOverlayView: View {
    let viewModel: RobotDetailViewModel

    private var title: String {
        if case .rebooting = viewModel.updateService?.phase {
            return String(localized: "update.rebooting_title")
        }
        return String(localized: "update.applying_title")
    }

    private var subtitle: String {
        if case .rebooting = viewModel.updateService?.phase {
            return String(localized: "update.rebooting_hint")
        }
        return String(localized: "update.applying_hint")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }
}
