import Foundation

public extension CadenceEngine {
    /// Explicit opt-in for the local simulation only. Never used by the app dispatcher.
    @_spi(AutomaticPolicyExperiment)
    static func decideAutomaticExperiment(
        request: V2EngineRequest,
        configuration: V2EngineConfiguration,
        sizing: V2AutomaticSizingExperiment
    ) -> V2EngineResult {
        switch request {
        case let .sessionDecision(input, now):
            return .sessionDecision(CadenceEngineV2.decideNextSession(
                input: input, now: now, configuration: configuration, experimentalSizing: sizing
            ))
        case let .activeSessionTransition(input):
            return .activeSessionTransition(CadenceEngineV2.reduceActiveSession(
                input: input, configuration: configuration, preserveUnstartedAfterEstimate: true
            ))
        case .progressionTransition:
            return decideV2(request: request, configuration: configuration)
        }
    }

    /// Candidate policy under a separate SPI; never selected by the app.
    @_spi(AutomaticPolicyExperiment)
    static func decideDoseExperiment(
        input: V2SessionDecisionInput, now: Date, configuration: V2EngineConfiguration,
        memory: [V2DoseMemory] = [], feedback: [V2DoseFeedback] = []
    ) -> V2DoseExperimentResult {
        CadenceEngineV2.decideDoseExperiment(input: input, now: now, configuration: configuration,
                                             memory: memory, feedback: feedback)
    }

    static func decideV2(
        request: V2EngineRequest,
        configuration: V2EngineConfiguration
    ) -> V2EngineResult {
        CadenceEngineV2.evaluate(request, configuration: configuration)
    }
}

// Simulation-only SPI: the normal public dispatcher never supplies this value.
// No persisted policy or application default is changed by the experiment.
@_spi(AutomaticPolicyExperiment) public enum V2AutomaticSizingExperiment: String, Sendable {
    case catalogMaximum
    case catalogMinimum
    case capAtTwo
}

enum CadenceEngineV2 {
    static func evaluate(
        _ request: V2EngineRequest,
        configuration: V2EngineConfiguration
    ) -> V2EngineResult {
        switch request {
        case let .sessionDecision(input, now):
            return .sessionDecision(decideNextSession(input: input, now: now, configuration: configuration))
        case let .progressionTransition(input):
            return .progressionTransition(progressPrescription(input: input, configuration: configuration))
        case let .activeSessionTransition(input):
            return .activeSessionTransition(reduceActiveSession(input: input, configuration: configuration))
        }
    }

    static func decideNextSession(
        input: V2SessionDecisionInput,
        now: Date,
        configuration: V2EngineConfiguration,
        experimentalSizing: V2AutomaticSizingExperiment? = nil
    ) -> V2SessionDecision {
        let mode = input.request.mode ?? .normal
        let requestedBudget = configuration.policy.durationBudgetsSeconds[String(input.request.durationMinutes)]
        guard experimentalSizing != nil || requestedBudget != nil else {
            return sessionDecision(
                .requestValidInput,
                mode: mode,
                configuration: configuration,
                reasons: [reason("invalid_duration", scope: "session", source: "user", configuration: configuration)]
            )
        }
        guard input.request.remainingSeconds.map({ $0 >= 0 }) ?? true,
              inventoryIsCoherent(input.todayInventory),
              input.history.allSatisfy({ parseDate($0.endedAt).map { $0 <= now } ?? false }) else {
            return sessionDecision(
                .requestValidInput,
                mode: mode,
                configuration: configuration,
                reasons: [reason("invalid_input", scope: "session", source: "user", configuration: configuration)]
            )
        }
        if input.declaredCurrentHealthSignal {
            return sessionDecision(
                .stopStandardSession,
                mode: mode,
                configuration: configuration,
                reasons: [reason("safety_stop_session", scope: "session", source: "safety", configuration: configuration)]
            )
        }
        if input.declaredScope != nil {
            return sessionDecision(
                .blockStandardMode,
                mode: mode,
                configuration: configuration,
                reasons: [reason("standard_mode_outside_v2_scope", scope: "session", source: "product_scope", configuration: configuration)]
            )
        }

        let budget: Int? = experimentalSizing == nil ? (input.request.remainingSeconds ?? requestedBudget) : nil
        if let active = input.activeSession {
            guard active.catalogVersion == configuration.catalogVersion,
                  active.decisionPolicyVersion == configuration.decisionPolicyVersion else {
                return V2SessionDecision(
                    catalogVersion: configuration.catalogVersion,
                    decisionPolicyVersion: configuration.decisionPolicyVersion,
                    decision: .requestValidInput,
                    sessionId: active.sessionId,
                    mode: active.mode,
                    confirmed: active.confirmed,
                    reasons: [reason(
                        "active_session_version_incompatible",
                        scope: "session",
                        source: "history",
                        configuration: configuration
                    )],
                    confirmedImmutable: true
                )
            }
            return adaptActiveSession(
                input: input,
                active: active,
                budget: budget,
                now: now,
                configuration: configuration,
                experimentalSizing: experimentalSizing
            )
        }

        let normal = buildSession(
            input: input,
            mode: mode == .light ? .normal : mode,
            budget: budget,
            now: now,
            configuration: configuration,
            preferredExerciseIds: nil,
            experimentalSizing: experimentalSizing
        )
        guard mode == .light, normal.decision == .generateSession else { return normal }
        return lighten(normal, input: input, configuration: configuration)
    }

