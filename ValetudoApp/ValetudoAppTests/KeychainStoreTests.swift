import XCTest
@testable import ValetudoApp

final class KeychainStoreTests: XCTestCase {

    // Track UUIDs used in each test for cleanup
    private var testUUIDs: [UUID] = []

    override func tearDown() {
        super.tearDown()
        for uuid in testUUIDs {
            KeychainStore.delete(for: uuid)
        }
        testUUIDs.removeAll()
    }

    private func makeUUID() -> UUID {
        let uuid = UUID()
        testUUIDs.append(uuid)
        return uuid
    }

    // MARK: - Tests

    func testSaveAndRetrieve() {
        let robotId = makeUUID()
        let saved = KeychainStore.save(password: "testPass123", for: robotId)
        XCTAssertTrue(saved, "save should return true on success")

        let retrieved = KeychainStore.password(for: robotId)
        XCTAssertEqual(retrieved, "testPass123")
    }

    func testDeleteRemovesPassword() {
        let robotId = makeUUID()
        KeychainStore.save(password: "secretValue", for: robotId)
        KeychainStore.delete(for: robotId)

        let retrieved = KeychainStore.password(for: robotId)
        XCTAssertNil(retrieved, "password should be nil after delete")
    }

    func testOverwritePassword() {
        let robotId = makeUUID()
        KeychainStore.save(password: "old", for: robotId)
        KeychainStore.save(password: "new", for: robotId)

        let retrieved = KeychainStore.password(for: robotId)
        XCTAssertEqual(retrieved, "new", "second save should overwrite first")
    }

    func testPasswordForUnknownUUIDReturnsNil() {
        let robotId = makeUUID()
        // Never saved - should return nil
        let retrieved = KeychainStore.password(for: robotId)
        XCTAssertNil(retrieved)
    }

    func testMultipleRobotsStoredIndependently() {
        let id1 = makeUUID()
        let id2 = makeUUID()
        KeychainStore.save(password: "pass1", for: id1)
        KeychainStore.save(password: "pass2", for: id2)

        XCTAssertEqual(KeychainStore.password(for: id1), "pass1")
        XCTAssertEqual(KeychainStore.password(for: id2), "pass2")
    }

    func testDeleteNonexistentDoesNotCrash() {
        let robotId = makeUUID()
        // Should not throw or crash
        KeychainStore.delete(for: robotId)
        XCTAssertNil(KeychainStore.password(for: robotId))
    }
}
