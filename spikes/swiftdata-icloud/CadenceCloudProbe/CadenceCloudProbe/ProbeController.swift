import CadencePersistenceSpike
import Foundation
import Observation
import SwiftData

enum ProbeConstants {
    static let containerIdentifier = "iCloud.fr.opencadence.CadenceCloudProbe"
    static let logicalID = UUID(uuidString: "A60BEE26-201B-4E4B-86C2-E792D05A9407")!
    static let conflictDate = Date(timeIntervalSince1970: 2_000_000_000)
    static let conflictRevision = 50
}

@MainActor
@Observable
final class ProbeController {
    private let localContainer: ModelContainer
    private let cloudContainer: ModelContainer

    private(set) var localValues: [SnapshotValue] = []
    private(set) var cloudValues: [SnapshotValue] = []
    private(set) var operationStatus = "Ready"
    private(set) var lastMigration: MigrationReport?

    var canonicalCloudValue: SnapshotValue? {
        SnapshotConflictResolver.canonicalize(cloudValues).first
    }

    convenience init() throws {
        try self.init(baseURL: Self.defaultStoreDirectory())
    }

    init(baseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )

        localContainer = try PersistenceStoreFactory.makeContainer(
            url: baseURL.appending(path: "local.store"),
            mode: .localOnly
        )
        cloudContainer = try PersistenceStoreFactory.makeContainer(
            url: baseURL.appending(path: "cloud.store"),
            mode: .privateCloud(containerIdentifier: ProbeConstants.containerIdentifier)
        )
        try refresh()
    }

    func seedLocal(payload: String, replica: String) {
        let nextRevision = localValues
            .filter { $0.logicalID == ProbeConstants.logicalID }
            .map(\.revision)
            .max()
            .map { $0 + 1 } ?? 1

        insert(
            SnapshotValue(
                logicalID: ProbeConstants.logicalID,
                kind: "cloud-probe",
                revision: nextRevision,
                updatedAt: Date(),
                deviceID: replica,
                payload: Data(payload.utf8)
            ),
            into: localContainer,
            success: "Seeded local r\(nextRevision) from \(replica)"
        )
    }

    func copyLocalToCloud() {
        do {
            lastMigration = try PersistenceMigrationCoordinator.migrate(
                from: localContainer,
                to: cloudContainer,
                now: Date()
            )
            try refresh()
            operationStatus = "Copied and verified local → cloud"
        } catch {
            operationStatus = "Copy failed: \(error.localizedDescription)"
        }
    }

    func writeCloudConflict(payload: String, replica: String, isDeleted: Bool) {
        insert(
            SnapshotValue(
                logicalID: ProbeConstants.logicalID,
                kind: "cloud-probe",
                revision: ProbeConstants.conflictRevision,
                updatedAt: ProbeConstants.conflictDate,
                deviceID: replica,
                payload: Data("\(payload)-\(replica)".utf8),
                isDeleted: isDeleted
            ),
            into: cloudContainer,
            success: "Wrote cloud conflict from \(replica)"
        )
    }

    func eraseCloudDestination() {
        do {
            try PersistenceMigrationCoordinator.erase(cloudContainer)
            try refresh()
            operationStatus = "Erased cloud destination; local source intact"
        } catch {
            operationStatus = "Erase failed: \(error.localizedDescription)"
        }
    }

    private func insert(
        _ value: SnapshotValue,
        into container: ModelContainer,
        success: String
    ) {
        do {
            let context = ModelContext(container)
            context.insert(value.makeModel())
            try context.save()
            try refresh()
            operationStatus = success
        } catch {
            operationStatus = "Write failed: \(error.localizedDescription)"
        }
    }

    private func refresh() throws {
        localValues = try PersistenceMigrationCoordinator.values(in: localContainer)
        cloudValues = try PersistenceMigrationCoordinator.values(in: cloudContainer)
    }

    private static func defaultStoreDirectory() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "CadenceCloudProbe", directoryHint: .isDirectory)
    }
}