    static func decideDoseExperiment(
        input: V2SessionDecisionInput, now: Date, configuration: V2EngineConfiguration,
        memory: [V2DoseMemory], feedback: [V2DoseFeedback]
    ) -> V2DoseExperimentResult {
        let requestedMode = input.request.mode ?? .normal
        let normalInput = V2SessionDecisionInput(
            request: .init(durationMinutes: input.request.durationMinutes,
                           mode: requestedMode == .light ? .normal : requestedMode,
                           remainingSeconds: input.request.remainingSeconds),
            persistentInventory: input.persistentInventory, todayInventory: input.todayInventory,
            todaySupports: input.todaySupports, history: input.history, refusals: input.refusals,
            activeSession: input.activeSession, declaredCurrentHealthSignal: input.declaredCurrentHealthSignal,
            declaredScope: input.declaredScope)
        let base = decideNextSession(input: normalInput, now: now, configuration: configuration, experimentalSizing: .capAtTwo)
        guard base.decision == .generateSession, input.activeSession == nil else {
            return V2DoseExperimentResult(decision: base, memory: memory)
        }
        var reasons = base.reasons
        func note(_ code: String, _ context: String, source: String = "user") {
            reasons.append(V2Reason(code: code, scope: "configuration", source: source,
                message: "\(context): \(code)", decisionPolicyVersion: "dose-choice-v1"))
        }
        let validMemory = memory.filter { record in
            guard record.at <= now, record.catalogVersion == configuration.catalogVersion,
                  record.decisionPolicyVersion == configuration.decisionPolicyVersion,
                  record.experimentVersion == "dose-choice-v1",
                  let exercise = configuration.catalog[record.lastPlan.exerciseId],
                  exercise.progressionContext == record.lastPlan.progressionContext,
                  (exercise.sets.min...exercise.sets.max).contains(record.ordinarySets),
                  (exercise.sets.min...exercise.sets.max).contains(record.lastPlan.sets),
                  record.ordinarySets == 2 || record.preferenceSource != nil else { return false }
            // Non-selected contexts retain their decision record; no temporary inventory loss erases a preference.
            guard base.plan.contains(where: { $0.progressionContext == record.lastPlan.progressionContext }) else { return true }
            return dosePlanAvailable(record.lastPlan, exercise: exercise, input: input, configuration: configuration)
        }
        var nextMemory = validMemory
        var plan: [V2PlanItem] = []
        for item in base.plan {
            guard let exercise = configuration.catalog[item.exerciseId] else { continue }
            let context = item.progressionContext
            let prior = validMemory.filter { $0.lastPlan.progressionContext == context }
                .sorted { $0.at > $1.at }.first
            let ordinary = max(exercise.sets.min, min(exercise.sets.max, prior?.ordinarySets ?? 2))
            var chosen = ordinary
            var preferenceSource = prior?.preferenceSource
            var sets = ordinary
            var reps = item.targetReps
            var load = item.load
            let responses = feedback.filter { $0.progressionContext == context }
            let response = responses.count == 1 ? responses.first : nil
            let validResponse = response.flatMap {
                $0.at == now && $0.catalogVersion == configuration.catalogVersion
                    && $0.decisionPolicyVersion == configuration.decisionPolicyVersion ? $0 : nil
            }
            if !responses.isEmpty && validResponse == nil { note("dose_feedback_ignored", context) }
            let history = doseHistory(context: context, input: input, now: now, configuration: configuration)
            if history.contains(where: { $0.confirmedSets.count != ordinary }) {
                note("dose_historical_not_adopted", context, source: "history")
            }
            if let response = validResponse {
                note("dose_feedback_" + response.action.rawValue, context)
                switch response.action {
                case .discover:
                    sets = exercise.sets.min
                    note("dose_discovery_selected", context)
                case .preferOrdinary:
                    chosen = max(exercise.sets.min, min(exercise.sets.max, 2)); sets = chosen
                    preferenceSource = response.source
                case .preferHistorical:
                    let matching = history.filter {
                        $0.confirmedSets.count == response.historicalSets
                            && $0.source == (response.source == .syntheticScenario ? .syntheticScenario : .nativeConfirmed)
                    }
                    if let requested = response.historicalSets,
                       (exercise.sets.min...exercise.sets.max).contains(requested), matching.count >= 2,
                       matching[0].confirmedSets.map(\.repetitions) == matching[1].confirmedSets.map(\.repetitions),
                       matching[0].confirmedSets.map(\.loadKg) == matching[1].confirmedSets.map(\.loadKg),
                       matching[0].confirmedSets.map(\.loadOptionID) == matching[1].confirmedSets.map(\.loadOptionID) {
                        chosen = requested
                        sets = chosen; preferenceSource = response.source
                        note("dose_historical_preference_confirmed", context)
                    } else { note("dose_historical_preference_unavailable", context, source: "history") }
                case .volumeTooHigh:
                    chosen = max(exercise.sets.min, ordinary - 1); sets = chosen
                    preferenceSource = response.source
                case .difficultyTooHigh:
                    let reference = latestReferences(input.history, configuration: configuration)[context]
                    reps = exercise.repRange.min
                    load = recalibrationLoad(exercise, reference: reference, inventory: input.todayInventory)
                case .difficultyTooLow:
                    if item.targetReps >= exercise.repRange.max,
                       nextLoad(after: item.load, for: exercise, inventory: input.todayInventory) == nil {
                        note("dose_equipment_limit", context, source: "equipment")
                    }
                case .trainedElsewhere, .noTrainingElsewhere:
                    note("dose_external_training_unknown_performance", context)
                }
            }
            if requestedMode == .recalibration {
                sets = exercise.sets.min
                note(item.referenceStatus == "new" ? "dose_discovery_selected" : "dose_return_selected", context)
            }
            // The previous prescription is a decision record, never inferred from completed volume.
            if sets > (prior?.lastPlan.sets ?? ordinary) {
                if let old = prior?.lastPlan,
                   old.exerciseId == item.exerciseId, old.progressionContext == context,
                   dosePlanAvailable(old, exercise: exercise, input: input, configuration: configuration) {
                    reps = old.targetReps; load = old.load
                    note("dose_increase_only", context)
                } else {
                    sets = prior?.lastPlan.sets ?? ordinary
                    chosen = ordinary
                    note("dose_increase_deferred", context)
                }
            }
            let updated = V2PlanItem(exerciseId: item.exerciseId, sourceExerciseId: item.sourceExerciseId,
                sets: sets, targetReps: reps, restSeconds: item.restSeconds, load: load,
                referenceStatus: item.referenceStatus, progressionContext: context, targetUnit: item.targetUnit)
            plan.append(updated)
            nextMemory.removeAll { $0.lastPlan.progressionContext == context }
            nextMemory.append(V2DoseMemory(ordinarySets: chosen, lastPlan: updated, at: now,
                preferenceSource: preferenceSource, catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion))
        }
        let estimated = plan.reduce(0) { total, item in
            guard let exercise = configuration.catalog[item.exerciseId] else { return total }
            return total + cost(row: MutableRow(candidate: Candidate(exerciseId: item.exerciseId,
                sourceExerciseId: item.sourceExerciseId, substitutionType: nil), sets: item.sets,
                targetReps: item.targetReps, restSeconds: item.restSeconds, load: item.load,
                referenceStatus: item.referenceStatus, progressionContext: item.progressionContext),
                sets: item.sets, exercise: exercise)
        }
        let normal = V2SessionDecision(catalogVersion: base.catalogVersion, decisionPolicyVersion: base.decisionPolicyVersion,
            decision: base.decision, mode: base.mode, estimatedSeconds: estimated, plan: plan,
            coveredAnchors: base.coveredAnchors, omittedAnchors: base.omittedAnchors, reasons: reasons)
        let decision = requestedMode == .light ? lighten(normal, input: input, configuration: configuration) : normal
        // A light session affects the last proposed plan, not the ordinary preference.
        if decision.decision == .generateSession {
            for item in decision.plan {
                if let index = nextMemory.firstIndex(where: { $0.lastPlan.progressionContext == item.progressionContext }) {
                    let old = nextMemory[index]
                    nextMemory[index] = V2DoseMemory(ordinarySets: old.ordinarySets, lastPlan: item, at: now,
                        preferenceSource: old.preferenceSource, catalogVersion: old.catalogVersion,
                        decisionPolicyVersion: old.decisionPolicyVersion)
                }
            }
        } else { nextMemory = validMemory }
        return V2DoseExperimentResult(decision: decision, memory: nextMemory.sorted { $0.lastPlan.progressionContext < $1.lastPlan.progressionContext })
    }

    static func progressPrescription(
        input: V2ProgressionInput,
        configuration: V2EngineConfiguration
    ) -> V2ProgressionDecision {
        let previous = input.previousPrescription
        guard previous.catalogVersion == configuration.catalogVersion,
              previous.decisionPolicyVersion == configuration.decisionPolicyVersion,
              let exercise = configuration.catalog[previous.exerciseId],
              exercise.progressionContext == previous.progressionContext,
              exerciseIsAvailable(exercise, inventory: input.todayInventory, supports: input.todaySupports, configuration: configuration) else {
            return progressionDecision(
                .holdPrescription,
                prescription: previous,
                configuration: configuration,
                reasonCode: "progression_held_no_comparable_reference"
            )
        }

        guard exercise.resolvedTargetUnit == .repetitions else {
            return progressionDecision(
                .holdPrescription,
                prescription: previous,
                configuration: configuration,
                reasonCode: "progression_held_non_repetition_target"
            )
        }

        let admissible = input.exposures.filter {
            $0.allPrescribedSetsConfirmed
                && !$0.interruptedBySafetySignal
                && $0.progressionContext == previous.progressionContext
                && $0.catalogVersion == configuration.catalogVersion
                && $0.decisionPolicyVersion == configuration.decisionPolicyVersion
                && $0.confirmedReps.count == previous.sets
                && $0.confirmedReps.allSatisfy { $0 >= previous.targetReps }
                && comparableLoad(
                    exposureKg: $0.loadKg,
                    exposureOptionID: $0.loadOptionID,
                    prescribed: previous.load,
                    mode: exercise.loadMode
                )
        }
        guard !admissible.isEmpty else {
            return progressionDecision(
                .holdPrescription,
                prescription: previous,
                configuration: configuration,
                reasonCode: "progression_held_no_comparable_reference"
            )
        }

        if previous.targetReps < exercise.repRange.max {
            let next = V2Prescription(
                exerciseId: previous.exerciseId,
                sets: previous.sets,
                targetReps: previous.targetReps + 1,
                load: previous.load,
                progressionContext: previous.progressionContext
            )
            return V2ProgressionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .updatePrescription,
                nextPrescription: next,
                changedFields: ["targetReps"],
                reasons: [reason("progression_repetitions_increased", scope: "configuration", source: "history", configuration: configuration)]
            )
        }

        let confirmations = configuration.policy.rangeCeilingConfirmations
        guard admissible.count >= confirmations,
              let nextLoad = nextLoad(
                after: previous.load,
                for: exercise,
                inventory: input.todayInventory
              ) else {
            return progressionDecision(
                .holdPrescription,
                prescription: previous,
                configuration: configuration,
                reasonCode: "progression_held_no_real_load_step"
            )
        }

