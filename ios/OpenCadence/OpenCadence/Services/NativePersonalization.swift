import CadenceEngine
import Foundation

/// Durable declarations live in UserSetupRecord. This is the frozen context of one session.
struct NativePersonalizationContext: Codable, Equatable {
    var person: V2Personalization
    var checks: [V2MovementCheck]
    var options: [String: [V2MovementOption]]
    var coverage: V2MuscleCoverage
    var policyVersion: String
    var refusals: [String]
    var releaseConfiguration: Bool
    var prescribedSets: [String: Int]
    var explicitChoices: [V2SessionChoice]?
    var incompatibleChoices: [String]?
    var repetitionReviewHandled: Bool?
    var blocks: [[String]]?
    var recentWorkExercises: [String]?

    init(person: V2Personalization, result: V2PersonalizedSessionResult, refusals: [String], releaseConfiguration: Bool = false) {
        self.person = V2Personalization(sessionId: person.sessionId, practice: person.practice,
            returning: person.returning, knowledge: result.knowledge)
        recentWorkExercises = result.decision.reasons.filter { $0.code == "recent_work_dose" }.map(\.scope)
        blocks = result.blocks
        checks = result.checks; options = result.optionsByExercise; coverage = result.coverage
        policyVersion = result.policyVersion; self.refusals = refusals
        self.releaseConfiguration = releaseConfiguration
        prescribedSets = Dictionary(uniqueKeysWithValues: result.decision.plan.map { ($0.exerciseId, $0.sets) })
    }
}

enum NativePersonalization {
    enum AdjustmentError: Error { case unavailable, runningSet, invalidDecision }

    static func prepare(person: V2Personalization, inventory: [V2InventoryItem], todayInventory: [V2InventoryItem],
                        supports: [String], history: [V2HistoryEntry], limitations: [Limitation] = [],
                        refusals: [String] = [], mode: V2SessionMode, healthSignal: Bool = false,
                        scope: V2DeclaredScope? = nil, active: V2ActiveSession? = nil,
                        configuration: V2EngineConfiguration = .productPreview,
                        source: V2HistoryEvidenceSource = .nativeConfirmed, now: Date) -> V2PersonalizedSessionResult {
        let exclusions = limitations.flatMap(\.excludedExerciseKeys).map {
            V2Refusal(scope: "movement", temporalScope: "today", exerciseId: $0)
        } + refusals.compactMap { id -> V2Refusal? in
            guard let e = configuration.catalog[id] else { return nil }
            return V2Refusal(scope: "configuration", temporalScope: "persistent", exerciseId: id,
                             progressionContext: e.progressionContext)
        }
        return CadenceEngine.decidePersonalizedSession(input: .init(request: .init(durationMinutes: 30, mode: mode),
            persistentInventory: inventory, todayInventory: todayInventory, todaySupports: supports,
            history: history, refusals: exclusions, activeSession: active,
            declaredCurrentHealthSignal: healthSignal, declaredScope: scope),
            person: person, now: now, configuration: configuration, evidenceSource: source)
    }

