import CadenceEngine
import Foundation
import Testing
@testable import OpenCadence

@MainActor
struct HandoffJourneyTests {
    private let inventory = [
        EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
        EquipmentItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8], supportedConfigurations: ["single", "central", "unilateral", "pair"])
    ]
    private func initial() -> ActiveWorkoutSnapshot {
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory, durationMinutes: 30, engineVersion: .previewV2,
            todaySupports: ["floor_allowed", "stable_hand_support", "stable_incline_support", "overhead_clearance"]
        )
        return ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: .now)
    }

    @Test("Generated multi-movement fixture records only explicit sets across rest and snapshot restoration")
    func generatedJourney() throws {
        var snapshot = initial()
        #expect((snapshot.decision.movements?.count ?? 0) >= 3)
        let plannedCount = snapshot.totalSetCount
        var now = Date.now
        for _ in 0..<100 {
            if snapshot.isFinished { break }
            guard let movement = snapshot.currentMovement else { Issue.record("Missing current movement"); return }
            if let weight = WorkoutLoadResolver.options(for: movement, inventory: inventory).first {
                snapshot = ActiveSessionCoordinator.confirmLoad(snapshot, exerciseKey: movement.exerciseKey, perUnitWeightKg: weight, inventory: inventory)
            }
            snapshot.setStartedAt = now
            snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
            #expect(snapshot.setStartedAt == now)
            let before = snapshot.recordedSets.count
            snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: now)
            #expect(snapshot.recordedSets.count == before + 1)
            #expect(snapshot.setStartedAt == nil)
            if !snapshot.isFinished {
                let recorded = snapshot.recordedSets
                snapshot = ActiveSessionCoordinator.pauseRest(snapshot, now: now)
                snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
                snapshot = ActiveSessionCoordinator.resumeRest(snapshot, now: now)
                now = now.addingTimeInterval(1)
                snapshot = ActiveSessionCoordinator.completeRest(snapshot, now: now)
                #expect(snapshot.recordedSets == recorded.map { item in
                    var result = item
                    if result.plannedRestSeconds != nil && result.restEndedAt == nil { result.restEndedAt = now }
                    return result
                })
                #expect(snapshot.recordedSets.count == before + 1)
            }
        }
        #expect(snapshot.isFinished)
        #expect(snapshot.recordedSets.count == plannedCount)
        #expect(Set(snapshot.recordedSets.map(\.eventID)).count == plannedCount)
    }

    @Test("Skipping a started movement requires a fresh explicit start after snapshot restoration")
    func abandonStartedMovement() throws {
        var snapshot = initial()
        snapshot.setStartedAt = .now
        let first = snapshot.currentMovement?.exerciseKey
        snapshot = ActiveSessionCoordinator.skipCurrentMovement(snapshot)
        snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(snapshot.currentMovement?.exerciseKey != first)
        #expect(snapshot.setStartedAt == nil)
        #expect(snapshot.recordedSets.isEmpty)
    }
    @Test("A pain stop clears the explicit set start before recovery")
    func painClearsStart() throws {
        var snapshot = initial()
        snapshot.setStartedAt = .now
        snapshot = ActiveSessionCoordinator.reportPain(snapshot, score: 3)
        snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(snapshot.setStartedAt == nil)
        #expect(snapshot.unresolvedSafetyEvent != nil)
        #expect(snapshot.recordedSets.isEmpty)
    }

}
