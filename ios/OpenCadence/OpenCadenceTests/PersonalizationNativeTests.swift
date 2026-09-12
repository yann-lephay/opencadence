import CadenceEngine
import Foundation
import SwiftData
import Testing
@testable import OpenCadence

@MainActor
struct PersonalizationNativeTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let inventory = [EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])]
    let supports = ["floor_allowed", "solid_wall", "wall_or_stable_plane", "stable_incline_support", "stable_hand_support", "seated_support"]

    func prepared(practice: V2StrengthPractice? = nil, knowledge: [V2MovementKnowledge] = [],
                  history: [CompletedWorkoutRecord] = [], at: Date? = nil) -> PreparedWorkout {
        WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 20,
            completedWorkouts: history, engineVersion: .previewV2, todaySupports: supports,
            person: .init(sessionId: UUID().uuidString, practice: practice, knowledge: knowledge), now: at ?? now)
    }

    @Test("Native preparation uses local familiarity and session identity")
    func preparationAndPractice() throws {
        let first = prepared(practice: .regular)
        let context = try #require(first.v2Context)
        #expect(context.personalization != nil)
        #expect(context.plan.allSatisfy { $0.sets == 2 })
        let knowledge = context.plan.map { V2MovementKnowledge(exerciseId: $0.exerciseId,
            progressionContext: $0.progressionContext, familiar: true, at: now,
            catalogVersion: context.catalogVersion) }
        let known = try #require(prepared(practice: .regular, knowledge: knowledge).v2Context)
        #expect(known.plan.allSatisfy { $0.sets == 3 })
        let snapshot = ActiveSessionCoordinator.start(decision: first.decision, v2Context: context, now: now)
        #expect(snapshot.sessionID == context.personalization?.person.sessionId)
        #expect(try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
    }

    @Test("A rest adjustment preserves confirmed work, timer and restoration")
    func restAndConfirmedWork() throws {
        let initial = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: initial.decision, v2Context: initial.v2Context, now: now)
        snapshot.setStartedAt = now
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: now.addingTimeInterval(30))
        let id = try #require(snapshot.currentMovement?.exerciseKey)
        let adjusted = try NativePersonalization.adjust(snapshot, exerciseID: id, choice: .sets(3), scope: .today,
            declaration: nil, history: [], now: now.addingTimeInterval(35))
        #expect(adjusted.recordedSets == snapshot.recordedSets)
        #expect(adjusted.restDeadline == snapshot.restDeadline)
        #expect(adjusted.processedEventIDs == snapshot.processedEventIDs)
        #expect(adjusted.currentMovement?.sets == 3)
        #expect(adjusted.completedSetsInMovement == 1)
        let container = try ModelContainer(for: UserSetupRecord.self, ActiveWorkoutRecord.self, CompletedWorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let record = try ActiveWorkoutRecord(snapshot: snapshot)
        container.mainContext.insert(record)
        try ActiveSessionCoordinator.persist(adjusted, in: record, context: container.mainContext)
        #expect(try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: record.snapshotData) == adjusted)
        let continued = ActiveSessionCoordinator.completeRest(adjusted, now: now.addingTimeInterval(3600))
        #expect(continued.v2Context?.plan == adjusted.v2Context?.plan)
        #expect(continued.currentMovementIndex == ActiveSessionCoordinator.nextMovementIndex(adjusted))
        #expect(continued.setStartedAt == nil)
    }

    @Test("Running set refuses adjustments")
    func runningSet() throws {
        let initial = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: initial.decision, v2Context: initial.v2Context, now: now)
        snapshot.setStartedAt = now
        let id = try #require(snapshot.currentMovement?.exerciseKey)
        #expect(throws: NativePersonalization.AdjustmentError.self) {
            try NativePersonalization.adjust(snapshot, exerciseID: id, choice: .sets(3), scope: .today, declaration: nil, history: [], now: now)
        }
    }

    @Test("A usual volume choice cannot persist today's capacity")
    func durableIsolation() throws {
        let row = try #require(prepared().v2Context?.plan.first)
        let temporary = V2MovementKnowledge(exerciseId: row.exerciseId, progressionContext: row.progressionContext,
            familiar: true, usualSets: 3, declaredReps: 12, at: now, catalogVersion: V2EngineConfiguration.productPreview.catalogVersion)
        let durable = NativePersonalization.durableKnowledge([], exerciseID: row.exerciseId, choice: .sets(3), declaration: nil, result: [temporary])
        #expect(durable.first?.usualSets == 3)
        #expect(durable.first?.declaredReps == nil)
        #expect(durable.first?.familiar == false)
    }

    @Test("Absent personal data migrates; corrupt personal data stays an error")
    func additiveStorage() throws {
        let setup = try UserSetupRecord(inventory: inventory)
        #expect(try setup.movementKnowledge().isEmpty)
        setup.movementKnowledgeData = Data("broken".utf8)
        #expect(throws: DecodingError.self) { try setup.movementKnowledge() }
        let initial = WorkoutEngineBridge.prepareWorkout(inventory: inventory, durationMinutes: 30,
            engineVersion: .previewV2, todaySupports: supports, now: now)
        #expect(initial.v2Context?.personalization == nil)
    }

    @Test("Second and third preparation learn from real native confirmations")
    func threeSessions() throws {
        let first = prepared(practice: .regular)
        var snapshot = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: now)
        snapshot.setStartedAt = now
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: now.addingTimeInterval(30))
        snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: now.addingTimeInterval(40))
        let payload = WorkoutHistoryBuilder.payload(from: snapshot)
        let record = try CompletedWorkoutRecord(payload: payload)
        let second = prepared(practice: .regular, history: [record], at: now.addingTimeInterval(86400))
        let id = try #require(snapshot.recordedSets.first?.exerciseKey)
        #expect(second.v2Context?.plan.first(where: { $0.exerciseId == id })?.sets == 3)
        #expect(second.personalizationResult?.checks.contains(where: { $0.exerciseId == id }) == false)
        let third = prepared(practice: .regular, history: [record], at: now.addingTimeInterval(172800))
        #expect(third.v2Context?.plan.first(where: { $0.exerciseId == id })?.sets == 3)
        #expect(third.personalizationResult?.checks.contains(where: { $0.exerciseId == id }) == false)
    }
    @Test("Replacing an exercise retains the original incomplete prescription")
    func replacementProvenance() throws {
        let initial = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: initial.decision, v2Context: initial.v2Context, now: now)
        let personal = try #require(initial.v2Context?.personalization)
        let pair = try #require(personal.options.first { $0.value.contains { !$0.requiresCapacityAnswer } })
        let replacement = try #require(pair.value.first { !$0.requiresCapacityAnswer })
        snapshot.currentMovementIndex = try #require(snapshot.decision.movements?.firstIndex { $0.exerciseKey == pair.key })
        snapshot = try NativePersonalization.adjust(snapshot, exerciseID: pair.key, choice: .sets(3), scope: .today,
            declaration: nil, history: [], now: now)
        snapshot.currentMovementIndex = try #require(snapshot.decision.movements?.firstIndex { $0.exerciseKey == pair.key })
        snapshot.setStartedAt = now
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: now.addingTimeInterval(30))
        let adjusted = try NativePersonalization.adjust(snapshot, exerciseID: pair.key, choice: .variant(replacement.exerciseId),
            scope: .today, declaration: nil, history: [], now: now.addingTimeInterval(31))
        #expect(adjusted.recordedSets == snapshot.recordedSets)
        #expect(adjusted.restDeadline == snapshot.restDeadline)
        let ended = ActiveSessionCoordinator.endEarly(adjusted, now: now.addingTimeInterval(40))
        let migrated = WorkoutEngineBridge.migratedV2History(from: [WorkoutHistoryBuilder.payload(from: ended)])
        let evidence = migrated.flatMap { $0.confirmedWorkEvidence ?? [] }.first { $0.exerciseId == pair.key }
        #expect(!migrated.flatMap { $0.completedExerciseIds ?? [] }.contains(pair.key))
        #expect(!migrated.flatMap { $0.references ?? [] }.contains { $0.exerciseId == pair.key })
        #expect(evidence?.plannedSets == 3)
        #expect(evidence?.confirmedSets.count == 1)
    }

    @Test("Release adjustments retain release catalogue restrictions")
    func releaseAdjustment() throws {
        let initial = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: initial.decision, v2Context: initial.v2Context, now: now)
        snapshot.v2Context?.personalization?.releaseConfiguration = true
        let id = try #require(snapshot.currentMovement?.exerciseKey)
        do {
            let adjusted = try NativePersonalization.adjust(snapshot, exerciseID: id, choice: .sets(3), scope: .today,
                declaration: nil, history: [], now: now)
            #expect(adjusted.v2Context?.personalization?.releaseConfiguration == true)
            #expect(adjusted.v2Context?.plan.allSatisfy { V2EngineConfiguration.releaseV2.catalog[$0.exerciseId] != nil } == true)
        } catch {
            Issue.record("Approved release adaptation must succeed: \(error)")
        }
    }

    @Test("Current assisted movement exposes real assistance options")
    func currentAssistanceLoads() {
        let inventory = [V2InventoryItem(category: "resistance_band", units: 1, optionIDs: ["synthetic-band"])]
        let loads = CadenceEngine.personalizationLoads(exerciseId: "band_assisted_pull_up", inventory: inventory,
            configuration: .productPreview)
        #expect(loads.map(\.optionID) == ["synthetic-band"])
        #expect(loads.allSatisfy { $0.kg == nil })
    }

    @Test("Automatic preparation reaches a ready movement without starting effort or rest")
    func directReadyStart() throws {
        let prepared = prepared()
        let snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: now)
        #expect(snapshot.currentMovement != nil)
        #expect(snapshot.recordedSets.isEmpty)
        #expect(snapshot.setStartedAt == nil)
        #expect(snapshot.restDeadline == nil)
        let updated = try NativePersonalization.replaceBeforeFirstSet(snapshot, with: prepared)
        #expect(updated.sessionID == snapshot.sessionID)
        #expect(updated.setStartedAt == nil)
        #expect(updated.recordedSets.isEmpty)
    }

    @Test("Global settings cannot regenerate started or confirmed work")
    func preferenceBoundary() throws {
        let prepared = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: now)
        snapshot.setStartedAt = now
        #expect(throws: NativePersonalization.AdjustmentError.self) {
            try NativePersonalization.replaceBeforeFirstSet(snapshot, with: prepared)
        }
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: now.addingTimeInterval(30))
        #expect(throws: NativePersonalization.AdjustmentError.self) {
            try NativePersonalization.replaceBeforeFirstSet(snapshot, with: prepared)
        }
    }

    @Test("Familiarity can be unchecked without erasing or dating today's capacity")
    func familiarityRoundTrip() throws {
        let config = V2EngineConfiguration.productPreview
        let exercise = try #require(config.catalog["pull_up"])
        let today = V2MovementKnowledge(exerciseId: "pull_up", progressionContext: exercise.progressionContext,
            declaredReps: 5, at: now, catalogVersion: config.catalogVersion)
        let checked = NativePersonalization.settingFamiliarity([today], exerciseID: "pull_up", familiar: true, configuration: config)
        let unchecked = NativePersonalization.settingFamiliarity(checked, exerciseID: "pull_up", familiar: false, configuration: config)
        #expect(checked.first?.familiar == true)
        #expect(unchecked == [today])
        let durable = NativePersonalization.settingFamiliarity([], exerciseID: "pull_up", familiar: true, configuration: config)
        #expect(durable.first?.declaredReps == nil)
    }

}

