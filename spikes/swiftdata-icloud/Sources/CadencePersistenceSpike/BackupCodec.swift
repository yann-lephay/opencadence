import CryptoKit
import Foundation

public struct BackupEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let records: [SnapshotValue]
    public let contentChecksum: String
    public let checksum: String
}

private struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let records: [SnapshotValue]
    let contentChecksum: String
}

private struct CanonicalContent: Codable {
    let schemaVersion: Int
    let records: [SnapshotValue]
}

public enum BackupCodec {
    public static func make(
        records: [SnapshotValue],
        exportedAt: Date
    ) throws -> BackupEnvelope {
        let sorted = records.sorted(by: SnapshotConflictResolver.stableOrder)
        let content = CanonicalContent(schemaVersion: 1, records: sorted)
        let contentChecksum = try checksum(for: content)
        let payload = BackupPayload(
            schemaVersion: content.schemaVersion,
            exportedAt: exportedAt,
            records: content.records,
            contentChecksum: contentChecksum
        )
        return BackupEnvelope(
            schemaVersion: payload.schemaVersion,
            exportedAt: payload.exportedAt,
            records: payload.records,
            contentChecksum: payload.contentChecksum,
            checksum: try checksum(for: payload)
        )
    }

    public static func encode(_ envelope: BackupEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func decodeAndVerify(_ data: Data) throws -> BackupEnvelope {
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        let payload = BackupPayload(
            schemaVersion: envelope.schemaVersion,
            exportedAt: envelope.exportedAt,
            records: envelope.records,
            contentChecksum: envelope.contentChecksum
        )
        let content = CanonicalContent(
            schemaVersion: envelope.schemaVersion,
            records: envelope.records
        )
        guard envelope.contentChecksum == (try checksum(for: content)) else {
            throw BackupError.invalidChecksum
        }
        let expectedChecksum = try checksum(for: payload)
        guard envelope.checksum == expectedChecksum else {
            throw BackupError.invalidChecksum
        }
        return envelope
    }

    private static func checksum<T: Encodable>(for value: T) throws -> String {
        SHA256.hash(data: try encoder.encode(value))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

public enum BackupError: Error, Equatable {
    case invalidChecksum
}
