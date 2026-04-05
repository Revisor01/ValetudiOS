import SwiftUI

struct StatisticsSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
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
}