extension PersonalizationNativeTests {
    @Test func asymmetricBlocksRestoreSkipAndStopWithoutLosingWork() throws {
        let initial = prepared()
        var snapshot = ActiveSessionCoordinator.start(decision: initial.decision, v2Context: initial.v2Context, now: now)
        let block = try #require(snapshot.v2Context?.personalization?.blocks?.first { $0.count == 2 })
        let a = block[0], b = block[1]
        snapshot = try NativePersonalization.adjust(snapshot, exerciseID: a, choice: .sets(3), scope: .today,
            declaration: nil, history: [], now: now)
        // Focus this test on one pair; other blocks are deliberately skipped.
        snapshot.skippedExerciseKeys = (snapshot.decision.movements ?? []).map(\.exerciseKey).filter { !block.contains($0) }
        snapshot.currentMovementIndex = try #require(ActiveSessionCoordinator.nextMovementIndex(snapshot))
        // Distinct rests expose an incorrect "last row" duration calculation.
        var context = try #require(snapshot.v2Context)
        context.plan = context.plan.map { row in
            .init(exerciseId: row.exerciseId, sets: row.sets, targetReps: row.targetReps,
                restSeconds: row.exerciseId == a ? 60 : 120, load: row.load,
                referenceStatus: row.referenceStatus, progressionContext: row.progressionContext)
        }
        snapshot.v2Context = context
        snapshot.decision = WorkoutEngineBridge.legacyDecision(from: .init(catalogVersion: context.catalogVersion,
            decisionPolicyVersion: context.decisionPolicyVersion, decision: .generateSession, mode: context.mode,
            plan: context.plan), limitations: [], migratedHistory: false, configuration: .productPreview)
        let config = V2EngineConfiguration.productPreview
        let workSeconds = [a, b].reduce(0) { total, id in
            let timing = config.catalog[id]!.timingSeconds
            return total + timing.setup + (id == a ? 3 : 2) * (timing.execution + timing.secondSide + timing.transition)
        }
        #expect(ActiveSessionCoordinator.estimatedRemainingSeconds(snapshot, now: now) == workSeconds + 3 * 60 + 2 * 120 - 60)
        let original = snapshot
        var sequence: [String] = []
        for step in 0..<5 {
            let at = now.addingTimeInterval(Double(step * 300))
            if snapshot.restDeadline != nil {
                let preview = ActiveSessionCoordinator.nextMovementIndex(snapshot)
                snapshot = ActiveSessionCoordinator.completeRest(snapshot, now: at)
                #expect(snapshot.currentMovementIndex == preview)
            }
            sequence.append(try #require(snapshot.currentMovement?.exerciseKey))
            #expect(snapshot.setStartedAt == nil)
            snapshot = ActiveSessionCoordinator.startSet(snapshot, now: at)
            snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: at.addingTimeInterval(30))
            snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: JSONEncoder().encode(snapshot))
        }
        #expect(sequence == [a, b, a, b, a])
        #expect(snapshot.isFinished && snapshot.recordedSets.count == 5)
        #expect(snapshot.recordedSets.last?.plannedRestSeconds == nil)
        var partial = ActiveSessionCoordinator.startSet(original, now: now)
        partial = ActiveSessionCoordinator.recordSet(partial, repetitions: 8, now: now.addingTimeInterval(30))
        let nextSkipped = ActiveSessionCoordinator.skipUpcomingMovement(partial, now: now.addingTimeInterval(40))
        #expect(nextSkipped.skippedExerciseKeys.contains(b) && !nextSkipped.skippedExerciseKeys.contains(a))
        #expect(nextSkipped.restDeadline == partial.restDeadline && nextSkipped.recordedSets == partial.recordedSets)
        #expect(ActiveSessionCoordinator.completeRest(nextSkipped, now: now.addingTimeInterval(300)).currentMovement?.exerciseKey == a)
        let stopped = ActiveSessionCoordinator.endEarly(partial, now: now.addingTimeInterval(40))
        #expect(stopped.skippedExerciseKeys.contains(a) && stopped.skippedExerciseKeys.contains(b))
        #expect(stopped.recordedSets == partial.recordedSets)
        let skipped = ActiveSessionCoordinator.skipCurrentMovement(partial, now: now.addingTimeInterval(40))
        #expect(skipped.currentMovement?.exerciseKey == b)
        #expect(skipped.recordedSets == partial.recordedSets && skipped.setStartedAt == nil)
    }
}
