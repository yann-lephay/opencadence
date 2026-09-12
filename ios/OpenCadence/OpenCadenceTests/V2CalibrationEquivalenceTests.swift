import CadenceEngine
import Foundation
import SwiftData
import Testing
@testable import OpenCadence

@MainActor
struct V2CalibrationEquivalenceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("V2 preparation ignores calibration answers for identical declared inputs", arguments: [20, 30, 45])
    func v2CalibrationEquivalence(duration: Int) throws {
        for mode in [V2SessionMode.normal, .light, .recalibration] {
            let baseline = prepare(duration: duration, mode: mode, calibration: nil, explicit: false)
            #expect(baseline.decision.decision == "generate_workout")
            let context = try #require(baseline.v2Context)
            #expect(!context.plan.isEmpty)
            for upper in ["foundation", "established"] {
                for lower in ["foundation", "established"] {
                    let candidate = prepare(duration: duration, mode: mode,
                        calibration: .init(upper: upper, lower: lower), explicit: true)
                    #expect(candidate == baseline)
                }
            }
            // Stored values without explicit confirmation must also remain neutral in V2.
            #expect(prepare(duration: duration, mode: mode,
                calibration: .init(upper: "established", lower: "foundation"), explicit: false) == baseline)
            print("CALIBRATION_EQ duration=\(duration) mode=\(mode.rawValue) decision=\(baseline.decision.decision) movements=\(context.plan.map(\.exerciseId)) seconds=\(context.estimatedSeconds)")
        }
    }

    @Test("V2 calibration stays neutral with confirmed multi-movement history", arguments: [20, 30, 45])
    func v2CalibrationWithHistory(duration: Int) throws {
        let history = try completedHistory()
        let originalPayloads = history.map(\.payloadData)
        #expect(history.count == 2)
        #expect(history.allSatisfy { ($0.payload?.snapshot.recordedSets.count ?? 0) > 1 })
        for mode in [V2SessionMode.normal, .light, .recalibration] {
            let baseline = prepare(duration: duration, mode: mode, calibration: nil, explicit: false, history: history)
            let plan = try #require(baseline.v2Context?.plan)
            #expect(baseline.decision.decision == "generate_workout")
            if mode == .normal { #expect(plan.contains { $0.referenceStatus == "kept" }) }
            for upper in ["foundation", "established"] {
                for lower in ["foundation", "established"] {
                    #expect(prepare(duration: duration, mode: mode,
                        calibration: .init(upper: upper, lower: lower), explicit: true, history: history) == baseline)
                }
            }
            #expect(prepare(duration: duration, mode: mode,
                calibration: .init(upper: "established", lower: "foundation"), explicit: false, history: history) == baseline)
            #expect(history.map(\.payloadData) == originalPayloads)
            print("CALIBRATION_HISTORY_EQ duration=\(duration) mode=\(mode.rawValue) plan=\(plan.map { "\($0.exerciseId):\($0.sets)x\($0.targetReps):\($0.referenceStatus)" })")
        }
    }

    @Test("V2 history preserves confirmed volume without changing the existing prescription policy")
    func historyProjectionVolumeBoundary() throws {
        let start = now.addingTimeInterval(-3 * 86_400)
        let prepared = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            engineVersion: .previewV2, todaySupports: supports, now: start)
        let baseContext = try #require(prepared.v2Context)
        let tracked = try #require(baseContext.plan.first)
        let movement = try #require(prepared.decision.movements?.first { $0.exerciseKey == tracked.exerciseId })
        func payload(sets: Int) -> CompletedWorkoutPayload {
            var modifiedContext = baseContext
            modifiedContext.plan = [.init(exerciseId: tracked.exerciseId, sourceExerciseId: tracked.sourceExerciseId,
                sets: sets, targetReps: tracked.targetReps, restSeconds: tracked.restSeconds,
                load: tracked.load, referenceStatus: tracked.referenceStatus,
                progressionContext: tracked.progressionContext, targetUnit: tracked.targetUnit)]
            var decision = prepared.decision
            decision.movements = [.init(exerciseKey: movement.exerciseKey, variant: movement.variant,
                pattern: movement.pattern, sets: sets, target: movement.target,
                restSeconds: movement.restSeconds, equipment: movement.equipment)]
            var snapshot = ActiveSessionCoordinator.start(decision: decision, v2Context: modifiedContext, now: start)
            snapshot.setResults = (0..<sets).map { index in
                CompletedSetRecord(eventID: "volume-\(sets)-\(index)", exerciseKey: tracked.exerciseId,
                    repetitions: tracked.targetReps, perUnitWeightKg: tracked.load?.kg,
                    completedAt: start.addingTimeInterval(Double(index + 1)),
                    plannedRestSeconds: nil, restEndedAt: nil)
            }
            snapshot.completedSetCount = sets
            snapshot.isFinished = true
            snapshot.endedAt = start.addingTimeInterval(1_200)
            return WorkoutHistoryBuilder.payload(from: snapshot)
        }
        let one = payload(sets: 1)
        let three = payload(sets: 3)
        #expect(one.snapshot.recordedSets.count == 1)
        #expect(three.snapshot.recordedSets.count == 3)
        let oneProjection = WorkoutEngineBridge.migratedV2History(from: [one], source: .syntheticScenario)
        let threeProjection = WorkoutEngineBridge.migratedV2History(from: [three], source: .syntheticScenario)
        #expect(!(oneProjection.first?.references?.isEmpty ?? true))
        #expect(oneProjection != threeProjection)
        #expect(oneProjection.first?.confirmedWorkEvidence?.first?.confirmedSets.count == 1)
        #expect(threeProjection.first?.confirmedWorkEvidence?.first?.confirmedSets.count == 3)
        #expect(oneProjection.first?.references == threeProjection.first?.references)
        let oneNext = prepare(duration: 30, mode: .normal, calibration: nil, explicit: false,
            history: [try CompletedWorkoutRecord(payload: one)])
        let threeNext = prepare(duration: 30, mode: .normal, calibration: nil, explicit: false,
            history: [try CompletedWorkoutRecord(payload: three)])
        #expect(oneNext == threeNext)
        print("CALIBRATION_VOLUME_BOUNDARY confirmed=1_vs_3 projection_equal=false next_equal=true exercise=\(tracked.exerciseId)")
    }

    private func completedHistory() throws -> [CompletedWorkoutRecord] {
        var history: [CompletedWorkoutRecord] = []
        for daysAgo in [6, 3] {
            let start = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            let prepared = WorkoutEngineBridge.prepareWorkout(
                inventory: inventory, durationMinutes: 30, completedWorkouts: history,
                engineVersion: .previewV2, todaySupports: supports, now: start)
            let context = try #require(prepared.v2Context)
            #expect(context.plan.count > 1)
            var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: context, now: start)
            snapshot.setResults = context.plan.flatMap { item in
                (0..<item.sets).map { index in
                    CompletedSetRecord(eventID: "fixture-\(daysAgo)-\(item.exerciseId)-\(index)",
                        exerciseKey: item.exerciseId, repetitions: item.targetReps,
                        perUnitWeightKg: item.load?.kg,
                        completedAt: start.addingTimeInterval(Double(index + 1)),
                        plannedRestSeconds: nil, restEndedAt: nil)
                }
            }
            snapshot.completedSetCount = snapshot.recordedSets.count
            snapshot.isFinished = true
            snapshot.endedAt = start.addingTimeInterval(1_200)
            history.append(try CompletedWorkoutRecord(payload: WorkoutHistoryBuilder.payload(from: snapshot)))
        }
        return history
    }

    @Test("V1 setup still requires explicit markers and V2 preparation preserves persisted answers")
    func v1GuardAndStoredAnswers() throws {
        let container = try ModelContainer(for: UserSetupRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let setup = try UserSetupRecord(inventory: inventory, selectedDuration: 30, updatedAt: now)
        context.insert(setup)
        try context.save()
        #expect(setup.requiresCalibration)
        #expect(!setup.usesExplicitCalibration)
        #expect(setup.upperCalibration == nil && setup.lowerCalibration == nil)
        #expect(WorkoutEngineRuntime.selectedVersion(arguments: ["-OpenCadenceForceV1"]) == .productionV1)

        setup.upperCalibration = "established"
        setup.lowerCalibration = "foundation"
        setup.calibrationCompletedAt = now
        try context.save()
        let originalInventory = setup.inventoryData
        #expect(!setup.requiresCalibration)
        #expect(setup.usesExplicitCalibration)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: setup.inventory, durationMinutes: setup.selectedDuration,
            calibrations: setup.calibrations, calibrationIsExplicit: setup.usesExplicitCalibration,
            engineVersion: .previewV2, todaySupports: supports, now: now)
        #expect(prepared.decision.decision == "generate_workout")
        let saved = try #require(context.fetch(FetchDescriptor<UserSetupRecord>()).first)
        #expect(saved.upperCalibration == "established")
        #expect(saved.lowerCalibration == "foundation")
        #expect(saved.calibrationCompletedAt == now)
        #expect(saved.inventoryData == originalInventory)
        #expect(saved.selectedDuration == 30)
        #expect(saved.updatedAt == now)
    }

    @Test("V1 still consumes explicit calibration instead of silently adopting V2 neutrality")
    func v1StillUsesCalibration() {
        let foundation = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory, durationMinutes: 30,
            calibrations: .init(upper: "foundation", lower: "foundation"), calibrationIsExplicit: true,
            engineVersion: .productionV1, todaySupports: supports, now: now)
        let mixed = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory, durationMinutes: 30,
            calibrations: .init(upper: "established", lower: "foundation"), calibrationIsExplicit: true,
            engineVersion: .productionV1, todaySupports: supports, now: now)
        #expect(foundation.decision.decision == "generate_workout")
        #expect(mixed.decision.decision == "generate_workout")
        #expect(foundation.decision.planProfileId == "foundation-foundation-12")
        #expect(foundation.decision != mixed.decision)
        #expect(foundation.decision.reasonCodes.contains("calibration.user_selected_variants"))
        #expect(mixed.decision.reasonCodes.contains("calibration.user_selected_variants"))
        #expect(foundation.v2Context == nil && mixed.v2Context == nil)
        print("CALIBRATION_V1 foundation=\(foundation.decision.planProfileId ?? "nil") mixed=\(mixed.decision.planProfileId ?? "nil")")
    }

    private func prepare(duration: Int, mode: V2SessionMode, calibration: Calibrations?, explicit: Bool, history: [CompletedWorkoutRecord] = []) -> PreparedWorkout {
        WorkoutEngineBridge.prepareWorkout(
            inventory: inventory, durationMinutes: duration, completedWorkouts: history,
            historyEvidenceSource: .syntheticScenario,
            calibrations: calibration, calibrationIsExplicit: explicit,
            engineVersion: .previewV2, todaySupports: supports, previewMode: mode, now: now)
    }

    private var supports: [String] {
        ["wall_or_stable_plane", "floor_allowed", "stable_hand_support"]
    }

    private var inventory: [EquipmentItem] {
        [
            .init(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
            .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10],
                  supportedConfigurations: ["pair", "single", "central", "unilateral"])
        ]
    }
}
