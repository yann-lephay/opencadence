import Foundation
import SwiftData

public struct MigrationReport: Equatable, Sendable {
    public let sourceCount: Int
    public let destinationCountBefore: Int
    public let destinationCountAfter: Int
    public let canonicalChecksum: String
}

@MainActor
public enum PersistenceMigrationCoordinator {
    public static func values(in container: ModelContainer) throws -> [SnapshotValue] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<CadenceSnapshot>())
            .map(SnapshotValue.init)
            .sorted(by: SnapshotConflictResolver.stableOrder)
    }

    public static func migrate(
        from source: ModelContainer,
        to destination: ModelContainer,
        now: Date
    ) throws -> MigrationReport {
        let sourceValues = try values(in: source)
        let destinationValues = try values(in: destination)
        let canonical = SnapshotConflictResolver.canonicalize(sourceValues + destinationValues)
        try replaceAll(in: destination, with: canonical)

        let verified = try values(in: destination)
        let backup = try BackupCodec.make(records: verified, exportedAt: now)
        guard verified == canonical else { throw MigrationError.verificationFailed }

        return MigrationReport(
            sourceCount: sourceValues.count,
            destinationCountBefore: destinationValues.count,
            destinationCountAfter: verified.count,
            canonicalChecksum: backup.contentChecksum
        )
    }

    public static func restore(
        _ envelope: BackupEnvelope,
        into destination: ModelContainer
    ) throws {
        try replaceAll(in: destination, with: envelope.records)
        guard try values(in: destination) == envelope.records else {
            throw MigrationError.verificationFailed
        }
    }

    public static func erase(_ container: ModelContainer) throws {
        try replaceAll(in: container, with: [])
    }

    private static func replaceAll(
        in container: ModelContainer,
        with values: [SnapshotValue]
    ) throws {
        let context = ModelContext(container)
        for model in try context.fetch(FetchDescriptor<CadenceSnapshot>()) {
            context.delete(model)
        }
        for value in values {
            context.insert(value.makeModel())
        }
        try context.save()
    }
}

public enum MigrationError: Error, Equatable {
    case verificationFailed
}