        let next = V2Prescription(
            exerciseId: previous.exerciseId,
            sets: previous.sets,
            targetReps: exercise.repRange.min,
            load: nextLoad,
            progressionContext: previous.progressionContext
        )
        return V2ProgressionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: .updatePrescription,
            nextPrescription: next,
            changedFields: ["load", "targetReps"],
            atomicChange: "load_step_with_range_reset",
            reasons: [reason("progression_next_real_load", scope: "configuration", source: "history", configuration: configuration)]
        )
    }

    static func reduceActiveSession(
        input: V2ActiveTransitionInput,
        configuration: V2EngineConfiguration,
        preserveUnstartedAfterEstimate: Bool = false
    ) -> V2ActiveTransitionDecision {
        if input.action == .declareHealthSignal {
            return V2ActiveTransitionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .stopCurrentMovement,
                confirmed: input.confirmed,
                exposedActions: ["end_session"],
                loadedAlternative: nil,
                reasons: [reason("safety_stop_movement", scope: "movement", source: "safety", configuration: configuration)]
            )
        }
        guard input.catalogVersion == configuration.catalogVersion,
              input.decisionPolicyVersion == configuration.decisionPolicyVersion else {
            return V2ActiveTransitionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .requestValidInput,
                confirmed: input.confirmed,
                reasons: [reason(
                    "active_session_version_incompatible",
                    scope: "session",
                    source: "history",
                    configuration: configuration
                )]
            )
        }
        return finishOnTime(input: input, configuration: configuration, preserveUnstartedAfterEstimate: preserveUnstartedAfterEstimate)
    }
}

// Shared internal primitives for the legacy and personalized entry points.
extension CadenceEngineV2 {
    struct Candidate: Sendable {
        let exerciseId: String
        let sourceExerciseId: String?
        let substitutionType: String?
    }

    struct MutableRow: Sendable {
        let candidate: Candidate
        var sets: Int
        let targetReps: Int
        let restSeconds: Int
        let load: V2Load?
        let referenceStatus: String
        let progressionContext: String
    }

