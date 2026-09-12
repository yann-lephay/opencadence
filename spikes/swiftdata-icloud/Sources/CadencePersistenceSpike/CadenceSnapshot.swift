import Foundation
import SwiftData

/// A deliberately small CloudKit-compatible envelope for the persistence spike.
/// It tests migration and conflict semantics without freezing the product schema.
@Model
public final class CadenceSnapshot {
    public var logicalID: UUID = UUID()
    public var kind: String = ""
    public var revision: Int = 0
    public var updatedAt: Date = Date.distantPast
    public var deviceID: String = ""
    public var payload: Data = Data()
    // Avoid `isDeleted`: SwiftData/Core Data already uses that name for the
    // managed object's lifecycle state, which makes persisted tombstones read
    // back as live records.
    public var tombstone: Bool = false

    public init(
        logicalID: UUID,
        kind: String,
        revision: Int,
        updatedAt: Date,
        deviceID: String,
        payload: Data,
        isDeleted: Bool = false
    ) {
        self.logicalID = logicalID
        self.kind = kind
        self.revision = revision
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.payload = payload
        self.tombstone = isDeleted
    }
}

public struct SnapshotValue: Codable, Hashable, Sendable {
    public let logicalID: UUID
    public let kind: String
    public let revision: Int
    public let updatedAt: Date
    public let deviceID: String
    public let payload: Data
    public let isDeleted: Bool

    public init(
        logicalID: UUID,
        kind: String,
        revision: Int,
        updatedAt: Date,
        deviceID: String,
        payload: Data,
        isDeleted: Bool = false
    ) {
        self.logicalID = logicalID
        self.kind = kind
        self.revision = revision
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.payload = payload
        self.isDeleted = isDeleted
    }

    public init(_ model: CadenceSnapshot) {
        self.init(
            logicalID: model.logicalID,
            kind: model.kind,
            revision: model.revision,
            updatedAt: model.updatedAt,
            deviceID: model.deviceID,
            payload: model.payload,
            isDeleted: model.tombstone
        )
    }

    public func makeModel() -> CadenceSnapshot {
        CadenceSnapshot(
            logicalID: logicalID,
            kind: kind,
            revision: revision,
            updatedAt: updatedAt,
            deviceID: deviceID,
            payload: payload,
            isDeleted: isDeleted
        )
    }
}
