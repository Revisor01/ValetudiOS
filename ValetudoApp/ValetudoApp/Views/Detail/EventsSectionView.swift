import SwiftUI

struct EventsSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
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
}
