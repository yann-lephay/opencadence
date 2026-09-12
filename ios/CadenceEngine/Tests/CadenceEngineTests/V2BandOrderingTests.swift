import Foundation
import Testing
@testable import CadenceEngine

struct V2BandOrderingTests {
    private let exercise = V2EngineConfiguration.productPreview.catalog["seated_band_row"]!

    @Test("Old inventories do not imply an ordered resistance scale")
    func oldInventoryIsUnordered() throws {
        let data = Data(#"{"category":"resistance_band","units":1,"perUnitWeightsKg":[],"optionIDs":["light","strong"]}"#.utf8)
        let item = try JSONDecoder().decode(V2InventoryItem.self, from: data)
        #expect(item.optionProgressionIsDeclared == nil)
        #expect(next("light", [item]) == nil)
        #expect(recalibrate("strong", [item])?.optionID == "strong")
    }

    @Test("An explicit scale permits movement only within the declared item")
    func explicitScale() {
        let inventory = [band(["light", "medium", "strong"], declared: true)]
        #expect(next("light", inventory)?.optionID == "medium")
        #expect(recalibrate("strong", inventory)?.optionID == "medium")
        #expect(next("strong", inventory) == nil)
        #expect(next("absent", inventory) == nil)
    }

    @Test("Independent bands never acquire an order from array position or names")
    func independentBands() {
        let inventory = [band(["light"], declared: true), band(["strong"], declared: true)]
        #expect(next("light", inventory) == nil)
        #expect(recalibrate("strong", inventory)?.optionID == "strong")
        #expect(next("light", [band(["light", "strong"])]) == nil)
    }

    @Test("Ambiguous overlapping declarations do not choose an arbitrary resistance")
    func ambiguousDeclarations() {
        let inventory = [band(["light", "medium"], declared: true), band(["strong", "light"], declared: true)]
        #expect(next("light", inventory) == nil)
        #expect(recalibrate("light", inventory)?.optionID == "light")
    }

    private func band(_ ids: [String], declared: Bool = false) -> V2InventoryItem {
        .init(category: "resistance_band", units: 1, optionIDs: ids, optionProgressionIsDeclared: declared)
    }

    private func next(_ id: String, _ inventory: [V2InventoryItem]) -> V2Load? {
        let configuration = V2EngineConfiguration.productPreview
        let previous = V2Prescription(
            exerciseId: "seated_band_row", sets: 1, targetReps: exercise.repRange.max,
            load: .init(optionID: id), progressionContext: exercise.progressionContext,
            catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion
        )
        let exposures = (0..<2).map { _ in V2Exposure(
            confirmedReps: [exercise.repRange.max], loadOptionID: id,
            allPrescribedSetsConfirmed: true, progressionContext: exercise.progressionContext,
            catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion
        ) }
        let result = CadenceEngine.decideV2(request: .progressionTransition(.init(
            todayInventory: inventory, previousPrescription: previous, exposures: exposures,
            todaySupports: exercise.supports
        )), configuration: configuration)
        guard case .progressionTransition(let decision) = result,
              decision.nextPrescription.load?.optionID != id else { return nil }
        return decision.nextPrescription.load
    }

    private func recalibrate(_ id: String, _ inventory: [V2InventoryItem]) -> V2Load? {
        let configuration = V2EngineConfiguration.productPreview
        let inventory = [V2InventoryItem(category: "bodyweight", units: 1)] + inventory
        let history = V2HistoryEntry(
            endedAt: "2026-09-01T08:00:00Z",
            references: [.init(exerciseId: "seated_band_row", loadOptionID: id, targetReps: 8,
                              progressionContext: exercise.progressionContext)],
            catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion
        )
        let result = CadenceEngine.decideV2(request: .sessionDecision(.init(
            request: .init(durationMinutes: 30, mode: .recalibration),
            persistentInventory: inventory, todayInventory: inventory,
            todaySupports: Array(Set(configuration.catalog.values.flatMap(\.supports))), history: [history]
        ), now: ISO8601DateFormatter().date(from: "2026-09-02T08:00:00Z")!), configuration: configuration)
        guard case .sessionDecision(let decision) = result else { return nil }
        return decision.plan.first { $0.exerciseId == "seated_band_row" }?.load
    }
}
