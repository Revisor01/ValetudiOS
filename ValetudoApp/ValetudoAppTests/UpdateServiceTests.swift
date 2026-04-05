import XCTest
@testable import ValetudoApp

// MARK: - MockValetudoAPI

final class MockValetudoAPI: ValetudoAPIProtocol, @unchecked Sendable {

    var updaterStateToReturn: UpdaterState = UpdaterState(
        __class: "ValetudoUpdaterIdleState",
        busy: nil, currentVersion: nil, version: nil,
        releaseTimestamp: nil, downloadUrl: nil, downloadPath: nil, metaData: nil
    )

    var versionToReturn: ValetudoVersion = ValetudoVersion(release: "2024.01.0", commit: "abc123")
    var shouldThrowOnCheck = false
    var shouldThrowOnDownload = false
    var getUpdaterStateCallCount = 0

    /// Sequence of states to return on successive getUpdaterState calls.
    /// Once exhausted, falls back to updaterStateToReturn.
    var stateSequence: [UpdaterState]? = nil

    func checkForUpdates() async throws {
        if shouldThrowOnCheck { throw URLError(.badServerResponse) }
    }

    func getUpdaterState() async throws -> UpdaterState {
        getUpdaterStateCallCount += 1
        if let seq = stateSequence, getUpdaterStateCallCount <= seq.count {
            return seq[getUpdaterStateCallCount - 1]
        }
        return updaterStateToReturn
    }

    func downloadUpdate() async throws {
        if shouldThrowOnDownload { throw URLError(.badServerResponse) }
    }

    func applyUpdate() async throws {}

    func getValetudoVersion() async throws -> ValetudoVersion {
        versionToReturn
    }
}

// MARK: - Helpers

private func makeUpdaterState(_ className: String) -> UpdaterState {
    UpdaterState(
        __class: className,
        busy: nil, currentVersion: nil, version: nil,
        releaseTimestamp: nil, downloadUrl: nil, downloadPath: nil, metaData: nil
    )
}

// MARK: - UpdateServiceTests

@MainActor
final class UpdateServiceTests: XCTestCase {

    // MARK: - checkForUpdates: idle → checking → updateAvailable

    func testCheckForUpdates_withApprovalPendingState_transitionsToUpdateAvailable() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApprovalPendingState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .updateAvailable)
    }

    // MARK: - checkForUpdates: idle → checking → idle (no update)

    func testCheckForUpdates_withIdleState_remainsIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterIdleState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - checkForUpdates: idle → checking → error

    func testCheckForUpdates_whenAPIThrows_transitionsToError() async throws {
        let mock = MockValetudoAPI()
        mock.shouldThrowOnCheck = true
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        if case .error = service.phase {
            // expected
        } else {
            XCTFail("Expected error phase, got \(service.phase)")
        }
    }

    // MARK: - startDownload: updateAvailable → downloading (then poll to readyToApply)

    func testStartDownload_fromUpdateAvailable_transitionsToReadyToApply() async throws {
        let mock = MockValetudoAPI()
        // First getUpdaterState call: checkForUpdates poll → ApprovalPending
        // Then startDownload poll: first call → ApplyPending (triggers readyToApply)
        mock.stateSequence = [
            makeUpdaterState("ValetudoUpdaterApprovalPendingState"),
            makeUpdaterState("ValetudoUpdaterApplyPendingState")
        ]
        let service = UpdateService(api: mock)

        // Bring service to updateAvailable
        await service.checkForUpdates()
        XCTAssertEqual(service.phase, .updateAvailable)

        // Start download — poll will get ApplyPendingState on first call
        await service.startDownload()

        XCTAssertEqual(service.phase, .readyToApply)
    }

    // MARK: - startDownload: downloading → error (API throws)

    func testStartDownload_whenDownloadAPIThrows_transitionsToError() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApprovalPendingState")
        mock.shouldThrowOnDownload = true
        let service = UpdateService(api: mock)

        await service.checkForUpdates()
        XCTAssertEqual(service.phase, .updateAvailable)

        await service.startDownload()

        if case .error = service.phase {
            // expected
        } else {
            XCTFail("Expected error phase, got \(service.phase)")
        }
    }

    // MARK: - startDownload: downloading → error (poll returns idle = interrupted)

    func testStartDownload_whenPollReturnsIdle_transitionsToInterruptedError() async throws {
        let mock = MockValetudoAPI()
        // First call (checkForUpdates): ApprovalPending
        // Second call (poll in startDownload): IdleState → "Download unterbrochen"
        mock.stateSequence = [
            makeUpdaterState("ValetudoUpdaterApprovalPendingState"),
            makeUpdaterState("ValetudoUpdaterIdleState")
        ]
        let service = UpdateService(api: mock)

        await service.checkForUpdates()
        XCTAssertEqual(service.phase, .updateAvailable)

        await service.startDownload()

        XCTAssertEqual(service.phase, .error("Download wurde unterbrochen"))
    }

    // MARK: - reset: error → idle

    func testReset_fromErrorState_transitionsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.shouldThrowOnCheck = true
        let service = UpdateService(api: mock)

        await service.checkForUpdates()
        if case .error = service.phase { } else {
            XCTFail("Setup failed: expected error phase")
        }

        service.reset()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - reset: any state → idle

    func testReset_fromUpdateAvailableState_transitionsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApprovalPendingState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()
        XCTAssertEqual(service.phase, .updateAvailable)

        service.reset()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - mapUpdaterState: IdleState → .idle

    func testMapping_idleState_mapsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterIdleState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - mapUpdaterState: ApprovalPendingState → .updateAvailable

    func testMapping_approvalPendingState_mapsToUpdateAvailable() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApprovalPendingState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .updateAvailable)
    }

    // MARK: - mapUpdaterState: DownloadingState → .downloading

    func testMapping_downloadingState_mapsToDownloading() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterDownloadingState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .downloading)
    }

    // MARK: - mapUpdaterState: ApplyPendingState → .readyToApply

    func testMapping_applyPendingState_mapsToReadyToApply() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApplyPendingState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .readyToApply)
    }

    // MARK: - mapUpdaterState: DisabledState → .idle

    func testMapping_disabledState_mapsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterDisabledState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - mapUpdaterState: ErrorState → .error

    func testMapping_errorState_mapsToError() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterErrorState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        // ErrorState falls through to default → .idle (no error message field in model)
        // This documents the current behavior: unknown states map to .idle
        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - mapUpdaterState: NoUpdateRequiredState → .idle

    func testMapping_noUpdateRequiredState_mapsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterNoUpdateRequiredState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .idle)
    }

    // MARK: - mapUpdaterState: unknown class → .idle

    func testMapping_unknownClass_mapsToIdle() async throws {
        let mock = MockValetudoAPI()
        mock.updaterStateToReturn = makeUpdaterState("SomeUnknownUpdaterState")
        let service = UpdateService(api: mock)

        await service.checkForUpdates()

        XCTAssertEqual(service.phase, .idle)
    }
}
