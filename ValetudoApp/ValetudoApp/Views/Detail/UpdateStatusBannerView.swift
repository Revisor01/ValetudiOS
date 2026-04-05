import SwiftUI

struct UpdateStatusBannerView: View {
    let viewModel: RobotDetailViewModel
    @Binding var showUpdateWarning: Bool

    var body: some View {
        if case .updateAvailable = viewModel.updateService?.phase {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(String(localized: "update.available"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(viewModel.updateService?.currentVersion ?? "?") → \(viewModel.updateService?.latestVersion ?? "?")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // GitHub release link
                        if let urlStr = viewModel.updateService?.updateUrl, let releaseURL = URL(string: urlStr) {
                            Link(destination: releaseURL) {
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        showUpdateWarning = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.to.line")
                            Text(String(localized: "update.install"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        } else if case .downloading = viewModel.updateService?.phase {
            Section {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.updateService?.downloadProgress ?? 0.0)
                        .progressViewStyle(.linear)
                        .tint(.orange)
                    HStack {
                        Text(String(localized: "update.downloading"))
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int((viewModel.updateService?.downloadProgress ?? 0.0) * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    Text(String(localized: "update.do_not_disconnect"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else if case .readyToApply = viewModel.updateService?.phase {
            Section {
                Button {
                    showUpdateWarning = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "update.apply"))
                        Spacer()
                    }
                }
            }
        } else if viewModel.updateInProgress {
            Section {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(String(localized: "update.in_progress"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(String(localized: "update.in_progress_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        } else if case .error(let message) = viewModel.updateService?.phase {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading) {
                            Text(String(localized: "update.error"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Button {
                        viewModel.updateService?.reset()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "update.retry"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        } else if let currentVersion = viewModel.updateService?.currentVersion,
                  let latestVersion = viewModel.updateService?.latestVersion,
                  currentVersion != latestVersion,
                  let updateUrl = viewModel.updateService?.updateUrl {
            Section {
                if let url = URL(string: updateUrl) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.available"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(currentVersion) → \(latestVersion)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
