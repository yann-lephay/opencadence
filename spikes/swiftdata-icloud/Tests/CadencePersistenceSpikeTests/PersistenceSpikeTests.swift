import Foundation
import SwiftData
import XCTest
@testable import CadencePersistenceSpike

final class PersistenceSpikeTests: XCTestCase {
    @MainActor
    func testLocalStorePersistsAcrossContainerReopen() throws {
        let directory = try temporaryDirectory()
        let storeURL = directory.appending(path: "local.store")
        let id = UUID()

        var container: ModelContainer? = try PersistenceStoreFactory.makeContainer(url: storeURL)
        let context = ModelContext(try XCTUnwrap(container))
        context.insert(model(id: id, revision: 1, payload: "first"))
        try context.save()
        container = nil

        let reopened = try PersistenceStoreFactory.makeContainer(url: storeURL)
        let values = try PersistenceMigrationCoordinator.values(in: reopened)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.logicalID, id)
        XCTAssertEqual(String(data: try XCTUnwrap(values.first?.payload), encoding: .utf8), "first")
    }

    @MainActor
    func testLateActivationCopiesToSeparateStoreAndIsIdempotent() throws {
        let directory = try temporaryDirectory()
        let local = try PersistenceStoreFactory.makeContainer(url: directory.appending(path: "local.store"))
        let cloudCandidate = try PersistenceStoreFactory.makeContainer(url: directory.appending(path: "cloud.store"))
        let sharedID = UUID()
        let localOnlyID = UUID()

        try insert([
            model(id: sharedID, revision: 1, timestamp: 100, device: "phone", payload: "old"),
            model(id: localOnlyID, revision: 1, timestamp: 110, device: "phone", payload: "local")
        ], into: local)
        try insert([
            model(id: sharedID, revision: 2, timestamp: 120, device: "tablet", payload: "new")
        ], into: cloudCandidate)

        let first = try PersistenceMigrationCoordinator.migrate(from: local, to: cloudCandidate, now: Date(timeIntervalSince1970: 200))
        let second = try PersistenceMigrationCoordinator.migrate(from: local, to: cloudCandidate, now: Date(timeIntervalSince1970: 300))
        let values = try PersistenceMigrationCoordinator.values(in: cloudCandidate)

        XCTAssertEqual(first.destinationCountAfter, 2)
        XCTAssertEqual(second.destinationCountAfter, 2)
        XCTAssertEqual(first.canonicalChecksum, second.canonicalChecksum)
        XCTAssertEqual(try PersistenceMigrationCoordinator.values(in: local).count, 2, "The rollback store stays untouched")
        XCTAssertEqual(values.first(where: { $0.logicalID == sharedID })?.revision, 2)
    }

    func testConflictResolverIsDeterministicAndTombstoneWinsExactTie() {
        let id = UUID()
        let live = value(id: id, revision: 4, timestamp: 400, device: "phone", payload: "live")
        let deleted = value(id: id, revision: 4, timestamp: 400, device: "phone", payload: "live", isDeleted: true)

        XCTAssertTrue(SnapshotConflictResolver.winner(live, deleted).isDeleted)
        XCTAssertEqual(
            SnapshotConflictResolver.canonicalize([live, deleted]),
            SnapshotConflictResolver.canonicalize([deleted, live])
        )
    }

    @MainActor
    func testPersistedTombstoneRoundTripsAsDeleted() throws {
        let directory = try temporaryDirectory()
        let storeURL = directory.appending(path: "tombstone.store")
        var container: ModelContainer? = try PersistenceStoreFactory.makeContainer(url: storeURL)
        try insert([
            model(id: UUID(), revision: 4, timestamp: 400, device: "phone", payload: "deleted", isDeleted: true)
        ], into: try XCTUnwrap(container))
        container = nil

        let reopened = try PersistenceStoreFactory.makeContainer(url: storeURL)
        let value = try XCTUnwrap(PersistenceMigrationCoordinator.values(in: reopened).first)
        XCTAssertTrue(value.isDeleted)
    }

    @MainActor
    func testBackupRestoresAndRejectsTampering() throws {
        let directory = try temporaryDirectory()
        let source = try PersistenceStoreFactory.makeContainer(url: directory.appending(path: "source.store"))
        let restored = try PersistenceStoreFactory.makeContainer(url: directory.appending(path: "restored.store"))
        try insert([
            model(id: UUID(), revision: 1, timestamp: 100.123_456, payload: "session")
        ], into: source)

        let envelope = try BackupCodec.make(
            records: PersistenceMigrationCoordinator.values(in: source),
            exportedAt: Date(timeIntervalSince1970: 500.654_321)
        )
        let encoded = try BackupCodec.encode(envelope)
        let verified = try BackupCodec.decodeAndVerify(encoded)
        XCTAssertEqual(verified.exportedAt, envelope.exportedAt)
        XCTAssertEqual(verified.records.first?.updatedAt, envelope.records.first?.updatedAt)
        try PersistenceMigrationCoordinator.restore(verified, into: restored)
        XCTAssertEqual(
            try PersistenceMigrationCoordinator.values(in: source),
            try PersistenceMigrationCoordinator.values(in: restored)
        )

        var tampered = encoded
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        XCTAssertThrowsError(try BackupCodec.decodeAndVerify(tampered))
    }

    @MainActor
    func testEraseSurvivesReopen() throws {
        let directory = try temporaryDirectory()
        let storeURL = directory.appending(path: "erase.store")
        var container: ModelContainer? = try PersistenceStoreFactory.makeContainer(url: storeURL)
        try insert([model(id: UUID(), revision: 1, payload: "remove")], into: try XCTUnwrap(container))
        try PersistenceMigrationCoordinator.erase(try XCTUnwrap(container))
        XCTAssertTrue(try PersistenceMigrationCoordinator.values(in: try XCTUnwrap(container)).isEmpty)
        container = nil

        let reopened = try PersistenceStoreFactory.makeContainer(url: storeURL)
        XCTAssertTrue(try PersistenceMigrationCoordinator.values(in: reopened).isEmpty)
    }

    @MainActor
    func testCloudConfigurationUsesExplicitPrivateContainer() {
        let identifier = "iCloud.fr.opencadence.persistence-spike"
        let configuration = PersistenceStoreFactory.configuration(
            url: URL(filePath: "/tmp/cadence-cloud-config.store"),
            mode: .privateCloud(containerIdentifier: identifier)
        )
        XCTAssertEqual(configuration.cloudKitContainerIdentifier, identifier)
    }

    @MainActor
    private func insert(_ models: [CadenceSnapshot], into container: ModelContainer) throws {
        let context = ModelContext(container)
        for model in models { context.insert(model) }
        try context.save()
    }

    private func model(
        id: UUID,
        revision: Int,
        timestamp: TimeInterval = 100,
        device: String = "phone",
        payload: String,
        isDeleted: Bool = false
    ) -> CadenceSnapshot {
        CadenceSnapshot(
            logicalID: id,
            kind: "session",
            revision: revision,
            updatedAt: Date(timeIntervalSince1970: timestamp),
            deviceID: device,
            payload: Data(payload.utf8),
            isDeleted: isDeleted
        )
    }

    private func value(
        id: UUID,
        revision: Int,
        timestamp: TimeInterval,
        device: String,
        payload: String,
        isDeleted: Bool = false
    ) -> SnapshotValue {
        SnapshotValue(
            logicalID: id,
            kind: "session",
            revision: revision,
            updatedAt: Date(timeIntervalSince1970: timestamp),
            deviceID: device,
            payload: Data(payload.utf8),
            isDeleted: isDeleted
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "cadence-persistence-spike-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
