import SwiftUI

struct RoomsSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
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
                                if let index = viewModel.selectedSegments.firstIndex(of: segment.id) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 24, height: 24)
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
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
}
