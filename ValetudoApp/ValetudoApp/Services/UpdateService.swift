import Foundation
import os

// MARK: - UpdatePhase

enum UpdatePhase: Equatable {
    case idle
    case checking
    case updateAvailable
    case downloading
    case readyToApply
    case applying
    case rebooting
    case error(String)

    static func == (lhs: UpdatePhase, rhs: UpdatePhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking),
             (.updateAvailable, .updateAvailable), (.downloading, .downloading),
             (.readyToApply, .readyToApply), (.applying, .applying),
             (.rebooting, .rebooting):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - UpdateService

@MainActor
class UpdateService: ObservableObject {

    @Published private(set) var phase: UpdatePhase = .idle
    @Published private(set) var currentVersion: String?
    @Published private(set) var latestVersion: String?
    @Published private(set) var updateUrl: String?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "UpdateService")
    private let api: ValetudoAPI
    private var pollingTask: Task<Void, Never>?

    init(api: ValetudoAPI) {
        self.api = api
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Public Actions

    func loadVersionInfo() async {
        // Load current Valetudo version
        if let version = try? await api.getValetudoVersion() {
            currentVersion = version.release
        }

        // Load latest GitHub release
        guard let url = URL(string: Constants.githubApiLatestReleaseUrl) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = release.tag_name
            updateUrl = release.html_url
        } catch {
            logger.error("loadVersionInfo GitHub fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates() async {
        guard case .idle = phase else {
            logger.warning("checkForUpdates called in non-idle phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        phase = .checking

        do {
            try await api.checkForUpdates()
            let state = try await api.getUpdaterState()
            phase = mapUpdaterState(state)
        } catch {
            logger.error("checkForUpdates failed: \(error.localizedDescription, privacy: .public)")
            phase = .error(error.localizedDescription)
        }
    }

    func startDownload() async {
        guard case .updateAvailable = phase else {
            logger.warning("startDownload called in non-updateAvailable phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        phase = .downloading

        do {
            try await api.downloadUpdate()
            await pollUntilReadyToApply()
        } catch {
            logger.error("startDownload failed: \(error.localizedDescription, privacy: .public)")
            phase = .error(error.localizedDescription)
        }
    }

    func startApply() async {
        guard case .readyToApply = phase else {
            logger.warning("startApply called in non-readyToApply phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        phase = .applying

        do {
            try await api.applyUpdate()
            phase = .rebooting
        } catch {
            logger.error("startApply failed: \(error.localizedDescription, privacy: .public)")
            phase = .error(error.localizedDescription)
        }
    }

    func reset() {
        pollingTask?.cancel()
        phase = .idle
        currentVersion = nil
        latestVersion = nil
        updateUrl = nil
    }

    // MARK: - Private Helpers

    private func pollUntilReadyToApply() async {
        pollingTask = Task {
            for _ in 0..<60 {
                guard !Task.isCancelled else { return }

                try? await Task.sleep(for: .seconds(5))

                guard !Task.isCancelled else { return }

                guard let state = try? await api.getUpdaterState() else {
                    continue
                }

                let mapped = mapUpdaterState(state)

                if case .readyToApply = mapped {
                    phase = .readyToApply
                    return
                }

                // Pitfall 6: Unexpected idle while downloading means the download was interrupted
                if case .idle = mapped {
                    phase = .error("Download wurde unterbrochen")
                    return
                }
            }

            // Loop exhausted without reaching readyToApply
            if case .downloading = phase {
                phase = .error("Download-Timeout")
            }
        }

        await pollingTask?.value
    }

    private func mapUpdaterState(_ state: UpdaterState) -> UpdatePhase {
        switch state.stateType {
        case "ValetudoUpdaterIdleState":
            return .idle
        case "ValetudoUpdaterApprovalPendingState":
            return .updateAvailable
        case "ValetudoUpdaterDownloadingState":
            return .downloading
        case "ValetudoUpdaterApplyPendingState":
            return .readyToApply
        default:
            logger.warning("Unknown updater state: \(state.stateType, privacy: .public)")
            return .idle
        }
    }
}
