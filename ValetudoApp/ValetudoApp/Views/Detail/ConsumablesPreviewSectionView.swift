import SwiftUI

struct ConsumablesPreviewSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
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
}
