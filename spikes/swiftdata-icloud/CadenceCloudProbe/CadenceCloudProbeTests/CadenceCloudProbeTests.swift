import CadencePersistenceSpike
import Foundation
import Testing
@testable import CadenceCloudProbe

struct CadenceCloudProbeTests {
    @MainActor
    @Test func controllerCopiesLocalSourceToSeparateDestination() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let controller = try ProbeController(baseURL: baseURL)
        controller.seedLocal(payload: "baseline", replica: "replica-a")
        controller.copyLocalToCloud()

        #expect(controller.localValues.count == 1)
        #expect(controller.cloudValues == controller.localValues)
        #expect(controller.lastMigration?.sourceCount == 1)
        #expect(controller.lastMigration?.destinationCountAfter == 1)
    }
}
