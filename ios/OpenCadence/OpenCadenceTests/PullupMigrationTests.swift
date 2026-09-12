import CadenceEngine
import Foundation
import Testing
@testable import OpenCadence

@MainActor
struct PullupMigrationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Legacy foot-assisted work never becomes strict or band-assisted capacity")
    func legacyAssistanceIsNotStrict() throws {
        let decision = EngineDecision(decision: "generate_workout", reasonCodes: [])
        let snapshot = ActiveSessionCoordinator.start(decision: decision, v2Context: nil, now: now)
        let base = WorkoutHistoryBuilder.payload(from: snapshot)
        for ids in [["assisted_pullup"], ["assisted_pullup", "bodyweight_squat"]] {
            let payload = CompletedWorkoutPayload(endedAt: now, snapshot: snapshot,
                feedback: base.feedback,
                historySession: .init(sessionId: "synthetic-legacy-assistance", endedAt: now.ISO8601Format(),
                    completedExerciseKeys: ids))
            let before = try JSONEncoder().encode(payload)
            let result = WorkoutEngineBridge.migratedV2History(from: [payload], source: .syntheticScenario)
            #expect(result.flatMap { $0.completedExerciseIds ?? [] } == (ids.count == 1 ? [] : ["squat"]))
            #expect(result.allSatisfy { $0.references == nil })
            #expect(payload.historySession.completedExerciseKeys == ids)
            #expect(try JSONDecoder().decode(CompletedWorkoutPayload.self, from: before) == payload)
        }
    }

    @Test("Audit trace: material availability is not a native capacity input")
    func auditInitialChoices() throws {
        let body = EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        let bar = EquipmentItem(category: "pullup_bar", units: 1, supportedConfigurations: ["bodyweight"])
        let band = EquipmentItem(category: "resistance_band", units: 1, optionIDs: ["synthetic-band"], supportedConfigurations: ["band"])
        let cases: [(String, [EquipmentItem], [String])] = [
            ("bar_no_clearance", [body, bar], []),
            ("bar_clearance_capacity_unknown", [body, bar], ["pullup_clearance"]),
            ("bar_top_support_capacity_unknown", [body, bar], ["pullup_clearance", "pullup_top_start_support"]),
            ("bar_band_capacity_unknown", [body, bar, band], ["pullup_clearance", "band_on_pullup_bar_allowed"])
        ]
        for (name, inventory, supports) in cases {
            let prepared = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
                engineVersion: .previewV2, todaySupports: supports, now: now)
            let context = try #require(prepared.v2Context)
            let rows = context.plan.filter { V2EngineConfiguration.productPreview.catalog[$0.exerciseId]?.anchor == "pull" }
            print("PULLUP_AUDIT \(name) pull=\(rows.map { "\($0.exerciseId):\($0.sets)x\($0.targetReps):\($0.referenceStatus)" })")
        }
        let configuration = V2EngineConfiguration.productPreview
        let inventory = [V2InventoryItem(category: "bodyweight", units: 1), V2InventoryItem(category: "pullup_bar", units: 1)]
        for reps in [0, 1, 2, 3, 5] {
            let history = V2HistoryEntry(endedAt: now.addingTimeInterval(-86400).ISO8601Format(),
                completedExerciseIds: ["pull_up"],
                references: [.init(exerciseId: "pull_up", targetReps: reps, progressionContext: "pull_up")],
                catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
            let result = CadenceEngine.decideV2(request: .sessionDecision(.init(
                request: .init(durationMinutes: 30), persistentInventory: inventory, todayInventory: inventory,
                todaySupports: ["pullup_clearance"], history: [history]), now: now), configuration: configuration)
            guard case let .sessionDecision(session) = result else { Issue.record("Expected session decision"); continue }
            print("PULLUP_AUDIT supplied_reference=\(reps) pull=\(session.plan.filter { $0.exerciseId == "pull_up" }.map { "\($0.sets)x\($0.targetReps):\($0.referenceStatus)" })")
        }
    }
}
