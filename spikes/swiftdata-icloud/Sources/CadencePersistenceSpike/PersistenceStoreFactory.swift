import Foundation
import SwiftData

public enum PersistenceSyncMode: Equatable, Sendable {
    case localOnly
    case privateCloud(containerIdentifier: String)
}

public enum PersistenceStoreFactory {
    @MainActor
    private static var schema: Schema {
        Schema([CadenceSnapshot.self])
    }

    @MainActor
    public static func configuration(
        url: URL,
        mode: PersistenceSyncMode
    ) -> ModelConfiguration {
        let cloudDatabase: ModelConfiguration.CloudKitDatabase = switch mode {
        case .localOnly:
            .none
        case let .privateCloud(containerIdentifier):
            .private(containerIdentifier)
        }

        return ModelConfiguration(
            "CadencePersistenceSpike",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: cloudDatabase
        )
    }

    @MainActor
    public static func makeContainer(
        url: URL,
        mode: PersistenceSyncMode = .localOnly
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: [configuration(url: url, mode: mode)]
        )
    }
}
