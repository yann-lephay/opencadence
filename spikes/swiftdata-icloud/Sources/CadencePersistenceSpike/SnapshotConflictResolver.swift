import Foundation

public enum SnapshotConflictResolver {
    /// Higher revision wins. Remaining fields are deterministic tie-breakers.
    /// A tombstone wins an otherwise exact tie so deletion cannot resurrect data.
    public static func winner(_ lhs: SnapshotValue, _ rhs: SnapshotValue) -> SnapshotValue {
        if lhs.revision != rhs.revision { return lhs.revision > rhs.revision ? lhs : rhs }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt ? lhs : rhs }
        if lhs.isDeleted != rhs.isDeleted { return lhs.isDeleted ? lhs : rhs }
        if lhs.deviceID != rhs.deviceID { return lhs.deviceID > rhs.deviceID ? lhs : rhs }

        let leftPayload = lhs.payload.base64EncodedString()
        let rightPayload = rhs.payload.base64EncodedString()
        return leftPayload >= rightPayload ? lhs : rhs
    }

    public static func canonicalize(_ values: [SnapshotValue]) -> [SnapshotValue] {
        var winners: [UUID: SnapshotValue] = [:]
        for value in values {
            if let current = winners[value.logicalID] {
                winners[value.logicalID] = winner(current, value)
            } else {
                winners[value.logicalID] = value
            }
        }
        return winners.values.sorted(by: stableOrder)
    }

    public static func stableOrder(_ lhs: SnapshotValue, _ rhs: SnapshotValue) -> Bool {
        if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
        return lhs.logicalID.uuidString < rhs.logicalID.uuidString
    }
}
