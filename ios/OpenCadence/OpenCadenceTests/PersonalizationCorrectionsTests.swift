import CadenceEngine
import Foundation
import Testing
@testable import OpenCadence

@MainActor
struct PersonalizationCorrectionsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let body = EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
    let weights = EquipmentItem(category: "adjustable_dumbbell", units: 2,
        perUnitWeightsKg: [4, 6, 8], supportedConfigurations: ["single", "pair"])
    let row = "supported_one_arm_row__adjustable"
    func prepare(_ equipment: [EquipmentItem]? = nil) -> PreparedWorkout {
        WorkoutEngineBridge.prepareWorkout(inventory: equipment ?? [body, weights], durationMinutes: 30,
            engineVersion: .previewV2, todaySupports: ["floor_allowed", "stable_hand_support", "stable_incline_support"],
            person: .init(sessionId: "corrections"), now: now)
    }
    @Test func lastLoadSetsAndVariantSurviveRegenerationAndRestoration() throws {
        let first = prepare()
        var state = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        for kg in [6.0, 8.0] {
            state = try NativePersonalization.adjust(state, exerciseID: row, choice: .load(.init(mode: .singleTotalKg, kg: kg)),
                scope: .today, declaration: nil, history: [], now: now)
        }
        state = try NativePersonalization.adjust(state, exerciseID: row, choice: .sets(3), scope: .today, declaration: nil, history: [], now: now)
        state = try NativePersonalization.adjust(state, exerciseID: "dumbbell_romanian_deadlift__adjustable",
            choice: .load(.init(mode: .pairEachKg, kg: 6)), scope: .today, declaration: nil, history: [], now: now)
        state = try NativePersonalization.adjust(state, exerciseID: "dumbbell_romanian_deadlift__adjustable",
            choice: .variant("glute_bridge"), scope: .today, declaration: nil, history: [], now: now)
        #expect(state.confirmedLoads["dumbbell_romanian_deadlift__adjustable"] == nil)
        state = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(state))
        let next = try NativePersonalization.replaceBeforeFirstSet(state, with: prepare(), now: now)
        let chosen = try #require(next.v2Context?.plan.first { $0.exerciseId == row })
        #expect(chosen.load?.kg == 8 && chosen.sets == 3)
        #expect(next.v2Context?.plan.contains { $0.exerciseId == "glute_bridge" } == true)
        #expect(next.v2Context?.personalization?.incompatibleChoices?.isEmpty == true)
        let repeatNext = try NativePersonalization.replaceBeforeFirstSet(next, with: prepare(), now: now)
        #expect(repeatNext.v2Context?.plan == next.v2Context?.plan)
        let withoutWeights = try NativePersonalization.replaceBeforeFirstSet(state, with: prepare([body]), now: now)
        #expect(withoutWeights.v2Context?.plan.allSatisfy { $0.load?.kg == nil } == true)
        #expect(withoutWeights.v2Context?.personalization?.incompatibleChoices?.contains(row) == true)
    }
    @Test func targetIsFrozenAtStartAndLegacyUnknownStaysUnknown() throws {
        let first = prepare()
        var state = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        state = ActiveSessionCoordinator.confirmLoad(state, exerciseKey: row, perUnitWeightKg: 4, inventory: [body, weights])
        state = ActiveSessionCoordinator.startSet(state, now: now)
        let target = try #require(state.startedPrescriptionReps)
        let original = try #require(state.v2Context?.plan.first)
        // Even a future erroneous change to the plan must not rewrite the started target.
        state.v2Context?.plan[0] = .init(exerciseId: original.exerciseId, sets: original.sets, targetReps: target + 3,
            restSeconds: original.restSeconds, load: original.load, referenceStatus: original.referenceStatus,
            progressionContext: original.progressionContext)
        state = ActiveSessionCoordinator.recordSet(state, repetitions: 7, now: now.addingTimeInterval(30))
        #expect(state.recordedSets.first?.prescribedRepetitions == target)
        let payload = WorkoutHistoryBuilder.payload(from: ActiveSessionCoordinator.endEarly(state, now: now.addingTimeInterval(31)))
        let facts = WorkoutEngineBridge.migratedV2History(from: [payload])
        #expect(facts.first?.confirmedWorkEvidence?.first?.confirmedSets.first?.prescribedRepetitions == target)
        let old = CompletedSetRecord(eventID: "old", exerciseKey: row, repetitions: 8, perUnitWeightKg: 4,
            completedAt: now, plannedRestSeconds: nil, restEndedAt: nil)
        #expect(try JSONDecoder().decode(CompletedSetRecord.self, from: JSONEncoder().encode(old)).prescribedRepetitions == nil)
    }
    @Test func availableHingeAlternativeCanCompleteSingleDumbbellCoverage() throws {
        let single = EquipmentItem(category: "adjustable_dumbbell", units: 1, perUnitWeightsKg: [6], supportedConfigurations: ["single"])
        let first = prepare([body, single])
        #expect(first.personalizationResult?.coverage.missingPrimary.contains("hamstrings") == true)
        var state = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        let hinge = try #require(state.v2Context?.plan.first { V2EngineConfiguration.productPreview.catalog[$0.exerciseId]?.anchor == "hinge" })
        #expect(state.v2Context?.personalization?.options[hinge.exerciseId]?.contains { $0.exerciseId == "kickstand_romanian_deadlift__dumbbell" } == true)
        state = try NativePersonalization.adjust(state, exerciseID: hinge.exerciseId,
            choice: .variant("kickstand_romanian_deadlift__dumbbell"), scope: .today, declaration: nil, history: [], now: now)
        #expect(state.v2Context?.personalization?.coverage.missingPrimary.contains("hamstrings") == false)
    }
    @Test func endingDuringRestDoesNotMarkCompletedMovementSkipped() throws {
        let first = prepare()
        var state = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        state = ActiveSessionCoordinator.confirmLoad(state, exerciseKey: row, perUnitWeightKg: 4, inventory: [body, weights])
        // This regression covers a saved grouped session from before block support.
        state.v2Context?.personalization?.blocks = nil
        for index in 0..<2 {
            let at = now.addingTimeInterval(Double(index * 200))
            if index > 0 { state = ActiveSessionCoordinator.completeRest(state, now: at) }
            state = ActiveSessionCoordinator.startSet(state, now: at)
            state = ActiveSessionCoordinator.recordSet(state, repetitions: 8, now: at.addingTimeInterval(30))
        }
        let ended = ActiveSessionCoordinator.endEarly(state, now: now.addingTimeInterval(240))
        #expect(!ended.skippedExerciseKeys.contains(row))
        #expect(ended.recordedSets == state.recordedSets)
        let evidence = WorkoutEngineBridge.migratedV2History(from: [WorkoutHistoryBuilder.payload(from: ended)])
        #expect(evidence.first?.confirmedWorkEvidence?.first?.wasSkipped == false)
    }

    @Test func directLoadControlSurvivesAnotherLocalAdjustmentAndLocksDuringEffort() throws {
        let first = prepare()
        var state = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        state = ActiveSessionCoordinator.confirmLoad(state, exerciseKey: row, perUnitWeightKg: 6, inventory: [body, weights])
        state = try NativePersonalization.adjust(state, exerciseID: "dumbbell_floor_press__adjustable", choice: .sets(3),
            scope: .today, declaration: nil, history: [], now: now)
        #expect(state.v2Context?.plan.first { $0.exerciseId == row }?.load?.kg == 6)
        state = ActiveSessionCoordinator.startSet(state, now: now)
        #expect(ActiveSessionCoordinator.confirmLoad(state, exerciseKey: row, perUnitWeightKg: 8, inventory: [body, weights]) == state)
    }

}
