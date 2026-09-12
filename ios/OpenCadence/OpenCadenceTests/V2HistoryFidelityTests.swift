import CadenceEngine
import Foundation
import SwiftData
import Testing
@testable import OpenCadence

@MainActor
struct V2HistoryFidelityTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var inventory: [EquipmentItem] {
        [.init(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
         .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10],
               supportedConfigurations: ["pair", "single", "central", "unilateral"])]
    }
    private let supports = ["wall_or_stable_plane", "floor_allowed", "stable_hand_support"]

    @Test("Native confirmed partial work survives persistence and projection without a capacity reference")
    func partialChain() throws {
        let snapshot = try fixture(confirmed: 1, planned: 3, at: now.addingTimeInterval(-86_400))
        let record = try persist(snapshot)
        let payload = try #require(record.payload)
        let entries = WorkoutEngineBridge.migratedV2History(from: [payload], source: .syntheticScenario)
        let entry = try #require(entries.first)
        let evidence = try #require(entry.confirmedWorkEvidence?.first)
        #expect(evidence.plannedSets == 3)
        #expect(evidence.confirmedSets.count == 1)
        #expect(evidence.source == .syntheticScenario)
        #expect(evidence.confirmedSets.first?.eventID == snapshot.recordedSets.first?.eventID)
        #expect(evidence.confirmedSets.first?.repetitions == snapshot.recordedSets.first?.repetitions)
        #expect(evidence.confirmedSets.first?.loadKg == snapshot.recordedSets.first?.perUnitWeightKg)
        #expect(entry.references == nil)
        #expect(entry.completedExerciseIds?.isEmpty != false)
        #expect(entry.restObservations?.count == 1)
        #expect(entry.catalogVersion == snapshot.v2Context?.catalogVersion)
        #expect(entry.endedAt == payload.endedAt.ISO8601Format())
        let next = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            completedWorkouts: [record], historyEvidenceSource: .syntheticScenario,
            engineVersion: .previewV2, todaySupports: supports, now: now)
        #expect(next.decision.decision == "generate_workout")
        #expect(record.payload?.snapshot.recordedSets == snapshot.recordedSets)
    }

    @Test("Projection processes exposure history chronologically regardless of caller order")
    func ordering() throws {
        let older = try #require(persist(fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-6 * 86_400))).payload)
        let newer = try #require(persist(fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-3 * 86_400))).payload)
        #expect(WorkoutEngineBridge.migratedV2History(from: [newer, older], source: .syntheticScenario)
            == WorkoutEngineBridge.migratedV2History(from: [older, newer], source: .syntheticScenario))
    }

    @Test("Old V2 versions keep their evidence and are never reinterpreted as V1 references")
    func oldVersion() throws {
        var snapshot = try fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-86_400))
        let context = try #require(snapshot.v2Context)
        snapshot.v2Context = ActiveWorkoutV2Context(catalogVersion: "older-catalog", decisionPolicyVersion: "older-policy",
            mode: context.mode, durationMinutes: context.durationMinutes, estimatedSeconds: context.estimatedSeconds,
            plan: context.plan, inventory: context.inventory, supports: context.supports)
        let payload = try #require(persist(snapshot).payload)
        let entry = try #require(WorkoutEngineBridge.migratedV2History(from: [payload], source: .syntheticScenario).first)
        #expect(entry.catalogVersion == "older-catalog")
        #expect(entry.decisionPolicyVersion == "older-policy")
        #expect(entry.references == nil && entry.completedExerciseIds == nil)
        #expect(entry.confirmedWorkEvidence?.first?.confirmedSets.count == 3)
        #expect(entry.restObservations?.count == 2)
    }

    @Test("Skipped and safety-interrupted work keep facts without becoming a capacity reference")
    func safetyAndSkip() throws {
        let base = try fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-86_400))
        let id = try #require(base.v2Context?.plan.first?.exerciseId)
        var skipped = base
        skipped.skippedExerciseKeys = [id]
        var safety = base
        safety.safetyEventRecords = [SafetyEventRecord(eventID: "fixture-safety", exerciseKey: id, kind: "pain",
            painScore: 3, alertCodes: [], reportedAt: now.addingTimeInterval(-86_350),
            transition: "stop_current_exercise", mustNotDiagnose: true)]
        for snapshot in [skipped, safety] {
            let payload = try #require(persist(snapshot).payload)
            let entry = try #require(WorkoutEngineBridge.migratedV2History(from: [payload], source: .syntheticScenario).first)
            #expect(entry.references == nil)
            #expect(entry.confirmedWorkEvidence?.first?.confirmedSets.count == 3)
            #expect(entry.confirmedWorkEvidence?.first?.wasSkipped == !snapshot.skippedExerciseKeys.isEmpty)
            #expect(entry.confirmedWorkEvidence?.first?.interruptedBySafetySignal == !snapshot.recordedSafetyEvents.isEmpty)
        }
    }

    @Test("An actually different load stays factual and cannot restore the prescribed load as a reference")
    func differentLoad() throws {
        var snapshot = try fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-86_400))
        let original = try #require(snapshot.recordedSets.first?.perUnitWeightKg)
        snapshot.setResults = snapshot.recordedSets.map { result in
            CompletedSetRecord(eventID: result.eventID, exerciseKey: result.exerciseKey,
                repetitions: result.repetitions, perUnitWeightKg: original + 2,
                completedAt: result.completedAt, plannedRestSeconds: result.plannedRestSeconds,
                restEndedAt: result.restEndedAt)
        }
        let payload = try #require(persist(snapshot).payload)
        let entry = try #require(WorkoutEngineBridge.migratedV2History(from: [payload], source: .syntheticScenario).first)
        #expect(entry.references == nil)
        #expect(entry.confirmedWorkEvidence?.first?.confirmedSets.allSatisfy { $0.loadKg == original + 2 } == true)
    }

    @Test("Legacy history JSON retains unknown volume instead of fabricating zero")
    func missingEvidenceDecodes() throws {
        let data = Data(#"{"endedAt":"2026-01-01T00:00:00Z","catalogVersion":"old","decisionPolicyVersion":"old"}"#.utf8)
        let entry = try JSONDecoder().decode(V2HistoryEntry.self, from: data)
        #expect(entry.confirmedWorkEvidence == nil)
    }

    @Test("Three recovered partial rest observations use the existing rest rule, not a new volume rule")
    func partialRestConsequence() throws {
        let records = try [6, 4, 2].map { days in
            try persist(fixture(confirmed: 1, planned: 3, at: now.addingTimeInterval(-Double(days) * 86_400)))
        }
        let entries = WorkoutEngineBridge.migratedV2History(from: records.compactMap(\.payload), source: .syntheticScenario)
        #expect(entries.count == 3)
        #expect(entries.flatMap { $0.restObservations ?? [] }.count == 3)
        #expect(entries.allSatisfy { $0.references == nil })
        let first = try #require(records.first?.payload?.snapshot.v2Context?.plan.first)
        let before = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            engineVersion: .previewV2, todaySupports: supports, now: now)
        let after = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            completedWorkouts: records, historyEvidenceSource: .syntheticScenario,
            engineVersion: .previewV2, todaySupports: supports, now: now)
        let beforeRow = try #require(before.v2Context?.plan.first { $0.progressionContext == first.progressionContext })
        let afterRow = try #require(after.v2Context?.plan.first { $0.progressionContext == first.progressionContext })
        #expect(afterRow.restSeconds >= beforeRow.restSeconds)
        #expect(afterRow.load == beforeRow.load)
        #expect(afterRow.targetReps == beforeRow.targetReps)
        print("HISTORY_PARTIAL_REST before=\(beforeRow.restSeconds) after=\(afterRow.restSeconds) beforeSets=\(beforeRow.sets) afterSets=\(afterRow.sets)")
    }

    @Test("Evidence-only partial entries do not consume completed-session anchor depth")
    func partialDoesNotEvictCompletedDepth() throws {
        let complete = try #require(persist(fixture(confirmed: 3, planned: 3, at: now.addingTimeInterval(-6 * 86_400))).payload)
        let partial = try #require(persist(fixture(confirmed: 1, planned: 3, at: now.addingTimeInterval(-2 * 86_400))).payload)
        let projected = WorkoutEngineBridge.migratedV2History(from: [complete, partial], source: .syntheticScenario)
        #expect(projected.count == 2)
        #expect(projected.last?.references == nil)
        #expect(projected.last?.completedExerciseIds?.isEmpty != false)
        let base = V2EngineConfiguration.productPreview
        let policy = V2DecisionPolicy(durationBudgetsSeconds: base.policy.durationBudgetsSeconds,
            historyDepthCompletedSessions: 1,
            returnQuestionAfterDaysWithoutComparableExposure: base.policy.returnQuestionAfterDaysWithoutComparableExposure,
            anchorTieOrder: base.policy.anchorTieOrder, rangeCeilingConfirmations: base.policy.rangeCeilingConfirmations)
        let configuration = V2EngineConfiguration(catalogVersion: base.catalogVersion,
            decisionPolicyVersion: base.decisionPolicyVersion, catalog: base.catalog,
            substitutions: base.substitutions, policy: policy, requiresProductApproval: base.requiresProductApproval)
        let v2Inventory = try #require(complete.snapshot.v2Context?.inventory)
        func plan(_ entries: [V2HistoryEntry]) throws -> [String] {
            let result = CadenceEngine.decideV2(request: .sessionDecision(.init(
                request: .init(durationMinutes: 30), persistentInventory: v2Inventory,
                todayInventory: v2Inventory, todaySupports: supports, history: entries), now: now), configuration: configuration)
            guard case .sessionDecision(let decision) = result else { Issue.record("Expected session decision"); return [] }
            #expect(!decision.plan.isEmpty)
            return decision.plan.map(\.exerciseId)
        }
        #expect(try plan([projected[0]]) == plan(projected))
    }

    private func fixture(confirmed: Int, planned: Int, at start: Date) throws -> ActiveWorkoutSnapshot {
        let prepared = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            engineVersion: .previewV2, todaySupports: supports, now: start)
        var context = try #require(prepared.v2Context)
        let item = try #require(context.plan.first)
        let movement = try #require(prepared.decision.movements?.first { $0.exerciseKey == item.exerciseId })
        context.plan = [.init(exerciseId: item.exerciseId, sets: planned, targetReps: item.targetReps,
            restSeconds: item.restSeconds, load: item.load, referenceStatus: item.referenceStatus,
            progressionContext: item.progressionContext, targetUnit: item.targetUnit)]
        var decision = prepared.decision
        decision.movements = [.init(exerciseKey: movement.exerciseKey, variant: movement.variant, pattern: movement.pattern,
            sets: planned, target: movement.target, restSeconds: movement.restSeconds, equipment: movement.equipment)]
        var snapshot = ActiveSessionCoordinator.start(decision: decision, v2Context: context, now: start)
        snapshot = ActiveSessionCoordinator.confirmLoad(snapshot, exerciseKey: item.exerciseId,
            perUnitWeightKg: item.load?.kg, inventory: inventory)
        for index in 0..<confirmed {
            snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: item.targetReps,
                now: start.addingTimeInterval(Double(index * 240 + 1)))
            if snapshot.restDeadline != nil {
                snapshot = ActiveSessionCoordinator.completeRest(snapshot,
                    now: start.addingTimeInterval(Double(index * 240 + 181)))
            }
        }
        #expect(snapshot.recordedSets.count == confirmed)
        if !snapshot.isFinished { snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: start.addingTimeInterval(1_200)) }
        return snapshot
    }

    private func persist(_ snapshot: ActiveWorkoutSnapshot) throws -> CompletedWorkoutRecord {
        let container = try ModelContainer(for: ActiveWorkoutRecord.self, CompletedWorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let active = try ActiveWorkoutRecord(snapshot: snapshot)
        context.insert(active)
        try context.save()
        try WorkoutCompletionCoordinator.save(snapshot: snapshot, activeRecord: active, context: context)
        let saved = try #require(context.fetch(FetchDescriptor<CompletedWorkoutRecord>()).first)
        // Return a detached copy, preserving the payload after this in-memory store is released.
        let payload = try #require(saved.payload)
        return try CompletedWorkoutRecord(payload: payload)
    }
}