    static func buildSession(
        input: V2SessionDecisionInput,
        mode: V2SessionMode,
        budget: Int?,
        now: Date,
        configuration: V2EngineConfiguration,
        preferredExerciseIds: [String]?,
        restrictToPreferred: Bool = false,
        preservedWork: [String: V2UnstartedWork] = [:],
        setCaps: [String: Int] = [:],
        forcedCandidates: [Candidate]? = nil,
        experimentalSizing: V2AutomaticSizingExperiment? = nil
    ) -> V2SessionDecision {
        let stableIds = preferredExerciseIds ?? stableExerciseIds(input.history, configuration: configuration)
        var orderedAnchors = orderedAnchors(
            history: input.history,
            configuration: configuration
        )
        if restrictToPreferred {
            let allowedAnchors = Set(stableIds.compactMap { configuration.catalog[$0]?.anchor })
            orderedAnchors = orderedAnchors.filter(allowedAnchors.contains)
        }
        var selected: [Candidate] = forcedCandidates ?? []
        var omitted: [String] = []
        var usedPartial = selected.contains { $0.substitutionType == "partial" }

        if forcedCandidates == nil {
            for anchor in orderedAnchors {
                let preferred = stableIds.first { configuration.catalog[$0]?.anchor == anchor }
                if restrictToPreferred && preferred == nil { continue }
                if let candidate = chooseCandidate(
                    anchor: anchor,
                    preferredExerciseId: preferred,
                    input: input,
                    configuration: configuration
                ) {
                    selected.append(candidate)
                    usedPartial = usedPartial || candidate.substitutionType == "partial"
                } else {
                    omitted.append(anchor)
                }
            }
        }

        guard !selected.isEmpty else {
            let refusalFiltered = !input.refusals.isEmpty
            return sessionDecision(
                .noCleanSession,
                mode: mode,
                configuration: configuration,
                reasons: [reason(
                    refusalFiltered ? "all_compatible_configurations_refused" : "no_compatible_force_configuration",
                    scope: "session",
                    source: refusalFiltered ? "user" : "product_scope",
                    configuration: configuration
                )]
            )
        }

        let references = latestReferences(input.history, configuration: configuration)
        var rows: [MutableRow] = []
        var usedSeconds = 0
        var heldUnconfirmedProgression = false
        for candidate in selected {
            guard let exercise = configuration.catalog[candidate.exerciseId] else { continue }
            let preserved = preservedWork[candidate.exerciseId]
            let generated = prescription(
                candidate: candidate,
                exercise: exercise,
                mode: mode,
                references: references,
                inventory: input.todayInventory,
                now: now,
                history: input.history,
                configuration: configuration,
                suspendUnconfirmedOnReturn: experimentalSizing != nil
            )
            if generated.referenceStatus == "reconfirmation_pending",
               let reference = references[exercise.progressionContext],
               generated.targetReps != reference.targetReps || generated.load != load(from: reference, mode: exercise.loadMode) {
                heldUnconfirmedProgression = true
            }
            let prescription = (
                targetReps: preserved?.targetReps ?? generated.targetReps,
                load: preserved?.load ?? generated.load,
                referenceStatus: preserved?.referenceStatus ?? generated.referenceStatus
            )
            guard exercise.loadMode == .bodyweight || prescription.load != nil else {
                omitted.append(exercise.anchor)
                continue
            }
            let effectiveCandidate = Candidate(
                exerciseId: candidate.exerciseId,
                sourceExerciseId: preserved?.sourceExerciseId ?? candidate.sourceExerciseId,
                substitutionType: candidate.substitutionType
            )
            let row = MutableRow(
                candidate: effectiveCandidate,
                sets: experimentalSizing == nil ? exercise.sets.min : min(exercise.sets.min, setCaps[candidate.exerciseId] ?? exercise.sets.min),
                targetReps: prescription.targetReps,
                restSeconds: preserved?.restSeconds ?? plannedRestSeconds(
                    for: exercise,
                    history: input.history,
                    configuration: configuration
                ),
                load: prescription.load,
                referenceStatus: prescription.referenceStatus,
                progressionContext: preserved?.progressionContext ?? exercise.progressionContext
            )
            let minimumCost = cost(row: row, sets: row.sets, exercise: exercise)
            guard budget.map({ usedSeconds + minimumCost <= $0 }) ?? true else {
                omitted.append(exercise.anchor)
                continue
            }
            rows.append(row)
            usedSeconds += minimumCost
        }

        guard !rows.isEmpty else {
            return sessionDecision(
                .noCleanSession,
                mode: mode,
                configuration: configuration,
                reasons: [reason("no_compatible_force_configuration", scope: "session", source: "time", configuration: configuration)]
            )
        }

        let optionalLimit = budget.map { $0 >= 2_700 ? 2 : ($0 >= 1_800 ? 1 : 0) } ?? 0
        if optionalLimit > 0 {
            let alreadySelectedMovements = Set(rows.compactMap {
                configuration.catalog[$0.candidate.exerciseId]?.resolvedMovementId
            })
            var addedMovements = Set<String>()
            let optionalCandidates = configuration.catalog
                .filter { id, exercise in
                    exercise.resolvedSelectionRole == .optional
                        && !alreadySelectedMovements.contains(exercise.resolvedMovementId)
                        && !isRefused(id, exercise: exercise, refusals: input.refusals)
                        && exerciseIsAvailable(
                            exercise,
                            inventory: input.todayInventory,
                            supports: input.todaySupports,
                            configuration: configuration
                        )
                }
                .sorted {
                    let leftExposure = latestMovementExposure(
                        movementID: $0.value.resolvedMovementId,
                        history: input.history,
                        configuration: configuration
                    )
                    let rightExposure = latestMovementExposure(
                        movementID: $1.value.resolvedMovementId,
                        history: input.history,
                        configuration: configuration
                    )
                    if leftExposure != rightExposure {
                        return (leftExposure ?? .distantPast) < (rightExposure ?? .distantPast)
                    }
                    return ($0.value.selectionRank, $0.key) < ($1.value.selectionRank, $1.key)
                }

            for (id, exercise) in optionalCandidates {
                guard rows.filter({
                    configuration.catalog[$0.candidate.exerciseId]?.resolvedSelectionRole == .optional
                }).count < optionalLimit else { break }
                guard addedMovements.insert(exercise.resolvedMovementId).inserted else { continue }
                let candidate = Candidate(exerciseId: id, sourceExerciseId: nil, substitutionType: nil)
                let generated = prescription(
                    candidate: candidate,
                    exercise: exercise,
                    mode: mode,
                    references: references,
                    inventory: input.todayInventory,
                    now: now,
                    history: input.history,
                    configuration: configuration,
                suspendUnconfirmedOnReturn: experimentalSizing != nil
                )
                guard exercise.loadMode == .bodyweight || generated.load != nil else { continue }
                let row = MutableRow(
                    candidate: candidate,
                    sets: exercise.sets.min,
                    targetReps: generated.targetReps,
                    restSeconds: plannedRestSeconds(
                        for: exercise,
                        history: input.history,
                        configuration: configuration
                    ),
                    load: generated.load,
                    referenceStatus: generated.referenceStatus,
                    progressionContext: exercise.progressionContext
                )
                let minimumCost = cost(row: row, sets: row.sets, exercise: exercise)
                guard budget.map({ usedSeconds + minimumCost <= $0 }) ?? true else { continue }
                rows.append(row)
                usedSeconds += minimumCost
            }
        }

        let conditioningCandidates = configuration.catalog
            .filter { id, exercise in
                exercise.resolvedSelectionRole == .conditioning
                    && !isRefused(id, exercise: exercise, refusals: input.refusals)
                    && exerciseIsAvailable(
                        exercise,
                        inventory: input.todayInventory,
                        supports: input.todaySupports,
                        configuration: configuration
                    )
            }
            .sorted(by: { ($0.value.selectionRank, $0.key) < ($1.value.selectionRank, $1.key) })
        if let budget, budget >= 2_700, let (id, exercise) = conditioningCandidates.first {
            let candidate = Candidate(exerciseId: id, sourceExerciseId: nil, substitutionType: nil)
            let row = MutableRow(
                candidate: candidate,
                sets: exercise.sets.min,
                targetReps: exercise.repRange.entry,
                restSeconds: exercise.timingSeconds.rest,
                load: nil,
                referenceStatus: "new",
                progressionContext: exercise.progressionContext
            )
            let minimumCost = cost(row: row, sets: row.sets, exercise: exercise)
            if usedSeconds + minimumCost <= budget {
                rows.append(row)
                usedSeconds += minimumCost
            }
        }

        while true {
            var addedInPass = false
            for index in rows.indices {
                let exercise = configuration.catalog[rows[index].candidate.exerciseId]!
                let plannedCap = setCaps[rows[index].candidate.exerciseId]
                    ?? preservedWork[rows[index].candidate.exerciseId].map { max(exercise.sets.min, $0.sets) }
                let experimentCap: Int
                switch experimentalSizing {
                case .catalogMinimum: experimentCap = exercise.sets.min
                case .capAtTwo: experimentCap = max(exercise.sets.min, min(exercise.sets.max, 2))
                default: experimentCap = exercise.sets.max
                }
                let maximum = min(exercise.sets.max, plannedCap ?? experimentCap)
                guard rows[index].sets < maximum else { continue }
                let oldCost = cost(row: rows[index], sets: rows[index].sets, exercise: exercise)
                let newCost = cost(row: rows[index], sets: rows[index].sets + 1, exercise: exercise)
                let marginal = newCost - oldCost
                if budget.map({ usedSeconds + marginal <= $0 }) ?? true {
                    rows[index].sets += 1
                    usedSeconds += marginal
                    addedInPass = true
                }
            }
            if !addedInPass { break }
        }

        let plan = rows.map { planItem($0, configuration: configuration) }
        let covered = rows.compactMap { configuration.catalog[$0.candidate.exerciseId]?.anchor }
        var reasons: [V2Reason] = []
        if heldUnconfirmedProgression {
            reasons.append(reason("stale_unconfirmed_progression_held", scope: "configuration", source: "history", configuration: configuration))
        }
        if inventoriesDiffer(input.persistentInventory, input.todayInventory) {
            reasons.append(reason("equipment_temporarily_unavailable", scope: "session", source: "equipment", configuration: configuration))
        }
        if input.refusals.contains(where: { $0.temporalScope == "persistent" }) {
            reasons.append(reason("refusal_persistent", scope: "movement", source: "user", configuration: configuration))
        } else if input.refusals.contains(where: { $0.temporalScope == "today" }) {
            reasons.append(reason("refusal_today", scope: "movement", source: "user", configuration: configuration))
        }
        if mode == .recalibration {
            reasons.append(reason("recalibration_user_selected", scope: "session", source: "user", configuration: configuration))
        }
        if usedPartial {
            let source = input.refusals.isEmpty ? "equipment" : "user"
            reasons.append(reason("partial_substitution_new_reference", scope: "movement", source: source, configuration: configuration))
        }
        if plan.contains(where: { $0.referenceStatus == "reconfirmation_pending" }) {
            reasons.append(reason("progression_held_reference_to_reconfirm", scope: "configuration", source: "history", configuration: configuration))
        }
        if mode == .normal, plan.contains(where: { $0.referenceStatus == "recalibrating" }) {
            reasons.append(reason("progression_held_no_comparable_reference", scope: "configuration", source: "history", configuration: configuration))
        }
        let uniqueOmitted = stableUnique(omitted.filter { !covered.contains($0) })
        if !uniqueOmitted.isEmpty {
            let source = inventoriesDiffer(input.persistentInventory, input.todayInventory) ? "equipment" : "product_scope"
            reasons.append(reason("anchor_omitted_no_compatible_movement", scope: "movement", source: source, configuration: configuration))
        }
        return V2SessionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: .generateSession,
            mode: mode,
            estimatedSeconds: usedSeconds,
            plan: plan,
            coveredAnchors: covered,
            omittedAnchors: uniqueOmitted,
            reasons: stableUniqueReasons(reasons),
            automaticProgression: false,
            persistentInventoryChanged: false
        )
    }

    static func adaptActiveSession(
        input: V2SessionDecisionInput,
        active: V2ActiveSession,
        budget: Int?,
        now: Date,
        configuration: V2EngineConfiguration,
        experimentalSizing: V2AutomaticSizingExperiment? = nil
    ) -> V2SessionDecision {
        guard active.unstarted.allSatisfy({ plannedWorkIsCoherent($0, configuration: configuration) }) else {
            return V2SessionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .requestValidInput,
                sessionId: active.sessionId,
                mode: active.mode,
                confirmed: active.confirmed,
                reasons: [reason("invalid_input", scope: "session", source: "history", configuration: configuration)],
                confirmedImmutable: true
            )
        }
        var withoutActive = input
        withoutActive = V2SessionDecisionInput(
            request: V2SessionRequest(
                durationMinutes: input.request.durationMinutes,
                mode: active.mode,
                remainingSeconds: input.request.remainingSeconds
            ),
            persistentInventory: input.persistentInventory,
            todayInventory: input.todayInventory,
            todaySupports: input.todaySupports,
            history: input.history,
            refusals: input.refusals,
            activeSession: nil,
            declaredCurrentHealthSignal: false,
            declaredScope: nil
        )
        let activeResolutions = active.unstarted.compactMap { work -> (V2UnstartedWork, Candidate)? in
            guard let definition = configuration.catalog[work.exerciseId] else { return nil }
            guard let candidate = chooseCandidate(
                anchor: definition.anchor,
                preferredExerciseId: work.exerciseId,
                input: withoutActive,
                configuration: configuration,
                allowDirectFallback: false
            ) else { return nil }
            return (work, candidate)
        }
        let activeCandidates = activeResolutions.map { $0.1 }
        let preservedWork = activeResolutions.reduce(into: [String: V2UnstartedWork]()) { result, resolution in
            let (work, candidate) = resolution
            guard candidate.exerciseId == work.exerciseId,
                  let exercise = configuration.catalog[work.exerciseId],
                  plannedLoadIsUsable(work.load, for: exercise, inventory: input.todayInventory) else { return }
            result[work.exerciseId] = work
        }
        var setCaps: [String: Int] = [:]
        for (work, candidate) in activeResolutions {
            setCaps[candidate.exerciseId] = work.sets
        }
        let rebuilt = buildSession(
            input: withoutActive,
            mode: active.mode,
            budget: budget,
            now: now,
            configuration: configuration,
            preferredExerciseIds: active.unstarted.map(\.exerciseId),
            restrictToPreferred: true,
            preservedWork: preservedWork,
            setCaps: setCaps,
            forcedCandidates: activeCandidates,
            experimentalSizing: experimentalSizing
        )
        guard rebuilt.decision == .generateSession else {
            return V2SessionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .resumeOrAdaptActiveSession,
                sessionId: active.sessionId,
                mode: active.mode,
                confirmed: active.confirmed,
                reasons: [reason("active_session_revalidated", scope: "session", source: "user", configuration: configuration)],
                confirmedImmutable: true,
                createsDebt: false
            )
        }
        return V2SessionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: .resumeOrAdaptActiveSession,
            sessionId: active.sessionId,
            mode: active.mode,
            estimatedSeconds: rebuilt.estimatedSeconds,
            plan: rebuilt.plan,
            confirmed: active.confirmed,
            coveredAnchors: [],
            omittedAnchors: [],
            reasons: stableUniqueReasons(
                [reason("active_session_revalidated", scope: "session", source: "user", configuration: configuration)]
                    + rebuilt.reasons.filter { $0.code != "anchor_omitted_no_compatible_movement" }
            ),
            automaticProgression: false,
            confirmedImmutable: true,
            createsDebt: false,
            persistentInventoryChanged: false
        )
    }

    static func lighten(
        _ normal: V2SessionDecision,
        input: V2SessionDecisionInput,
        configuration: V2EngineConfiguration
    ) -> V2SessionDecision {
        var reduced: [V2PlanItem] = []
        for item in normal.plan {
            guard let exercise = configuration.catalog[item.exerciseId] else { continue }
            let sets = item.sets > exercise.sets.min ? item.sets - 1 : item.sets
            reduced.append(V2PlanItem(
                exerciseId: item.exerciseId,
                sourceExerciseId: item.sourceExerciseId,
                sets: sets,
                targetReps: item.targetReps,
                restSeconds: item.restSeconds,
                load: item.load,
                referenceStatus: item.referenceStatus,
                progressionContext: item.progressionContext,
                targetUnit: item.targetUnit
            ))
        }
        let changed = zip(normal.plan, reduced).contains { $0.sets != $1.sets }
        guard changed else {
            return sessionDecision(
                .noCleanSession,
                mode: .light,
                configuration: configuration,
                reasons: [reason("light_plan_unavailable", scope: "session", source: "product_scope", configuration: configuration)]
            )
        }
        return V2SessionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: .generateSession,
            mode: .light,
            estimatedSeconds: estimate(reduced, configuration: configuration),
            plan: reduced,
            coveredAnchors: normal.coveredAnchors,
            omittedAnchors: normal.omittedAnchors,
            reasons: [reason("light_mode_user_selected", scope: "session", source: "user", configuration: configuration)],
            automaticProgression: false
        )
    }

    static func chooseCandidate(
        anchor: String,
        preferredExerciseId: String?,
        input: V2SessionDecisionInput,
        configuration: V2EngineConfiguration,
        allowDirectFallback: Bool = true
    ) -> Candidate? {
        if let preferredExerciseId,
           let preferred = configuration.catalog[preferredExerciseId],
           preferred.anchor == anchor {
            if !isRefused(preferredExerciseId, exercise: preferred, refusals: input.refusals),
               exerciseIsAvailable(preferred, inventory: input.todayInventory, supports: input.todaySupports, configuration: configuration) {
                return Candidate(exerciseId: preferredExerciseId, sourceExerciseId: nil, substitutionType: nil)
            }
            let alternatives = configuration.substitutions
                .filter { $0.from == preferredExerciseId && $0.type != "forbidden" }
                .sorted { ($0.rank, $0.to) < ($1.rank, $1.to) }
            for relation in alternatives {
                guard let exercise = configuration.catalog[relation.to],
                      exercise.anchor == anchor,
                      !isRefused(relation.to, exercise: exercise, refusals: input.refusals),
                      exerciseIsAvailable(exercise, inventory: input.todayInventory, supports: input.todaySupports, configuration: configuration) else { continue }
                return Candidate(
                    exerciseId: relation.to,
                    sourceExerciseId: preferredExerciseId,
                    substitutionType: relation.type
                )
            }
            guard allowDirectFallback else { return nil }
            return directCandidate(
                anchor: anchor,
                excluding: Set([preferredExerciseId]),
                input: input,
                configuration: configuration
            )
        }

        return directCandidate(anchor: anchor, excluding: [], input: input, configuration: configuration)
    }

    static func directCandidate(
        anchor: String,
        excluding: Set<String>,
        input: V2SessionDecisionInput,
        configuration: V2EngineConfiguration
    ) -> Candidate? {
        configuration.catalog
            .filter { id, exercise in
                exercise.anchor == anchor
                    && exercise.resolvedSelectionRole == .anchor
                    && !excluding.contains(id)
                    && exercise.catalogStatus == "published_in_fixture_catalog"
                    && !isRefused(id, exercise: exercise, refusals: input.refusals)
                    && exerciseIsAvailable(exercise, inventory: input.todayInventory, supports: input.todaySupports, configuration: configuration)
            }
            .sorted {
                let left = ($0.value.selectionRank, $0.key)
                let right = ($1.value.selectionRank, $1.key)
                return left < right
            }
            .first
            .map { Candidate(exerciseId: $0.key, sourceExerciseId: nil, substitutionType: nil) }
    }

    static func prescription(
        candidate: Candidate,
        exercise: V2ExerciseDefinition,
        mode: V2SessionMode,
        references: [String: V2Reference],
        inventory: [V2InventoryItem],
        now: Date,
        history: [V2HistoryEntry],
        configuration: V2EngineConfiguration,
        suspendUnconfirmedOnReturn: Bool = false
    ) -> (targetReps: Int, load: V2Load?, referenceStatus: String) {
        let reference = references[exercise.progressionContext]
        if candidate.substitutionType == "partial" {
            return (
                exercise.repRange.entry,
                entryLoad(exercise, inventory: inventory),
                "new_after_partial_substitution"
            )
        }
        if mode == .recalibration {
            let load = recalibrationLoad(exercise, reference: reference, inventory: inventory)
            return (exercise.repRange.min, load, reference == nil ? "new" : "recalibrating")
        }
        if let reference {
            let referenceLoadIsUsable: Bool
            if exercise.loadMode == .bodyweight {
                referenceLoadIsUsable = reference.loadKg == nil
            } else if exercise.loadMode == .bandOption {
                referenceLoadIsUsable = reference.loadOptionID.map {
                    availableOptions(for: exercise, inventory: inventory).contains($0)
                } ?? false
            } else if let load = reference.loadKg {
                referenceLoadIsUsable = availableWeights(for: exercise, inventory: inventory).contains(load)
            } else {
                referenceLoadIsUsable = false
            }
            if !referenceLoadIsUsable {
                return (
                    exercise.repRange.min,
                    recalibrationLoad(exercise, reference: reference, inventory: inventory),
                    "recalibrating"
                )
            }
            let oldEnoughForQuestion = latestReferenceDate(
                progressionContext: exercise.progressionContext,
                history: history,
                configuration: configuration
            ).map {
                now.timeIntervalSince($0) >= Double(configuration.policy.returnQuestionAfterDaysWithoutComparableExposure * 86_400)
            } ?? false
            if oldEnoughForQuestion && suspendUnconfirmedOnReturn,
               let anchor = confirmedReturnAnchor(exercise: exercise, reference: reference, history: history,
                                                  inventory: inventory, now: now, configuration: configuration) {
                return (anchor.targetReps, load(from: anchor, mode: exercise.loadMode), "reconfirmation_pending")
            }
            let status = oldEnoughForQuestion ? "reconfirmation_pending" : "kept"
            return (
                min(max(reference.targetReps, exercise.repRange.min), exercise.repRange.max),
                load(from: reference, mode: exercise.loadMode),
                status
            )
        }
        return (exercise.repRange.entry, entryLoad(exercise, inventory: inventory), "new")
    }

    static func finishOnTime(
        input: V2ActiveTransitionInput,
        configuration: V2EngineConfiguration,
        preserveUnstartedAfterEstimate: Bool = false
    ) -> V2ActiveTransitionDecision {
        guard input.remainingSeconds.map({ $0 >= 0 }) ?? false,
              input.unstarted.allSatisfy({ plannedWorkIsCoherent($0, configuration: configuration) }) else {
            return V2ActiveTransitionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .requestValidInput,
                confirmed: input.confirmed,
                reasons: [reason("invalid_input", scope: "session", source: "time", configuration: configuration)]
            )
        }
        let budget = max(0, input.remainingSeconds ?? 0)
        var remaining = input.unstarted.map { work in
            MutableRow(
                candidate: Candidate(
                    exerciseId: work.exerciseId,
                    sourceExerciseId: work.sourceExerciseId,
                    substitutionType: nil
                ),
                sets: work.sets,
                targetReps: work.targetReps,
                restSeconds: work.restSeconds,
                load: work.load,
                referenceStatus: work.referenceStatus,
                progressionContext: work.progressionContext
            )
        }
        // This path is reachable only by the internal experiment, after validation.
        // It preserves the work supplied now; it cannot restore work removed earlier.
        if preserveUnstartedAfterEstimate {
            let plan = remaining.map { planItem($0, configuration: configuration) }
            return V2ActiveTransitionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .activeSessionTransition,
                estimatedSeconds: estimate(plan, configuration: configuration),
                plan: plan,
                confirmed: input.confirmed
            )
        }
        let originalSets = Dictionary(uniqueKeysWithValues: input.unstarted.map { ($0.exerciseId, $0.sets) })

        if estimate(remaining.map { planItem($0, configuration: configuration) }, configuration: configuration) > budget {
            for index in remaining.indices.reversed() {
                guard let exercise = configuration.catalog[remaining[index].candidate.exerciseId] else { continue }
                while remaining[index].sets > exercise.sets.min,
                      estimate(remaining.map { planItem($0, configuration: configuration) }, configuration: configuration) > budget {
                    remaining[index].sets -= 1
                }
            }
        }
        if estimate(remaining.map { planItem($0, configuration: configuration) }, configuration: configuration) > budget {
            for index in remaining.indices.reversed() {
                guard remaining[index].sets > 0 else { continue }
                let old = remaining[index].sets
                remaining[index].sets = 0
                if estimate(remaining.map { planItem($0, configuration: configuration) }, configuration: configuration) <= budget {
                    break
                }
                if old == 0 { continue }
            }
        }
        let plan = remaining.filter { $0.sets > 0 }.map { planItem($0, configuration: configuration) }
        let removed = input.unstarted.compactMap { work -> V2RemovedWork? in
            let kept = remaining.first { $0.candidate.exerciseId == work.exerciseId }?.sets ?? 0
            let count = (originalSets[work.exerciseId] ?? work.sets) - kept
            return count > 0
                ? V2RemovedWork(exerciseId: work.exerciseId, sets: count, progressionContext: work.progressionContext)
                : nil
        }
        return V2ActiveTransitionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: .activeSessionTransition,
            estimatedSeconds: estimate(plan, configuration: configuration),
            plan: plan,
            removed: removed,
            confirmed: input.confirmed,
            reasons: removed.isEmpty ? [] : [reason("time_budget_removed_unstarted_work", scope: "session", source: "time", configuration: configuration)]
        )
    }

    static func planItem(_ row: MutableRow, configuration: V2EngineConfiguration) -> V2PlanItem {
        return V2PlanItem(
            exerciseId: row.candidate.exerciseId,
            sourceExerciseId: row.candidate.sourceExerciseId,
            sets: row.sets,
            targetReps: row.targetReps,
            restSeconds: row.restSeconds,
            load: row.load,
            referenceStatus: row.referenceStatus,
            progressionContext: row.progressionContext,
            targetUnit: configuration.catalog[row.candidate.exerciseId]?.targetUnit
        )
    }

    static func estimate(_ plan: [V2PlanItem], configuration: V2EngineConfiguration) -> Int {
        plan.reduce(0) { total, item in
            guard let exercise = configuration.catalog[item.exerciseId] else { return total }
            return total
                + exercise.timingSeconds.setup
                + exercise.timingSeconds.transition
                + item.sets * (exercise.timingSeconds.execution + exercise.timingSeconds.secondSide)
                + max(0, item.sets - 1) * item.restSeconds
        }
    }

    static func confirmedReturnAnchor(exercise: V2ExerciseDefinition, reference: V2Reference,
                                      history: [V2HistoryEntry], inventory: [V2InventoryItem], now: Date,
                                      configuration: V2EngineConfiguration) -> V2Reference? {
        let facts: [V2Reference] = history.sorted { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }.compactMap { entry in
            guard entry.catalogVersion == configuration.catalogVersion,
                  entry.decisionPolicyVersion == configuration.decisionPolicyVersion,
                  let end = parseDate(entry.endedAt), end <= now,
                  let work = entry.confirmedWorkEvidence?.first(where: { $0.progressionContext == exercise.progressionContext }),
                  work.exerciseId == reference.exerciseId, work.targetUnit == exercise.resolvedTargetUnit,
                  !work.wasSkipped, !work.interruptedBySafetySignal,
                  work.plannedSets > 0, work.confirmedSets.count == work.plannedSets,
                  let first = work.confirmedSets.first,
                  work.confirmedSets.allSatisfy({
                      $0.repetitions > 0 && $0.loadKg == first.loadKg && $0.loadOptionID == first.loadOptionID
                          && parseDate($0.completedAt).map { $0 <= end } == true
                  }) else { return nil }
            let usable: Bool
            if exercise.loadMode == .bodyweight { usable = first.loadKg == nil && first.loadOptionID == nil }
            else if exercise.loadMode == .bandOption { usable = first.loadOptionID.map { availableOptions(for: exercise, inventory: inventory).contains($0) } ?? false }
            else { usable = first.loadKg.map { availableWeights(for: exercise, inventory: inventory).contains($0) } ?? false }
            guard usable else { return nil }
            let reps = min(work.confirmedSets.map(\.repetitions).min() ?? 0, exercise.repRange.max)
            guard reps >= exercise.repRange.min else { return nil }
            return V2Reference(exerciseId: work.exerciseId, loadKg: first.loadKg, loadOptionID: first.loadOptionID,
                targetReps: reps, progressionContext: work.progressionContext)
        }
        // A reference already performed is not reduced merely because time has passed.
        if facts.contains(where: { $0.loadKg == reference.loadKg && $0.loadOptionID == reference.loadOptionID && $0.targetReps >= reference.targetReps }) { return nil }
        return facts.first
    }

    static func dosePlanAvailable(_ item: V2PlanItem, exercise: V2ExerciseDefinition,
                                  input: V2SessionDecisionInput, configuration: V2EngineConfiguration) -> Bool {
        guard item.resolvedTargetUnit == exercise.resolvedTargetUnit,
              (exercise.repRange.min...exercise.repRange.max).contains(item.targetReps),
              exerciseIsAvailable(exercise, inventory: input.todayInventory, supports: input.todaySupports, configuration: configuration) else { return false }
        if exercise.loadMode == .bodyweight { return item.load == nil }
        if exercise.loadMode == .bandOption {
            return item.load?.optionID.map { availableOptions(for: exercise, inventory: input.todayInventory).contains($0) } ?? false
        }
        return item.load?.kg.map { availableWeights(for: exercise, inventory: input.todayInventory).contains($0) } ?? false
    }

    static func doseHistory(context: String, input: V2SessionDecisionInput, now: Date,
                            configuration: V2EngineConfiguration) -> [V2ConfirmedWorkEvidence] {
        var seenDates = Set<Date>()
        var seenEvents = Set<String>()
        return input.history.sorted { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }.compactMap { entry in
            guard entry.catalogVersion == configuration.catalogVersion,
                  entry.decisionPolicyVersion == configuration.decisionPolicyVersion,
                  let date = parseDate(entry.endedAt), date <= now,
                  now.timeIntervalSince(date) < Double(configuration.policy.returnQuestionAfterDaysWithoutComparableExposure * 86_400),
                  seenDates.insert(date).inserted,
                  let work = entry.confirmedWorkEvidence?.first(where: { $0.progressionContext == context }),
                  let exercise = configuration.catalog[work.exerciseId],
                  exercise.progressionContext == context, work.targetUnit == exercise.resolvedTargetUnit,
                  !work.wasSkipped, !work.interruptedBySafetySignal,
                  work.plannedSets > 0, work.confirmedSets.count == work.plannedSets,
                  work.confirmedSets.allSatisfy({ set in
                      set.repetitions > 0 && parseDate(set.completedAt).map {
                          $0 <= date && now.timeIntervalSince($0) < Double(configuration.policy.returnQuestionAfterDaysWithoutComparableExposure * 86_400)
                      } == true
                  }) else { return nil }
            let eventIDs = work.confirmedSets.compactMap(\.eventID)
            guard eventIDs.count == work.confirmedSets.count,
                  Set(eventIDs).count == eventIDs.count,
                  Set(eventIDs).isDisjoint(with: seenEvents) else { return nil }
            seenEvents.formUnion(eventIDs)
            let kg = work.confirmedSets.first?.loadKg
            let option = work.confirmedSets.first?.loadOptionID
            guard work.confirmedSets.allSatisfy({ $0.loadKg == kg && $0.loadOptionID == option }) else { return nil }
            let load = kg.map { V2Load(mode: exercise.loadMode, kg: $0) } ?? option.map(V2Load.init(optionID:))
            let comparable = V2PlanItem(exerciseId: work.exerciseId, sets: work.plannedSets,
                targetReps: exercise.repRange.entry, restSeconds: exercise.timingSeconds.rest, load: load,
                referenceStatus: "kept", progressionContext: context, targetUnit: work.targetUnit)
            return dosePlanAvailable(comparable, exercise: exercise, input: input, configuration: configuration) ? work : nil
        }
    }

    static func cost(row: MutableRow, sets: Int, exercise: V2ExerciseDefinition) -> Int {
        guard sets > 0 else { return 0 }
        return exercise.timingSeconds.setup
            + exercise.timingSeconds.transition
            + sets * (exercise.timingSeconds.execution + exercise.timingSeconds.secondSide)
            + max(0, sets - 1) * row.restSeconds
    }

    static func stableExerciseIds(
        _ history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> [String] {
        history.filter {
            $0.catalogVersion == configuration.catalogVersion
                && $0.decisionPolicyVersion == configuration.decisionPolicyVersion
        }
            .sorted { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }
            .flatMap { entry in
                (entry.references?.map(\.exerciseId) ?? []) + (entry.completedExerciseIds ?? [])
            }
            .reduce(into: [String]()) { ids, id in
                if !ids.contains(id) { ids.append(id) }
            }
    }

    static func latestReferences(
        _ history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> [String: V2Reference] {
        var result: [String: V2Reference] = [:]
        let comparable = history.filter {
            $0.catalogVersion == configuration.catalogVersion
                && $0.decisionPolicyVersion == configuration.decisionPolicyVersion
        }
        for entry in comparable.sorted(by: { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }) {
            for reference in entry.references ?? [] where result[reference.progressionContext] == nil {
                result[reference.progressionContext] = reference
            }
        }
        return result
    }

    static func latestReferenceDate(
        progressionContext: String,
        history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> Date? {
        history.compactMap { entry -> Date? in
            guard entry.catalogVersion == configuration.catalogVersion,
                  entry.decisionPolicyVersion == configuration.decisionPolicyVersion else { return nil }
            guard entry.references?.contains(where: { $0.progressionContext == progressionContext }) == true else { return nil }
            return parseDate(entry.endedAt)
        }.max()
    }

    static func latestMovementExposure(
        movementID: String,
        history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> Date? {
        history.compactMap { entry -> Date? in
            guard entry.catalogVersion == configuration.catalogVersion,
                  entry.decisionPolicyVersion == configuration.decisionPolicyVersion else { return nil }
            let ids = (entry.completedExerciseIds ?? []) + (entry.references?.map(\.exerciseId) ?? [])
            guard ids.contains(where: { configuration.catalog[$0]?.resolvedMovementId == movementID }) else {
                return nil
            }
            return parseDate(entry.endedAt)
        }.max()
    }

    static func plannedRestSeconds(
        for exercise: V2ExerciseDefinition,
        history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> Int {
        let recent = history
            .filter {
                $0.catalogVersion == configuration.catalogVersion
                    && $0.decisionPolicyVersion == configuration.decisionPolicyVersion
            }
            .sorted { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }
            .flatMap { $0.restObservations ?? [] }
            .filter { $0.progressionContext == exercise.progressionContext }
            .prefix(3)
        guard recent.count == 3,
              recent.allSatisfy({ $0.actualSeconds >= max($0.plannedSeconds + 15, Int(Double($0.plannedSeconds) * 1.2)) }) else {
            return exercise.timingSeconds.rest
        }
        let sortedActual = recent.map(\.actualSeconds).sorted()
        let median = sortedActual[1]
        let rounded = Int((Double(median) / 15).rounded()) * 15
        return min(180, max(exercise.timingSeconds.rest, rounded))
    }

    static func orderedAnchors(
        history: [V2HistoryEntry],
        configuration: V2EngineConfiguration
    ) -> [String] {
        let knownAnchors = configuration.policy.anchorTieOrder
        let relevantHistory = history
            .filter {
                $0.catalogVersion == configuration.catalogVersion
                    && $0.decisionPolicyVersion == configuration.decisionPolicyVersion
                    && (!($0.completedExerciseIds ?? []).isEmpty || !($0.references ?? []).isEmpty)
            }
            .sorted { (parseDate($0.endedAt) ?? .distantPast) > (parseDate($1.endedAt) ?? .distantPast) }
            .prefix(configuration.policy.historyDepthCompletedSessions)
        var lastExposure: [String: Date] = [:]
        for entry in relevantHistory {
            guard let date = parseDate(entry.endedAt) else { continue }
            let ids = (entry.completedExerciseIds ?? []) + (entry.references?.map(\.exerciseId) ?? [])
            for id in ids {
                guard let anchor = configuration.catalog[id]?.anchor else { continue }
                lastExposure[anchor] = max(lastExposure[anchor] ?? .distantPast, date)
            }
        }
        let tieRanks = Dictionary(uniqueKeysWithValues: configuration.policy.anchorTieOrder.enumerated().map { ($1, $0) })
        return knownAnchors.sorted { left, right in
            let leftDate = lastExposure[left]
            let rightDate = lastExposure[right]
            switch (leftDate, rightDate) {
            case (nil, nil): return (tieRanks[left] ?? .max) < (tieRanks[right] ?? .max)
            case (nil, _): return true
            case (_, nil): return false
            case let (.some(l), .some(r)) where l != r: return l < r
            default: return (tieRanks[left] ?? .max) < (tieRanks[right] ?? .max)
            }
        }
    }

    static func exerciseIsAvailable(
        _ exercise: V2ExerciseDefinition,
        inventory: [V2InventoryItem],
        supports: [String],
        configuration: V2EngineConfiguration
    ) -> Bool {
        guard exercise.catalogStatus == "published_in_fixture_catalog",
              (!configuration.requiresProductApproval || exercise.productPublicationStatus == "approved_for_product"),
              exercise.supports.allSatisfy(Set(supports).contains) else { return false }
        let requirementsSatisfied = exercise.resolvedEquipmentAlternatives.contains { alternative in
            alternative.allSatisfy { requirement in
                inventory.contains { $0.category == requirement.category && $0.units >= requirement.units }
            }
        }
        guard requirementsSatisfied else { return false }
        if exercise.loadMode == .bodyweight { return true }
        if exercise.loadMode == .bandOption {
            return !availableOptions(for: exercise, inventory: inventory).isEmpty
        }
        return !availableWeights(for: exercise, inventory: inventory).isEmpty
    }

    static func isRefused(
        _ exerciseId: String,
        exercise: V2ExerciseDefinition,
        refusals: [V2Refusal]
    ) -> Bool {
        refusals.contains { refusal in
            guard refusal.exerciseId == exerciseId else { return false }
            return refusal.scope == "movement"
                || (refusal.scope == "configuration" && refusal.progressionContext == exercise.progressionContext)
        }
    }

    static func entryLoad(_ exercise: V2ExerciseDefinition, inventory: [V2InventoryItem]) -> V2Load? {
        guard exercise.loadMode != .bodyweight else { return nil }
        if exercise.loadMode == .bandOption {
            return availableOptions(for: exercise, inventory: inventory).first.map(V2Load.init(optionID:))
        }
        guard let first = availableWeights(for: exercise, inventory: inventory).first else { return nil }
        return V2Load(mode: exercise.loadMode, kg: first)
    }

    static func recalibrationLoad(
        _ exercise: V2ExerciseDefinition,
        reference: V2Reference?,
        inventory: [V2InventoryItem]
    ) -> V2Load? {
        guard exercise.loadMode != .bodyweight else { return nil }
        if exercise.loadMode == .bandOption {
            let options = availableOptions(for: exercise, inventory: inventory)
            guard let referenceOption = reference?.loadOptionID,
                  options.contains(referenceOption) else {
                return options.first.map(V2Load.init(optionID:))
            }
            let eligibleCategories = Set(exercise.resolvedEquipmentAlternatives.flatMap {
                $0.filter { $0.configuration == "band" }.map(\.category)
            })
            let matchingItems = inventory.filter {
                eligibleCategories.contains($0.category)
                    && $0.optionProgressionIsDeclared == true
                    && $0.resolvedOptionIDs.contains(referenceOption)
            }
            guard matchingItems.count == 1, let item = matchingItems.first,
                  let index = item.resolvedOptionIDs.firstIndex(of: referenceOption) else {
                return V2Load(optionID: referenceOption)
            }
            return V2Load(optionID: item.resolvedOptionIDs[max(0, index - 1)])
        }
        let weights = availableWeights(for: exercise, inventory: inventory)
        guard let referenceLoad = reference?.loadKg else {
            return weights.first.map { V2Load(mode: exercise.loadMode, kg: $0) }
        }
        let lower = weights.last(where: { $0 < referenceLoad }) ?? weights.first(where: { $0 == referenceLoad })
        return lower.map { V2Load(mode: exercise.loadMode, kg: $0) }
    }

    static func availableWeights(
        for exercise: V2ExerciseDefinition,
        inventory: [V2InventoryItem]
    ) -> [Double] {
        guard exercise.loadMode != .bodyweight, exercise.loadMode != .bandOption else { return [] }
        let expectedConfiguration = exercise.loadMode == .pairEachKg ? "pair" : "single"
        let loadRequirements = exercise.resolvedEquipmentAlternatives.compactMap { alternative in
            alternative.first {
                $0.configuration == expectedConfiguration
                    || (expectedConfiguration == "single" && $0.configuration == "central")
            } ?? alternative.first
        }
        guard !loadRequirements.isEmpty else { return [] }
        let qualifyingItems = inventory.filter { item in
            loadRequirements.contains { requirement in
                item.category == requirement.category && item.units >= requirement.units
            }
        }
        return stableUnique(
            qualifyingItems
                .flatMap(\.perUnitWeightsKg)
                .sorted()
        )
    }

    static func availableOptions(
        for exercise: V2ExerciseDefinition,
        inventory: [V2InventoryItem]
    ) -> [String] {
        guard exercise.loadMode == .bandOption else { return [] }
        let eligibleCategories = Set(exercise.resolvedEquipmentAlternatives.flatMap { alternative in
            alternative.filter { $0.configuration == "band" }.map(\.category)
        })
        return inventory
            .filter { eligibleCategories.contains($0.category) }
            .flatMap(\.resolvedOptionIDs)
            .reduce(into: [String]()) { result, option in
                if !result.contains(option) { result.append(option) }
            }
    }

    static func nextLoad(
        after current: V2Load?,
        for exercise: V2ExerciseDefinition,
        inventory: [V2InventoryItem]
    ) -> V2Load? {
        if exercise.loadMode == .bandOption {
            let eligibleCategories = Set(exercise.resolvedEquipmentAlternatives.flatMap {
                $0.filter { $0.configuration == "band" }.map(\.category)
            })
            guard let currentOption = current?.optionID else { return nil }
            let matchingItems = inventory.filter {
                eligibleCategories.contains($0.category)
                    && $0.optionProgressionIsDeclared == true
                    && $0.resolvedOptionIDs.contains(currentOption)
            }
            guard matchingItems.count == 1, let item = matchingItems.first,
                  let index = item.resolvedOptionIDs.firstIndex(of: currentOption),
                  item.resolvedOptionIDs.indices.contains(index + 1) else { return nil }
            return V2Load(optionID: item.resolvedOptionIDs[index + 1])
        }
        guard let currentKg = current?.kg,
              let nextKg = availableWeights(for: exercise, inventory: inventory)
                .first(where: { $0 > currentKg }) else { return nil }
        return V2Load(mode: exercise.loadMode, kg: nextKg)
    }

    static func load(from reference: V2Reference, mode: V2LoadMode) -> V2Load? {
        if mode == .bandOption {
            return reference.loadOptionID.map(V2Load.init(optionID:))
        }
        return reference.loadKg.map { V2Load(mode: mode, kg: $0) }
    }

    static func comparableLoad(
        exposureKg: Double?,
        exposureOptionID: String?,
        prescribed: V2Load?,
        mode: V2LoadMode
    ) -> Bool {
        switch mode {
        case .bodyweight:
            return exposureKg == nil && exposureOptionID == nil && prescribed == nil
        case .bandOption:
            return exposureOptionID == prescribed?.optionID
        case .singleTotalKg, .centralTotalKg, .pairEachKg:
            return exposureKg == prescribed?.kg
        }
    }

    static func plannedWorkIsCoherent(
        _ work: V2UnstartedWork,
        configuration: V2EngineConfiguration
    ) -> Bool {
        guard let exercise = configuration.catalog[work.exerciseId],
              work.sets >= 1,
              work.sets <= exercise.sets.max,
              (exercise.repRange.min...exercise.repRange.max).contains(work.targetReps),
              work.restSeconds >= exercise.timingSeconds.rest,
              work.restSeconds <= 180,
              work.progressionContext == exercise.progressionContext,
              !work.referenceStatus.isEmpty else { return false }
        if let source = work.sourceExerciseId, configuration.catalog[source] == nil { return false }
        if exercise.loadMode == .bodyweight { return work.load == nil }
        guard let load = work.load else { return false }
        if exercise.loadMode == .bandOption {
            return load.mode == .bandOption && !(load.optionID ?? "").isEmpty
        }
        return load.mode == exercise.loadMode && (load.kg ?? 0) > 0
    }

    static func plannedLoadIsUsable(
        _ load: V2Load?,
        for exercise: V2ExerciseDefinition,
        inventory: [V2InventoryItem]
    ) -> Bool {
        if exercise.loadMode == .bodyweight { return load == nil }
        guard let load, load.mode == exercise.loadMode else { return false }
        if exercise.loadMode == .bandOption {
            return load.optionID.map { availableOptions(for: exercise, inventory: inventory).contains($0) } ?? false
        }
        return load.kg.map { availableWeights(for: exercise, inventory: inventory).contains($0) } ?? false
    }

    static func inventoryIsCoherent(_ inventory: [V2InventoryItem]) -> Bool {
        inventory.allSatisfy { item in
            item.units > 0
                && item.perUnitWeightsKg.allSatisfy { $0 > 0 }
                && item.perUnitWeightsKg == item.perUnitWeightsKg.sorted()
                && item.resolvedOptionIDs.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                && Set(item.resolvedOptionIDs).count == item.resolvedOptionIDs.count
        }
    }

    static func inventoriesDiffer(_ persistent: [V2InventoryItem], _ today: [V2InventoryItem]) -> Bool {
        persistent != today
    }

    static func parseDate(_ value: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(
            includingFractionalSeconds: true
        ).parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }

    static func progressionDecision(
        _ decision: V2DecisionName,
        prescription: V2Prescription,
        configuration: V2EngineConfiguration,
        reasonCode: String
    ) -> V2ProgressionDecision {
        V2ProgressionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: decision,
            nextPrescription: V2Prescription(
                exerciseId: prescription.exerciseId,
                sets: prescription.sets,
                targetReps: prescription.targetReps,
                load: prescription.load,
                progressionContext: prescription.progressionContext
            ),
            reasons: [reason(reasonCode, scope: "configuration", source: "history", configuration: configuration)]
        )
    }

    static func sessionDecision(
        _ decision: V2DecisionName,
        mode: V2SessionMode,
        configuration: V2EngineConfiguration,
        reasons: [V2Reason]
    ) -> V2SessionDecision {
        V2SessionDecision(
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            decision: decision,
            mode: mode,
            reasons: reasons
        )
    }

    static func reason(
        _ code: String,
        scope: String,
        source: String,
        configuration: V2EngineConfiguration
    ) -> V2Reason {
        let messages: [String: String] = [
            "stale_unconfirmed_progression_held": "La progression proposée avant l’interruption n’a pas été exécutée ; les derniers repères confirmés sont conservés.",
            "invalid_duration": "La durée demandée n'est pas prise en charge.",
            "invalid_input": "Une donnée critique est illisible ou incohérente.",
            "active_session_version_incompatible": "La séance active utilise une version incompatible et ne peut pas être réinterprétée.",
            "safety_stop_session": "Un signal actuel déclaré arrête le moteur standard.",
            "standard_mode_outside_v2_scope": "Le moteur standard n'est pas proposé pour ce contexte déclaré.",
            "all_compatible_configurations_refused": "Toutes les configurations propres disponibles ont été refusées.",
            "no_compatible_force_configuration": "Aucune configuration de force propre ne tient dans les contraintes actuelles.",
            "equipment_temporarily_unavailable": "Le matériel habituel n'est pas disponible aujourd'hui.",
            "refusal_persistent": "Ce mouvement a été refusé durablement sur demande explicite.",
            "refusal_today": "Ce mouvement a été refusé pour aujourd'hui.",
            "recalibration_user_selected": "La personne a choisi de retrouver ses repères.",
            "partial_substitution_new_reference": "Le remplacement reste utile mais crée une nouvelle référence locale.",
            "progression_held_reference_to_reconfirm": "La prescription est conservée en attendant une nouvelle exposition comparable.",
            "anchor_omitted_no_compatible_movement": "Aucun mouvement propre et compatible ne couvre cet ancrage aujourd'hui.",
            "active_session_revalidated": "Le travail restant a été revalidé avec le contexte actuel.",
            "light_plan_unavailable": "Aucune réduction utile ne respecte le bloc minimal.",
            "light_mode_user_selected": "La personne a choisi une séance allégée.",
            "progression_held_no_comparable_reference": "La prescription est conservée faute d'exposition comparable admissible.",
            "progression_held_no_real_load_step": "La prescription est conservée faute de palier de charge réellement disponible.",
            "progression_repetitions_increased": "La cible augmente d'une répétition après une exposition comparable confirmée.",
            "progression_next_real_load": "Le prochain palier de charge réellement disponible est utilisé.",
            "time_budget_removed_unstarted_work": "Du travail non commencé a été retiré pour terminer dans le temps restant.",
            "safety_stop_movement": "Un signal déclaré pendant la séance arrête le mouvement en cours."
        ]
        return V2Reason(
            code: code,
            scope: scope,
            source: source,
            message: messages[code] ?? code,
            decisionPolicyVersion: configuration.decisionPolicyVersion
        )
    }

    static func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    static func stableUniqueReasons(_ values: [V2Reason]) -> [V2Reason] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.code).inserted }
    }
}
