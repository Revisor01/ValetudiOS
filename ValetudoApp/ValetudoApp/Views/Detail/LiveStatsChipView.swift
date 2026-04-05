import SwiftUI

struct LiveStatsChipView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
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