    /// Replans only unstarted work. Confirmed rows remain in the snapshot for exact historical provenance.
    static func adjust(_ snapshot: ActiveWorkoutSnapshot, exerciseID: String, choice: V2DirectChoice?,
                       scope: V2ChoiceScope, declaration: V2MovementKnowledge?,
                       history: [V2HistoryEntry], now: Date = .now) throws -> ActiveWorkoutSnapshot {
        guard var context = snapshot.v2Context, let previous = context.personalization,
              !snapshot.isFinished, snapshot.unresolvedSafetyEventID == nil else { throw AdjustmentError.unavailable }
        guard snapshot.setStartedAt == nil else { throw AdjustmentError.runningSet }
        let config: V2EngineConfiguration = previous.releaseConfiguration ? .releaseV2 : .productPreview
        var knowledge = previous.person.knowledge
        if let declaration { knowledge.removeAll { $0.exerciseId == declaration.exerciseId }; knowledge.append(declaration) }
        let person = V2Personalization(sessionId: snapshot.sessionID, practice: previous.person.practice,
            returning: previous.person.returning, knowledge: knowledge,
            choices: choice.map { [.init(sessionId: snapshot.sessionID, exerciseId: exerciseID, choice: $0, scope: { if case .variant = $0 { return .today }; return scope }($0), at: now)] } ?? [])
        let counts = Dictionary(grouping: snapshot.recordedSets, by: \.exerciseKey).mapValues(\.count)
        let confirmed = context.plan.compactMap { row -> V2ConfirmedWork? in
            guard let count = counts[row.exerciseId], count > 0 else { return nil }
            return .init(exerciseId: row.exerciseId, sets: count, targetReps: row.targetReps,
                load: row.load, progressionContext: row.progressionContext)
        }
        var remaining = context.plan.filter { !snapshot.skippedExerciseKeys.contains($0.exerciseId) }.compactMap { row -> V2UnstartedWork? in
            let count = row.sets - (counts[row.exerciseId] ?? 0)
            guard count > 0 else { return nil }
            return .init(exerciseId: row.exerciseId, sets: count, targetReps: row.targetReps,
                restSeconds: row.restSeconds, load: row.load, referenceStatus: row.referenceStatus,
                progressionContext: row.progressionContext)
        }
        // A locally unresolved movement can be added once its capacity has actually been stated.
        if !remaining.contains(where: { $0.exerciseId == exerciseID }),
           previous.checks.contains(where: { $0.exerciseId == exerciseID }) {
            let seed = prepare(person: person, inventory: context.inventory, todayInventory: context.inventory,
                supports: context.supports, history: history, refusals: previous.refusals, mode: context.mode, configuration: config, now: now)
            let anchor = config.catalog[exerciseID]?.anchor
            if let row = seed.decision.plan.first(where: { config.catalog[$0.exerciseId]?.anchor == anchor }),
               !remaining.contains(where: { config.catalog[$0.exerciseId]?.anchor == anchor }) {
                remaining.append(.init(exerciseId: row.exerciseId, sets: row.sets, targetReps: row.targetReps,
                    restSeconds: row.restSeconds, load: row.load, referenceStatus: row.referenceStatus, progressionContext: row.progressionContext))
            }
        }
        let active = V2ActiveSession(sessionId: snapshot.sessionID, mode: context.mode, catalogVersion: context.catalogVersion,
            decisionPolicyVersion: context.decisionPolicyVersion, confirmed: confirmed, unstarted: remaining)
        let result = prepare(person: person, inventory: context.inventory, todayInventory: context.inventory,
            supports: context.supports, history: history, refusals: previous.refusals, mode: context.mode, active: active, configuration: config, now: now)
        guard result.decision.decision == .generateSession || result.decision.decision == .resumeOrAdaptActiveSession else {
            throw AdjustmentError.invalidDecision
        }
        // Do not remove a planned movement while a new capacity answer is still missing.
        guard !result.checks.contains(where: \.requiredBeforeMovement) else { throw AdjustmentError.invalidDecision }
        var plan: [V2PlanItem] = []
        let newIDs = Set(result.decision.plan.map(\.exerciseId))
        for row in context.plan where (counts[row.exerciseId] ?? 0) > 0 && !newIDs.contains(row.exerciseId) {
            plan.append(copy(row, sets: counts[row.exerciseId]!))
        }
        plan += result.decision.plan.map { copy($0, sets: $0.sets + (counts[$0.exerciseId] ?? 0)) }
        var next = snapshot
        let decision = V2SessionDecision(catalogVersion: context.catalogVersion, decisionPolicyVersion: context.decisionPolicyVersion,
            decision: .generateSession, mode: context.mode, estimatedSeconds: result.decision.estimatedSeconds, plan: plan)
        next.decision = WorkoutEngineBridge.legacyDecision(from: decision, limitations: [], migratedHistory: false, configuration: config)
        context.plan = plan
        context.estimatedSeconds = result.decision.estimatedSeconds
        var sessionRefusals = previous.refusals
        if choice == .exclude || choice == .cannotPerform { sessionRefusals.append(exerciseID) }
        context.personalization = NativePersonalizationContext(person: person, result: result, refusals: sessionRefusals, releaseConfiguration: previous.releaseConfiguration)
        // Preserve active block membership, mapping a replacement in its existing slot.
        context.personalization?.blocks = previous.blocks.map { blocks in
            var mapped = blocks.map { block in block.compactMap { id -> String? in
                if let replacement = plan.first(where: { $0.sourceExerciseId == id }) { return replacement.exerciseId }
                return plan.contains(where: { $0.exerciseId == id }) ? id : nil
            }}.filter { !$0.isEmpty }
            let present = Set(mapped.flatMap { $0 })
            mapped += plan.filter { !present.contains($0.exerciseId) }.map { [$0.exerciseId] }
            return mapped
        }
        context.personalization?.recentWorkExercises = previous.recentWorkExercises?.filter { id in
            guard plan.contains(where: { $0.exerciseId == id }) else { return false }
            if id == exerciseID, case .sets = choice { return false }
            return true
        }
        var savedChoices = previous.explicitChoices ?? []
        if let choice, choice != .deferRepetitionReview, choice != .difficultyTooHigh {
            if case let .variant(target) = choice, target != exerciseID {
                let anchor = config.catalog[exerciseID]?.anchor
                savedChoices.removeAll { config.catalog[$0.exerciseId]?.anchor == anchor }
            } else {
                savedChoices.removeAll { $0.exerciseId == exerciseID && choiceField($0.choice) == choiceField(choice) }
            }
            savedChoices.append(.init(sessionId: snapshot.sessionID, exerciseId: exerciseID, choice: choice, scope: scope, at: now))
        }
        context.personalization?.explicitChoices = savedChoices
        context.personalization?.incompatibleChoices = previous.incompatibleChoices
        context.personalization?.prescribedSets = previous.prescribedSets.merging(Dictionary(uniqueKeysWithValues: plan.map { ($0.exerciseId, $0.sets) }), uniquingKeysWith: max)
        // Unresolved anchors which were not involved in this correction remain available for later.
        context.personalization?.checks += previous.checks.filter { check in
            check.exerciseId != exerciseID && !result.checks.contains(where: { $0.exerciseId == check.exerciseId && $0.reason == check.reason }) && (check.requiredBeforeMovement == false || !plan.contains { config.catalog[$0.exerciseId]?.anchor == check.anchor })
        }
        var handled = previous.repetitionReviewHandled ?? false
        switch choice {
        case .holdRepetitions, .deferRepetitionReview, .difficultyTooHigh, .resumeRepetitionProgression: handled = true
        default: break
        }
        context.personalization?.repetitionReviewHandled = handled
        if handled { context.personalization?.checks.removeAll { !$0.requiredBeforeMovement } }
        next.v2Context = context
        if previous.blocks != nil {
            let remainingSeconds = ActiveSessionCoordinator.estimatedRemainingSeconds(next, now: now)
            next.v2Context?.estimatedSeconds = remainingSeconds
        }
        let movements = next.decision.movements ?? []
        if snapshot.restDeadline != nil || snapshot.pausedRemainingSeconds != nil,
           let old = snapshot.currentMovement?.exerciseKey,
           let index = movements.firstIndex(where: { $0.exerciseKey == old }) {
            next.currentMovementIndex = index
        } else {
            next.currentMovementIndex = ActiveSessionCoordinator.nextMovementIndex(next) ?? movements.count
        }
        next.completedSetsInMovement = next.currentMovement.flatMap { counts[$0.exerciseKey] } ?? 0
        if case let .variant(target) = choice, target != exerciseID {
            next.confirmedLoadsKg?.removeValue(forKey: exerciseID)
            next.confirmedLoadOptions?.removeValue(forKey: exerciseID)
        }
        if case let .load(load) = choice {
            if let kg = load.kg { next.confirmedLoadsKg?[exerciseID] = kg }
            if let option = load.optionID { next.confirmedLoadOptions?[exerciseID] = option }
        }
        return next
    }

