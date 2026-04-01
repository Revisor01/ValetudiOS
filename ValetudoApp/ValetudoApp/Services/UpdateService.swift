import Foundation
import UIKit
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
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

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

        setPhase(.checking)

        do {
            try await api.checkForUpdates()
            let state = try await api.getUpdaterState()
            setPhase(mapUpdaterState(state))
        } catch {
            logger.error("checkForUpdates failed: \(error.localizedDescription, privacy: .public)")
            setPhase(.error(error.localizedDescription))
        }
    }

    func startDownload() async {
        guard case .updateAvailable = phase else {
            logger.warning("startDownload called in non-updateAvailable phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        setPhase(.downloading)

        do {
            try await api.downloadUpdate()
            await pollUntilReadyToApply()
        } catch {
            logger.error("startDownload failed: \(error.localizedDescription, privacy: .public)")
            setPhase(.error(error.localizedDescription))
        }
    }

    func startApply() async {
        guard case .readyToApply = phase else {
            logger.warning("startApply called in non-readyToApply phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        setPhase(.applying)

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ValetudoApplyUpdate") { [weak self] in
            // Expiry handler — iOS gibt uns letzte Chance aufzuraeumen
            self?.logger.warning("Background task expiring")
            if let id = self?.backgroundTaskID, id != .invalid {
                UIApplication.shared.endBackgroundTask(id)
                self?.backgroundTaskID = .invalid
            }
        }

        do {
            try await api.applyUpdate()
            setPhase(.rebooting)
            await pollUntilReboot()
        } catch {
            logger.error("startApply failed: \(error.localizedDescription, privacy: .public)")
            setPhase(.error(error.localizedDescription))
        }

        endBackgroundTaskIfNeeded()
    }

    func reset() {
        pollingTask?.cancel()
        endBackgroundTaskIfNeeded()
        setPhase(.idle)
        currentVersion = nil
        latestVersion = nil
        updateUrl = nil
    }

    // MARK: - Private Helpers

    private func setPhase(_ newPhase: UpdatePhase) {
        phase = newPhase
        updateIdleTimer()
    }

    private func updateIdleTimer() {
        switch phase {
        case .downloading, .applying, .rebooting:
            UIApplication.shared.isIdleTimerDisabled = true
        default:
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

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
                    setPhase(.readyToApply)
                    return
                }

                // Pitfall 6: Unexpected idle while downloading means the download was interrupted
                if case .idle = mapped {
                    setPhase(.error("Download wurde unterbrochen"))
                    return
                }
            }

            // Loop exhausted without reaching readyToApply
            if case .downloading = phase {
                setPhase(.error("Download-Timeout"))
            }
        }

        await pollingTask?.value
    }

    private func pollUntilReboot() async {
        pollingTask = Task {
            // Warte 10 Sekunden bevor erstes Poll — Roboter braucht Zeit zum Herunterfahren
            try? await Task.sleep(for: .seconds(10))

            for _ in 0..<22 {  // 22 * 5s = 110s + 10s initial = 120s total
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }

                do {
                    let _ = try await api.getValetudoVersion()
                    // Roboter antwortet wieder — Erfolg
                    setPhase(.idle)
                    return
                } catch {
                    // Netzwerkfehler waehrend Reboot ist ERWARTET — weiter pollen
                    logger.info("Reboot-Polling: Roboter noch nicht erreichbar (\(error.localizedDescription, privacy: .public))")
                    continue
                }
            }

            // Timeout nach 120 Sekunden
            setPhase(.error("Roboter nicht erreichbar nach Update"))
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
