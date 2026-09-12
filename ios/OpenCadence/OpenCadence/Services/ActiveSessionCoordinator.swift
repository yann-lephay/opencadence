@_spi(AutomaticPolicyExperiment) import CadenceEngine
import Foundation
import SwiftData

enum ActiveSessionCoordinator {
    static func start(decision: EngineDecision) -> ActiveWorkoutSnapshot {
        start(decision: decision, v2Context: nil, now: .now)
    }

    static func start(
        decision: EngineDecision,
        v2Context: ActiveWorkoutV2Context?,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            sessionID: v2Context?.personalization?.person.sessionId ?? UUID().uuidString,
            decision: decision,
            currentMovementIndex: 0,
            completedSetsInMovement: 0,
            completedSetCount: 0,
            processedEventIDs: [],
            lastCompletedReps: nil,
            restDeadline: nil,
            pausedRemainingSeconds: nil,
            originalRestSeconds: nil,
            skippedExerciseKeys: [],
            isFinished: false,
            endedEarly: false,
            endedAt: nil,
            setResults: [],
            confirmedLoadsKg: [:],
            confirmedLoadOptions: [:],
            feedback: .empty,
            safetyEventRecords: [],
            unresolvedSafetyEventID: nil,
            startedAt: now,
            v2Context: v2Context
        )
    }

    static func load(_ record: ActiveWorkoutRecord) throws -> LoadedActiveWorkout {
        let decoder = JSONDecoder()
        if let current = try? decoder.decode(ActiveWorkoutSnapshot.self, from: record.snapshotData) {
            return LoadedActiveWorkout(
                snapshot: current,
                restoredPreviousSnapshot: false,
                v2ContextIsCompatible: v2ContextIsCompatible(current)
            )
        }
        if let previousData = record.previousSnapshotData,
           let previous = try? decoder.decode(ActiveWorkoutSnapshot.self, from: previousData) {
            return LoadedActiveWorkout(
                snapshot: previous,
                restoredPreviousSnapshot: true,
                v2ContextIsCompatible: v2ContextIsCompatible(previous)
            )
        }
        throw ActiveSessionError.noValidSnapshot
    }

    static func persist(
        _ snapshot: ActiveWorkoutSnapshot,
        in record: ActiveWorkoutRecord,
        context: ModelContext,
        now: Date = .now
    ) throws {
        let encoded = try JSONEncoder().encode(snapshot)
        record.previousSnapshotData = record.snapshotData
        record.snapshotData = encoded
        record.updatedAt = now
        try context.save()
    }

    static func repair(
        _ snapshot: ActiveWorkoutSnapshot,
        in record: ActiveWorkoutRecord,
        context: ModelContext,
        now: Date = .now
    ) throws {
        let encoded = try JSONEncoder().encode(snapshot)
        record.snapshotData = encoded
        record.previousSnapshotData = encoded
        record.updatedAt = now
        try context.save()
    }

    static func startSet(_ snapshot: ActiveWorkoutSnapshot, now: Date = .now) -> ActiveWorkoutSnapshot {
        guard !snapshot.isFinished, snapshot.setStartedAt == nil, snapshot.restDeadline == nil,
              snapshot.pausedRemainingSeconds == nil, snapshot.unresolvedSafetyEventID == nil,
              let movement = snapshot.currentMovement else { return snapshot }
        var next = snapshot
        next.setStartedAt = now
        next.startedPrescriptionReps = snapshot.v2Context?.plan.first { $0.exerciseId == movement.exerciseKey }?.targetReps
        return next
    }

    static func recordSet(
        _ snapshot: ActiveWorkoutSnapshot,
        repetitions: Int,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        guard repetitions > 0, let movement = snapshot.currentMovement else { return snapshot }
        let load = snapshot.confirmedLoads[movement.exerciseKey]
        let option = snapshot.confirmedOptions[movement.exerciseKey]
        guard !WorkoutLoadResolver.requiresLoad(movement) || load != nil else { return snapshot }
        guard !WorkoutLoadResolver.requiresOption(movement) || option != nil else { return snapshot }
        var next = snapshot
        let eventID = UUID().uuidString
        let transition = CadenceEngine.reduceActiveSession(
            snapshot: engineSnapshot(from: snapshot),
            event: SessionEvent(eventId: eventID, type: "complete_set", completedReps: repetitions),
            now: now
        )
        guard transition.transition == "set_completed" else { return snapshot }

        next.setStartedAt = nil
        next.startedPrescriptionReps = nil
        next.completedSetCount = transition.completedSetCount ?? snapshot.completedSetCount
        next.completedSetsInMovement += 1
        next.processedEventIDs.append(eventID)
        next.lastCompletedReps = repetitions
        var results = next.recordedSets
        let hasRemainingWork = (next.decision.movements ?? []).contains { row in
            !next.skippedExerciseKeys.contains(row.exerciseKey) &&
                results.filter { $0.exerciseKey == row.exerciseKey }.count + (row.exerciseKey == movement.exerciseKey ? 1 : 0) < row.sets
        }
        results.append(
            CompletedSetRecord(
                eventID: eventID,
                exerciseKey: movement.exerciseKey,
                repetitions: repetitions,
                perUnitWeightKg: load,
                loadOptionID: option,
                completedAt: now,
                plannedRestSeconds: hasRemainingWork
                    ? movement.restSeconds
                    : nil,
                restEndedAt: nil,
                prescribedRepetitions: snapshot.startedPrescriptionReps
            )
        )
        next.setResults = results
        if next.completedSetCount >= next.totalSetCount || (next.v2Context?.personalization?.blocks != nil && nextMovementIndex(next) == nil) {
            next.isFinished = true
            next.endedAt = now
        } else {
            next.originalRestSeconds = movement.restSeconds
            next.restDeadline = now.addingTimeInterval(TimeInterval(movement.restSeconds))
            next.pausedRemainingSeconds = nil
        }
        return next
    }

    static func confirmLoad(
        _ snapshot: ActiveWorkoutSnapshot,
        exerciseKey: String,
        perUnitWeightKg: Double?,
        inventory: [EquipmentItem]
    ) -> ActiveWorkoutSnapshot {
        guard snapshot.v2Context?.personalization == nil || snapshot.setStartedAt == nil else { return snapshot }
        guard let movement = snapshot.decision.movements?.first(where: { $0.exerciseKey == exerciseKey }) else {
            return snapshot
        }
        let options = WorkoutLoadResolver.options(for: movement, inventory: inventory)
        if let perUnitWeightKg,
           !options.contains(where: { abs($0 - perUnitWeightKg) < 0.000_1 }) {
            return snapshot
        }
        guard perUnitWeightKg != nil || !WorkoutLoadResolver.requiresLoad(movement) else {
            var next = snapshot
            next.confirmedLoadsKg?[exerciseKey] = nil
            return next
        }
        var next = snapshot
        var loads = next.confirmedLoads
        loads[exerciseKey] = perUnitWeightKg
        next.confirmedLoadsKg = loads
        if let kg = perUnitWeightKg, let mode = next.v2Context?.plan.first(where: { $0.exerciseId == exerciseKey })?.load?.mode {
            next = NativePersonalization.withConfirmedLoad(next, exerciseID: exerciseKey, load: .init(mode: mode, kg: kg))
        }
        return next
    }

    static func confirmLoadOption(
        _ snapshot: ActiveWorkoutSnapshot,
        exerciseKey: String,
        optionID: String?,
        inventory: [EquipmentItem]
    ) -> ActiveWorkoutSnapshot {
        guard snapshot.v2Context?.personalization == nil || snapshot.setStartedAt == nil else { return snapshot }
        guard let movement = snapshot.decision.movements?.first(where: { $0.exerciseKey == exerciseKey }),
              WorkoutLoadResolver.requiresOption(movement) else { return snapshot }
        let options = WorkoutLoadResolver.optionIDs(for: movement, inventory: inventory)
        guard optionID.map(options.contains) ?? false else { return snapshot }
        var next = snapshot
        var values = next.confirmedOptions
        values[exerciseKey] = optionID
        next.confirmedLoadOptions = values
        if let optionID { next = NativePersonalization.withConfirmedLoad(next, exerciseID: exerciseKey, load: .init(optionID: optionID)) }
        return next
    }

    static func updateFeedback(
        _ snapshot: ActiveWorkoutSnapshot,
        value: Int?,
        field: FeedbackField
    ) -> ActiveWorkoutSnapshot {
        var next = snapshot
        var feedback = next.feedback ?? .empty
        switch field {
        case .effort: feedback.effort = value
        case .discomfort: feedback.discomfort = value
        case .repetitionsInReserve: feedback.repetitionsInReserve = value
        }
        next.feedback = feedback
        return next
    }

    static func reportPain(
        _ snapshot: ActiveWorkoutSnapshot,
        score: Int,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        guard (0...10).contains(score), let movement = snapshot.currentMovement else {
            return snapshot
        }
        let eventID = UUID().uuidString
        let v2ConservativeStop = snapshot.v2Context != nil && score > 0
        let transition: EngineDecision
        if v2ConservativeStop {
            var conservative = EngineDecision(
                decision: "active_session_transition",
                reasonCodes: ["safety.conservative_v2_stop"]
            )
            conservative.transition = "stop_current_exercise"
            conservative.mustNotDiagnose = true
            transition = conservative
        } else {
            transition = CadenceEngine.reduceActiveSession(
                snapshot: engineSnapshot(from: snapshot),
                event: SessionEvent(eventId: eventID, type: "pain_reported", painScore: score),
                now: now
            )
        }
        var next = snapshot
        next.processedEventIDs.append(eventID)
        var feedback = next.feedback ?? .empty
        feedback.discomfort = max(feedback.discomfort ?? score, score)
        next.feedback = feedback
        var events = next.recordedSafetyEvents
        events.append(
            SafetyEventRecord(
                eventID: eventID,
                exerciseKey: movement.exerciseKey,
                kind: "pain",
                painScore: score,
                alertCodes: [],
                reportedAt: now,
                transition: transition.transition ?? "event_ignored",
                mustNotDiagnose: transition.mustNotDiagnose == true,
                chosenAction: nil
            )
        )
        next.safetyEventRecords = events
        if transition.transition == "stop_current_set"
            || transition.transition == "stop_current_exercise" {
            next.setStartedAt = nil
            next.unresolvedSafetyEventID = eventID
        }
        return next
    }

    static func reportUrgentAlert(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        let eventID = UUID().uuidString
        let transition = CadenceEngine.reduceActiveSession(
            snapshot: engineSnapshot(from: snapshot),
            event: SessionEvent(
                eventId: eventID,
                type: "alert_reported",
                redFlags: ["urgent_symptom_reported"]
            ),
            now: now
        )
        guard transition.transition == "stop_session_and_orient" else { return snapshot }

        var next = snapshot
        next.processedEventIDs.append(eventID)
        var events = next.recordedSafetyEvents
        events.append(
            SafetyEventRecord(
                eventID: eventID,
                exerciseKey: snapshot.currentMovement?.exerciseKey,
                kind: "urgent_alert",
                painScore: nil,
                alertCodes: ["urgent_symptom_reported"],
                reportedAt: now,
                transition: transition.transition ?? "stop_session_and_orient",
                mustNotDiagnose: transition.mustNotDiagnose == true,
                chosenAction: nil
            )
        )
        next.safetyEventRecords = events
        next.unresolvedSafetyEventID = eventID
        return endEarly(next, now: now)
    }

    static func resolveSafetyEvent(
        _ snapshot: ActiveWorkoutSnapshot,
        action: SafetyResolutionAction,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        guard let unresolved = snapshot.unresolvedSafetyEvent,
              action.isAllowed(for: unresolved.transition),
              let eventIndex = snapshot.recordedSafetyEvents.firstIndex(where: {
                  $0.eventID == unresolved.eventID
              }) else { return snapshot }

        var next = snapshot
        var events = next.recordedSafetyEvents
        events[eventIndex].chosenAction = action.rawValue
        next.safetyEventRecords = events
        next.unresolvedSafetyEventID = nil

        switch action {
        case .reduceRange, .acknowledgeOrientation:
            return next
        case .stopExercise:
            return skipCurrentMovement(next, now: now)
        case .endSession:
            return endEarly(next, now: now)
        }
    }

    static func correctLastSet(
        _ snapshot: ActiveWorkoutSnapshot,
        repetitions: Int,
        perUnitWeightKg: Double?,
        loadOptionID: String? = nil,
        inventory: [EquipmentItem]
    ) -> ActiveWorkoutSnapshot {
        guard repetitions > 0,
              let last = snapshot.recordedSets.last,
              let movement = snapshot.decision.movements?.first(where: {
                  $0.exerciseKey == last.exerciseKey
              }) else { return snapshot }

        if WorkoutLoadResolver.requiresLoad(movement) {
            let options = WorkoutLoadResolver.options(for: movement, inventory: inventory)
            guard let perUnitWeightKg,
                  options.contains(where: { abs($0 - perUnitWeightKg) < 0.000_1 }) else {
                return snapshot
            }
        } else if perUnitWeightKg != nil {
            return snapshot
        }
        if WorkoutLoadResolver.requiresOption(movement) {
            guard let loadOptionID,
                  WorkoutLoadResolver.optionIDs(for: movement, inventory: inventory).contains(loadOptionID) else {
                return snapshot
            }
        } else if loadOptionID != nil {
            return snapshot
        }

        var next = snapshot
        var results = next.recordedSets
        results[results.index(before: results.endIndex)] = CompletedSetRecord(
            eventID: last.eventID,
            exerciseKey: last.exerciseKey,
            repetitions: repetitions,
            perUnitWeightKg: perUnitWeightKg,
            loadOptionID: loadOptionID,
            completedAt: last.completedAt,
            plannedRestSeconds: last.plannedRestSeconds,
            restEndedAt: last.restEndedAt
        )
        next.setResults = results
        next.lastCompletedReps = repetitions
        if let perUnitWeightKg {
            var loads = next.confirmedLoads
            loads[last.exerciseKey] = perUnitWeightKg
            next.confirmedLoadsKg = loads
        }
        if let loadOptionID {
            var values = next.confirmedOptions
            values[last.exerciseKey] = loadOptionID
            next.confirmedLoadOptions = values
        }
        return next
    }

    static func pauseRest(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        applyTimerEvent("pause_rest", to: snapshot, now: now)
    }

    static func resumeRest(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        applyTimerEvent("resume_rest", to: snapshot, now: now)
    }

    static func restartRest(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        applyTimerEvent("restart_rest", to: snapshot, now: now)
    }

    /// Single resolver shared by execution, rest preview, corrections and skips.
    /// A nil block snapshot is an older session and retains its grouped behavior.
    static func nextMovementIndex(_ snapshot: ActiveWorkoutSnapshot, completedCounts: [String: Int]? = nil) -> Int? {
        let movements = snapshot.decision.movements ?? []
        let counts = completedCounts ?? Dictionary(grouping: snapshot.recordedSets, by: \.exerciseKey).mapValues(\.count)
        let skipped = Set(snapshot.skippedExerciseKeys)
        let pending: (Int) -> Bool = { i in
            !skipped.contains(movements[i].exerciseKey) && (counts[movements[i].exerciseKey] ?? 0) < movements[i].sets
        }
        guard let blocks = snapshot.v2Context?.personalization?.blocks else {
            return movements.indices.first(where: pending)
        }
        for block in blocks {
            let indices = block.compactMap { id in movements.firstIndex { $0.exerciseKey == id } }.filter(pending)
            let loads = block.compactMap { id in snapshot.v2Context?.plan.first { $0.exerciseId == id }?.load }
            if loads.count > 1, loads.first != loads.last, let first = indices.first { return first }
            if let index = indices.min(by: {
                (counts[movements[$0].exerciseKey] ?? 0) < (counts[movements[$1].exerciseKey] ?? 0)
            }) { return index }
        }
        return movements.indices.first(where: pending)
    }

    static func estimatedRemainingSeconds(_ snapshot: ActiveWorkoutSnapshot, now: Date) -> Int {
        guard let context = snapshot.v2Context else { return 0 }
        let config: V2EngineConfiguration = context.personalization?.releaseConfiguration == true ? .releaseV2 : .productPreview
        var counts = Dictionary(grouping: snapshot.recordedSets, by: \.exerciseKey).mapValues(\.count)
        var prepared = Set<String>(), seconds = 0, finalRest = 0
        while let index = nextMovementIndex(snapshot, completedCounts: counts),
              let movement = snapshot.decision.movements?[index] {
            let id = movement.exerciseKey
            counts[id, default: 0] += 1
            guard let exercise = config.catalog[id] else { continue }
            if prepared.insert(id).inserted { seconds += exercise.timingSeconds.setup }
            seconds += exercise.timingSeconds.execution + exercise.timingSeconds.secondSide
                + exercise.timingSeconds.transition + movement.restSeconds
            finalRest = movement.restSeconds
        }
        let pendingRest = snapshot.pausedRemainingSeconds ?? snapshot.restDeadline.map { max(0, Int($0.timeIntervalSince(now).rounded(.up))) } ?? 0
        return max(0, seconds - finalRest) + pendingRest
    }

    static func completeRest(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        var next: ActiveWorkoutSnapshot
        if let deadline = snapshot.restDeadline, deadline <= now {
            next = snapshot
            next.restDeadline = nil
            next.pausedRemainingSeconds = nil
        } else {
            next = applyTimerEvent("skip_rest", to: snapshot, now: now)
        }
        guard next.restDeadline == nil, next.pausedRemainingSeconds == nil else { return next }
        var results = next.recordedSets
        if let lastIndex = results.indices.last,
           results[lastIndex].plannedRestSeconds != nil,
           results[lastIndex].restEndedAt == nil {
            results[lastIndex].restEndedAt = now
            next.setResults = results
        }
        if next.v2Context?.personalization?.blocks != nil {
            next.currentMovementIndex = nextMovementIndex(next) ?? (next.decision.movements?.count ?? 0)
            next.completedSetsInMovement = next.recordedSets.filter { $0.exerciseKey == next.currentMovement?.exerciseKey }.count
        } else if let movement = next.currentMovement,
           next.completedSetsInMovement >= movement.sets {
            next.setStartedAt = nil
        next.currentMovementIndex += 1
            next.completedSetsInMovement = 0
        }
        next = applyV2TimeBudget(to: next, now: now)
        if next.currentMovement == nil {
            next.isFinished = true
            next.endedAt = now
        }
        return next
    }

    private static func applyV2TimeBudget(
        to snapshot: ActiveWorkoutSnapshot,
        now: Date
    ) -> ActiveWorkoutSnapshot {
        guard var context = snapshot.v2Context,
              context.personalization == nil,
              let startedAt = snapshot.startedAt,
              !snapshot.isFinished else { return snapshot }

        let elapsedSeconds = max(0, Int(now.timeIntervalSince(startedAt).rounded(.up)))
        let remainingSeconds = max(0, context.durationMinutes * 60 - elapsedSeconds)
        let resultsByExercise = Dictionary(grouping: snapshot.recordedSets, by: \.exerciseKey)
        let skipped = Set(snapshot.skippedExerciseKeys)

        let confirmed = context.plan.compactMap { item -> V2ConfirmedWork? in
            let results = Array((resultsByExercise[item.exerciseId] ?? []).prefix(item.sets))
            guard !results.isEmpty else { return nil }
            let factualLoad = results.last?.perUnitWeightKg.map {
                V2Load(mode: item.load?.mode ?? .singleTotalKg, kg: $0)
            } ?? results.last?.loadOptionID.map(V2Load.init(optionID:))
            return V2ConfirmedWork(
                exerciseId: item.exerciseId,
                sets: results.count,
                targetReps: item.targetReps,
                load: factualLoad,
                progressionContext: item.progressionContext
            )
        }
        let unstarted = context.plan.compactMap { item -> V2UnstartedWork? in
            guard !skipped.contains(item.exerciseId) else { return nil }
            let completed = min(resultsByExercise[item.exerciseId]?.count ?? 0, item.sets)
            let remaining = item.sets - completed
            guard remaining > 0 else { return nil }
            return V2UnstartedWork(
                exerciseId: item.exerciseId,
                sets: remaining,
                targetReps: item.targetReps,
                restSeconds: item.restSeconds,
                load: item.load,
                sourceExerciseId: item.sourceExerciseId,
                referenceStatus: item.referenceStatus,
                progressionContext: item.progressionContext
            )
        }
        let request = V2EngineRequest.activeSessionTransition(
                V2ActiveTransitionInput(
                    action: .finishOnTime,
                    catalogVersion: context.catalogVersion,
                    decisionPolicyVersion: context.decisionPolicyVersion,
                    remainingSeconds: remainingSeconds,
                    activeExerciseId: snapshot.currentMovement?.exerciseKey,
                    confirmed: confirmed,
                    unstarted: unstarted
                )
            )
        let result = context.automaticDurationExperiment == true
            ? CadenceEngine.decideAutomaticExperiment(request: request, configuration: .productPreview, sizing: .catalogMaximum)
            : CadenceEngine.decideV2(request: request, configuration: .productPreview)
        guard case let .activeSessionTransition(transition) = result,
              transition.decision == .activeSessionTransition else { return snapshot }

        let remainingByExercise = Dictionary(uniqueKeysWithValues: transition.plan.map { ($0.exerciseId, $0) })
        let updatedPlan = context.plan.compactMap { item -> V2PlanItem? in
            let completed = min(resultsByExercise[item.exerciseId]?.count ?? 0, item.sets)
            let remainingItem = skipped.contains(item.exerciseId)
                ? nil
                : remainingByExercise[item.exerciseId]
            let totalSets = completed + (remainingItem?.sets ?? 0)
            guard totalSets > 0 else { return nil }
            return V2PlanItem(
                exerciseId: item.exerciseId,
                sourceExerciseId: item.sourceExerciseId,
                sets: totalSets,
                targetReps: item.targetReps,
                restSeconds: item.restSeconds,
                load: item.load,
                referenceStatus: item.referenceStatus,
                progressionContext: item.progressionContext,
                targetUnit: item.targetUnit
            )
        }

        var next = snapshot
        context.plan = updatedPlan
        context.estimatedSeconds = transition.estimatedSeconds
        next.v2Context = context
        next.decision.plan = updatedPlan.map {
            PlanRow(exerciseKey: $0.exerciseId, sets: $0.sets)
        }
        let oldMovements = Dictionary(
            uniqueKeysWithValues: (snapshot.decision.movements ?? []).map { ($0.exerciseKey, $0) }
        )
        next.decision.movements = updatedPlan.compactMap { item in
            guard let movement = oldMovements[item.exerciseId] else { return nil }
            return PrescribedMovement(
                exerciseKey: movement.exerciseKey,
                variant: movement.variant,
                pattern: movement.pattern,
                sets: item.sets,
                target: movement.target,
                restSeconds: movement.restSeconds,
                equipment: movement.equipment
            )
        }
        let movements = next.decision.movements ?? []
        next.currentMovementIndex = movements.firstIndex { movement in
            (resultsByExercise[movement.exerciseKey]?.count ?? 0) < movement.sets
        } ?? movements.count
        next.completedSetsInMovement = next.currentMovement.map {
            resultsByExercise[$0.exerciseKey]?.count ?? 0
        } ?? 0
        if !transition.removed.isEmpty {
            next.decision.reasonCodes = Array(Set(
                next.decision.reasonCodes + ["time_budget.removed_unstarted_work"]
            )).sorted()
        }
        return next
    }

    private static func v2ContextIsCompatible(_ snapshot: ActiveWorkoutSnapshot) -> Bool {
        guard let context = snapshot.v2Context else { return true }
        let configuration = V2EngineConfiguration.productPreview
        return (context.personalization == nil || context.personalization?.policyVersion == "first-sessions-1")
            && context.catalogVersion == configuration.catalogVersion
            && context.decisionPolicyVersion == configuration.decisionPolicyVersion
    }

    static func skipUpcomingMovement(_ snapshot: ActiveWorkoutSnapshot, now: Date = .now) -> ActiveWorkoutSnapshot {
        guard let index = nextMovementIndex(snapshot), let movement = snapshot.decision.movements?[index] else { return snapshot }
        var next = snapshot
        next.skippedExerciseKeys = Array(Set(next.skippedExerciseKeys + [movement.exerciseKey])).sorted()
        if nextMovementIndex(next) == nil {
            next.isFinished = true; next.endedAt = now
            next.restDeadline = nil; next.pausedRemainingSeconds = nil
        }
        // While resting, the current pointer still describes the last actual set.
        // completeRest will select the remaining partner without shortening this rest.
        return next
    }

    static func skipCurrentMovement(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        guard let movement = snapshot.currentMovement else { return snapshot }
        var next = snapshot
        next.skippedExerciseKeys.append(movement.exerciseKey)
        next.setStartedAt = nil
        next.currentMovementIndex = next.v2Context?.personalization?.blocks != nil
            ? (nextMovementIndex(next) ?? (next.decision.movements?.count ?? 0)) : next.currentMovementIndex + 1
        next.completedSetsInMovement = next.recordedSets.filter { $0.exerciseKey == next.currentMovement?.exerciseKey }.count
        next.restDeadline = nil
        next.pausedRemainingSeconds = nil
        next.originalRestSeconds = nil
        if next.currentMovement == nil {
            next.isFinished = true
            next.endedAt = now
        }
        return next
    }

    static func endEarly(
        _ snapshot: ActiveWorkoutSnapshot,
        now: Date = .now
    ) -> ActiveWorkoutSnapshot {
        var next = snapshot
        let remaining = (snapshot.decision.movements ?? [])
            .dropFirst(snapshot.v2Context?.personalization?.blocks == nil ? snapshot.currentMovementIndex : 0)
            .filter { movement in
                snapshot.v2Context?.personalization == nil || snapshot.recordedSets.filter { $0.exerciseKey == movement.exerciseKey }.count < movement.sets
            }
            .map(\.exerciseKey)
        next.skippedExerciseKeys = Array(Set(next.skippedExerciseKeys + remaining)).sorted()
        next.restDeadline = nil
        next.pausedRemainingSeconds = nil
        next.isFinished = true
        next.endedEarly = true
        next.endedAt = now
        return next
    }

    private static func applyTimerEvent(
        _ type: String,
        to snapshot: ActiveWorkoutSnapshot,
        now: Date
    ) -> ActiveWorkoutSnapshot {
        let eventID = UUID().uuidString
        let transition = CadenceEngine.reduceActiveSession(
            snapshot: engineSnapshot(from: snapshot),
            event: SessionEvent(eventId: eventID, type: type),
            now: now
        )
        var next = snapshot
        next.processedEventIDs.append(eventID)
        switch transition.transition {
        case "rest_paused":
            next.restDeadline = nil
            next.pausedRemainingSeconds = transition.pausedRemainingSeconds
        case "rest_resumed", "rest_restarted":
            next.restDeadline = transition.restDeadline.flatMap(Self.date)
            next.pausedRemainingSeconds = nil
        case "rest_completed":
            next.restDeadline = nil
            next.pausedRemainingSeconds = nil
        default:
            break
        }
        return next
    }

    private static func engineSnapshot(from snapshot: ActiveWorkoutSnapshot) -> ActiveSessionSnapshot {
        ActiveSessionSnapshot(
            sessionId: snapshot.sessionID,
            version: snapshot.completedSetCount + snapshot.processedEventIDs.count + 1,
            checksumValid: true,
            completedSetCount: snapshot.completedSetCount,
            restDeadline: snapshot.restDeadline.map(isoDate),
            pausedRemainingSeconds: snapshot.pausedRemainingSeconds,
            originalRestSeconds: snapshot.originalRestSeconds,
            processedEventIds: snapshot.processedEventIDs
        )
    }

    private static func date(_ value: String) -> Date? {
        formatter().date(from: value)
    }

    private static func isoDate(_ value: Date) -> String {
        formatter().string(from: value)
    }

    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

enum ActiveSessionError: LocalizedError {
    case noValidSnapshot

    var errorDescription: String? {
        String(localized: "Aucune sauvegarde valide de cette séance n’a pu être restaurée.")
    }
}

enum FeedbackField {
    case effort
    case discomfort
    case repetitionsInReserve
}

enum SafetyResolutionAction: String {
    case reduceRange = "reduce_range"
    case stopExercise = "stop_exercise"
    case endSession = "end_session"
    case acknowledgeOrientation = "acknowledge_orientation"

    func isAllowed(for transition: String) -> Bool {
        switch transition {
        case "stop_current_set":
            self == .reduceRange || self == .stopExercise || self == .endSession
        case "stop_current_exercise":
            self == .stopExercise || self == .endSession
        case "stop_session_and_orient":
            self == .acknowledgeOrientation
        default:
            false
        }
    }
}