    static func settingFamiliarity(_ records: [V2MovementKnowledge], exerciseID: String?, familiar: Bool,
                                   configuration: V2EngineConfiguration, now: Date = .now) -> [V2MovementKnowledge] {
        guard let exerciseID, let exercise = configuration.catalog[exerciseID] else { return records }
        var next = records
        if let index = next.firstIndex(where: { $0.exerciseId == exerciseID }) { next[index].familiar = familiar }
        else if familiar {
            next.append(.init(exerciseId: exerciseID, progressionContext: exercise.progressionContext,
                familiar: true, at: now, catalogVersion: configuration.catalogVersion))
        }
        return next
    }

    static func replaceBeforeFirstSet(_ snapshot: ActiveWorkoutSnapshot, with prepared: PreparedWorkout, history: [V2HistoryEntry] = [], now: Date = .now) throws -> ActiveWorkoutSnapshot {
        guard snapshot.recordedSets.isEmpty, snapshot.setStartedAt == nil,
              snapshot.restDeadline == nil, snapshot.pausedRemainingSeconds == nil,
              snapshot.unresolvedSafetyEventID == nil, !snapshot.isFinished,
              prepared.decision.decision == "generate_workout",
              prepared.v2Context?.personalization?.person.sessionId == snapshot.sessionID else { throw AdjustmentError.unavailable }
        var next = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context, now: snapshot.startedAt ?? .now)
        let config: V2EngineConfiguration = next.v2Context?.personalization?.releaseConfiguration == true ? .releaseV2 : .productPreview
        var choices = snapshot.v2Context?.personalization?.explicitChoices ?? []
        // Direct load controls are explicit too, even though they do not replan the exercise.
        for (id, kg) in snapshot.confirmedLoads {
            guard snapshot.v2Context?.plan.contains(where: { $0.exerciseId == id }) == true else { continue }
            guard let exercise = config.catalog[id] else { continue }
            choices.removeAll { $0.exerciseId == id && choiceField($0.choice) == "load" }
            choices.append(.init(sessionId: snapshot.sessionID, exerciseId: id,
                choice: .load(.init(mode: exercise.loadMode, kg: kg)), at: now))
        }
        for (id, option) in snapshot.confirmedOptions {
            guard snapshot.v2Context?.plan.contains(where: { $0.exerciseId == id }) == true else { continue }
            choices.removeAll { $0.exerciseId == id && choiceField($0.choice) == "load" }
            choices.append(.init(sessionId: snapshot.sessionID, exerciseId: id,
                choice: .load(.init(optionID: option)), at: now))
        }
        var incompatible: [String] = []
        for choice in choices.sorted(by: { choiceField($0.choice) == "variant" && choiceField($1.choice) != "variant" }) {
            var source = choice.exerciseId
            if choice.choice == .exclude && next.v2Context?.personalization?.refusals.contains(source) == true { continue }
            if case let .variant(target) = choice.choice {
                if next.v2Context?.plan.contains(where: { $0.exerciseId == target }) == true {
                    let retained = (next.v2Context?.personalization?.explicitChoices ?? []) + [choice]
                    next.v2Context?.personalization?.explicitChoices = retained
                    continue
                }
                source = next.v2Context?.plan.first { config.catalog[$0.exerciseId]?.anchor == config.catalog[choice.exerciseId]?.anchor }?.exerciseId ?? source
            }
            do {
                next = try adjust(next, exerciseID: source, choice: choice.choice, scope: .today, declaration: nil, history: history, now: now)
            } catch { incompatible.append(choice.exerciseId) }
        }
        next.v2Context?.personalization?.explicitChoices = choices
        next.v2Context?.personalization?.incompatibleChoices = Array(Set(incompatible)).sorted()
        return next
    }

    static func durableKnowledge(_ previous: [V2MovementKnowledge], exerciseID: String, choice: V2DirectChoice?,
                                 declaration: V2MovementKnowledge?, result: [V2MovementKnowledge]) -> [V2MovementKnowledge] {
        var records = previous
        if let declaration {
            records.removeAll { $0.exerciseId == declaration.exerciseId }; records.append(declaration)
        }
        if let updated = result.first(where: { $0.exerciseId == exerciseID }) {
            var durable = records.first(where: { $0.exerciseId == exerciseID }) ?? V2MovementKnowledge(
                exerciseId: exerciseID, progressionContext: updated.progressionContext,
                at: updated.at, catalogVersion: updated.catalogVersion)
            switch choice {
            case .sets: durable.usualSets = updated.usualSets; durable.preferenceUpdatedAt = updated.preferenceUpdatedAt
            case .exclude: durable.unavailable = true
            case .variant: durable.familiar = updated.familiar
            case .holdRepetitions, .resumeRepetitionProgression:
                durable.preferredReps = updated.preferredReps; durable.preferredRepsLoad = updated.preferredRepsLoad
                durable.repetitionReviewAt = updated.repetitionReviewAt
                durable.repetitionHoldReleasedAt = updated.repetitionHoldReleasedAt
            case .difficultyTooHigh, .deferRepetitionReview:
                durable.repetitionReviewAt = updated.repetitionReviewAt
            default: break
            }
            records.removeAll { $0.exerciseId == exerciseID }; records.append(durable)
        }
        return records
    }

    static func withConfirmedLoad(_ snapshot: ActiveWorkoutSnapshot, exerciseID: String, load: V2Load) -> ActiveWorkoutSnapshot {
        guard snapshot.setStartedAt == nil, var context = snapshot.v2Context, context.personalization != nil,
              let index = context.plan.firstIndex(where: { $0.exerciseId == exerciseID }) else { return snapshot }
        let row = context.plan[index]
        context.plan[index] = .init(exerciseId: row.exerciseId, sourceExerciseId: row.sourceExerciseId,
            sets: row.sets, targetReps: row.targetReps, restSeconds: row.restSeconds, load: load,
            referenceStatus: "chosen_today", progressionContext: row.progressionContext, targetUnit: row.targetUnit)
        var next = snapshot; next.v2Context = context
        return next
    }

    private static func choiceField(_ choice: V2DirectChoice) -> String {
        switch choice {
        case .variant: return "variant"
        case .load: return "load"
        case .sets: return "sets"
        case .holdRepetitions, .resumeRepetitionProgression: return "repetitions"
        default: return "availability"
        }
    }

    private static func copy(_ row: V2PlanItem, sets: Int) -> V2PlanItem {
        .init(exerciseId: row.exerciseId, sourceExerciseId: row.sourceExerciseId, sets: sets, targetReps: row.targetReps,
              restSeconds: row.restSeconds, load: row.load, referenceStatus: row.referenceStatus,
              progressionContext: row.progressionContext, targetUnit: row.targetUnit)
    }
}
