import CadenceEngine
import Foundation
import Testing
@testable import OpenCadence

@MainActor
struct AutomaticNativeChainTests {
    @Test("Automatic experiment retains incompatible-version recovery guard")
    func incompatibleSnapshot() throws {
        let prepared = WorkoutEngineBridge.prepareWorkout(inventory: [
            .init(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ], durationMinutes: 30, engineVersion: .previewV2,
        todaySupports: ["floor_allowed", "wall_or_stable_plane"], now: Date(timeIntervalSince1970: 1_800_000_000))
        let base = try #require(prepared.v2Context)
        var context = ActiveWorkoutV2Context(catalogVersion: "incompatible", decisionPolicyVersion: base.decisionPolicyVersion,
            mode: base.mode, durationMinutes: base.durationMinutes, estimatedSeconds: base.estimatedSeconds,
            plan: base.plan, inventory: base.inventory, supports: base.supports)
        context.automaticDurationExperiment = true
        let snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: context)
        let record = try ActiveWorkoutRecord(snapshot: snapshot)
        let loaded = try ActiveSessionCoordinator.load(record)
        #expect(!loaded.v2ContextIsCompatible)
        #expect(loaded.snapshot == snapshot)
    }

    @Test("Only explicitly automatic snapshots preserve unstarted work after the estimate")
    func estimateIsNotDeadline() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(inventory: [
            .init(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
            .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8], supportedConfigurations: ["pair", "single", "central", "unilateral"])
        ], durationMinutes: 30, engineVersion: .previewV2,
        todaySupports: ["floor_allowed", "wall_or_stable_plane", "stable_hand_support"], now: now)
        let initial = try #require(prepared.v2Context)
        var counts: [Int] = []
        for flag: Bool? in [nil, false, true] {
            var context = initial
            context.automaticDurationExperiment = flag
            var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: context, now: now)
            snapshot = ActiveSessionCoordinator.confirmLoad(snapshot, exerciseKey: initial.plan[0].exerciseId, perUnitWeightKg: initial.plan[0].load?.kg, inventory: [
                .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8], supportedConfigurations: ["pair", "single", "central", "unilateral"])
            ])
            snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: initial.plan[0].targetReps, now: now.addingTimeInterval(1))
            #expect(snapshot.recordedSets.count == 1)
            let facts = snapshot.recordedSets
            let encoded = try JSONEncoder().encode(snapshot)
            snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: encoded)
            #expect(snapshot.v2Context?.automaticDurationExperiment == flag)
            snapshot = ActiveSessionCoordinator.completeRest(snapshot, now: now.addingTimeInterval(3_600))
            #expect(snapshot.recordedSets.map(\.eventID) == facts.map(\.eventID))
            #expect(snapshot.recordedSets.map(\.repetitions) == facts.map(\.repetitions))
            counts.append(snapshot.totalSetCount)
            if flag == true {
                #expect(snapshot.totalSetCount == prepared.decision.movements?.reduce(0, { $0 + $1.sets }))
                #expect(!snapshot.isFinished)
            }
        }
        #expect(counts[0] == counts[1])
        #expect(counts[2] > counts[0])
    }
}
