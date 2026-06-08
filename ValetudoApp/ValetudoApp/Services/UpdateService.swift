import Foundation
import UIKit
import os
import Observation

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

// MARK: - ValetudoAPIProtocol

protocol ValetudoAPIProtocol: AnyObject, Sendable {
    func checkForUpdates() async throws
    func getUpdaterState() async throws -> UpdaterState
    func downloadUpdate() async throws
    func applyUpdate() async throws
    func getValetudoVersion() async throws -> ValetudoVersion
}

// MARK: - UpdateService

@MainActor
@Observable
class UpdateService {

    private(set) var phase: UpdatePhase = .idle
    private(set) var currentVersion: String?
    private(set) var latestVersion: String?
    private(set) var updateUrl: String?
    private(set) var downloadProgress: Double = 0.0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "UpdateService")
    private let api: any ValetudoAPIProtocol
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var lastCheckDate: Date?

    /// Wird aufgerufen wenn der Roboter nach einem OTA-Update erfolgreich neu gestartet hat
    var onRebootComplete: (() -> Void)?

    init(api: any ValetudoAPIProtocol) {
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
        if let last = lastCheckDate, Date().timeIntervalSince(last) < 3600 { return }

        // Ein hängengebliebener .error aus einem früheren (abgebrochenen) Check darf einen
        // neuen Check nicht blockieren — aus .error oder .idle heraus neu prüfen ist ok.
        switch phase {
        case .idle, .error:
            break
        default:
            logger.warning("checkForUpdates called in non-idle phase: \(String(describing: self.phase), privacy: .public)")
            return
        }

        setPhase(.checking)
        lastCheckDate = Date()

        do {
            // Erst aktuellen State holen — Valetudo erlaubt "check" nur in Idle/Error.
            // Wenn bereits ApprovalPending/Downloading/ApplyPending, direkt nutzen.
            let initialState = try await api.getUpdaterState()
            let initialMapped = mapUpdaterState(initialState)
            if case .idle = initialMapped {
                // Nur dann triggern wir einen neuen Check.
                try await api.checkForUpdates()
                // Valetudo verarbeitet den Check asynchron — pollen bis State wechselt.
                var mapped: UpdatePhase = .idle
                for attempt in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(attempt == 0 ? 500 : 1500))
                    let state = try await api.getUpdaterState()
                    mapped = mapUpdaterState(state)
                    if case .idle = mapped { continue }
                    break
                }
                setPhase(mapped)
            } else {
                setPhase(initialMapped)
            }
        } catch {
            // Ein fehlgeschlagener Update-PRÜFUNG ist unkritisch (z.B. View verlassen,
            // Verbindung kurz weg, 401 beim Navigieren). Sie darf KEINEN dauerhaften
            // Fehler-Banner erzeugen — still zurück auf .idle, beim nächsten Öffnen
            // wird erneut geprüft. Echte Fehler-Banner gibt es nur bei Download/Apply.
            logger.info("checkForUpdates failed (silent, back to idle): \(error.localizedDescription, privacy: .public)")
            setPhase(.idle)
            // lastCheckDate zurücksetzen, damit der nächste Aufruf nicht wegen des
            // 1h-Throttles übersprungen wird.
            lastCheckDate = nil
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
        downloadProgress = 0.0
        lastCheckDate = nil
    }

    // MARK: - Private Helpers

    private func setPhase(_ newPhase: UpdatePhase) {
        if case .downloading = newPhase { } else { downloadProgress = 0.0 }
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

                if let meta = state.metaData?.progress,
                   let current = meta.current, let total = meta.total, total > 0 {
                    downloadProgress = Double(current) / Double(total)
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
                    onRebootComplete?()
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
        case "ValetudoUpdaterIdleState", "ValetudoUpdaterNoUpdateRequiredState":
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
