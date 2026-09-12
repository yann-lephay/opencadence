import Foundation

public enum CadenceEngine {
    private static let patterns = ["pull", "push", "knee", "hinge"]
    private static let planPatternOrder = ["pull", "knee", "push", "hinge"]

    public static func generateNextWorkout(
        input: EngineInput,
        now: Date,
        catalog: EngineCatalog
    ) -> EngineDecision {
        guard [20, 30, 45].contains(input.durationMinutes) else {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["duration.unsupported"]
            )
            decision.errorCode = "duration.unsupported"
            decision.preserveInput = true
            return decision
        }

        guard !input.inventory.isEmpty else {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["equipment.inventory_empty"]
            )
            decision.errorCode = "equipment.inventory_empty"
            decision.preserveInput = true
            return decision
        }

        if input.inventory.contains(where: { $0.supportedConfigurations.contains("pair") && $0.units < 2 }) {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["equipment.pair_requires_two_units"]
            )
            decision.errorCode = "equipment.pair_requires_two_units"
            decision.preserveInput = true
            return decision
        }

        if input.history.contains(where: { date($0.endedAt).map { $0 > now } ?? true }) {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["history.session_in_future"]
            )
            decision.errorCode = "history.session_in_future"
            decision.preserveInput = true
            return decision
        }

        if let active = input.activeSession,
           active.checksumValid == false,
           let previous = input.previousValidSnapshot,
           previous.checksumValid == true,
           active.sessionId == previous.sessionId,
           let currentVersion = active.version,
           let previousVersion = previous.version,
           previousVersion < currentVersion {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["session.snapshot_corrupt"]
            )
            decision.errorCode = "session.snapshot_corrupt"
            decision.recovery = "restore_previous_valid_snapshot"
            decision.restoredVersion = previousVersion
            return decision
        }

        if input.physiologicalContext == "pregnancy" || input.physiologicalContext == "postpartum" {
            let suffix = input.physiologicalContext == "pregnancy" ? "pregnancy" : "postpartum"
            var decision = EngineDecision(
                decision: "block_standard_mode",
                reasonCodes: ["life_stage.\(suffix)_standard_mode_blocked"]
            )
            decision.blockReason = "life_stage.dedicated_mode_required"
            return decision
        }

        if let snapshot = input.activeSession, let event = input.sessionEvent {
            return reduceActiveSession(snapshot: snapshot, event: event, now: now)
        }

        if let snapshot = input.activeSession, let deadlineText = snapshot.restDeadline, let deadline = date(deadlineText) {
            let seconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
            let code = seconds == 0 ? "session.rest_elapsed_while_away" : "session.active_restored"
            var decision = EngineDecision(decision: "resume_active_session", reasonCodes: [code])
            decision.restTimer = RestTimerDecision(deadline: deadlineText, remainingSeconds: seconds)
            return decision
        }

        if let interrupted = optionalMakeup(input: input, now: now) {
            return interrupted
        }

        let readinessResult = readiness(input: input, now: now)
        let baseBudget = [20: 8, 30: 12, 45: 16][input.durationMinutes]!
        let selectedExercises = selectExercises(input: input, catalog: catalog)
        let compatible = Set(selectedExercises.keys)
        guard !compatible.isEmpty else {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: requestedExcludedExerciseKeys(input).isEmpty
                    ? ["catalog.no_compatible_exercise"]
                    : ["limitation.no_compatible_plan", "catalog.no_compatible_exercise"]
            )
            decision.errorCode = "catalog.no_compatible_exercise"
            decision.preserveInput = true
            decision.excludedExerciseKeys = requestedExcludedExerciseKeys(input)
            return decision
        }
        let capacity = 4 * compatible.count
        let finalBudget = min(max(4, Int((Double(baseBudget) * readinessResult.value.factor).rounded())), capacity)
        let rollingPriority = input.rollingState.map(rollingPriorityFirst)
        let plan = allocatePlan(
            selectedExercises: selectedExercises,
            budget: finalBudget,
            rollingState: input.rollingState
        )
        guard validPlan(plan, budget: finalBudget, input: input, catalog: catalog) else {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: requestedExcludedExerciseKeys(input).isEmpty
                    ? ["catalog.no_valid_plan"]
                    : ["limitation.no_compatible_plan", "catalog.no_valid_plan"]
            )
            decision.errorCode = "catalog.no_valid_plan"
            decision.preserveInput = true
            decision.excludedExerciseKeys = requestedExcludedExerciseKeys(input)
            return decision
        }
        let profileId = matchingProfileId(plan: plan, catalog: catalog)
        let rower = hardRowerDecision(input: input, now: now, factor: readinessResult.value.factor)

        var reasonCodes = readinessResult.reasonCodes
        reasonCodes.append(contentsOf: defaultReasonCodes(
            input: input,
            now: now,
            compatiblePatterns: compatible,
            readiness: readinessResult.value
        ))
        if input.symptomTracking.enabled, let score = input.symptomTracking.todayScore {
            if score >= 6 {
                reasonCodes.append("symptoms.high_declared")
            } else if score >= 3 {
                reasonCodes.append(contentsOf: ["symptoms.moderate_declared", "symptoms.first_movements_test"])
            }
        }

        if let rolling = input.rollingState, let priority = rollingPriority {
            reasonCodes.append(contentsOf: rollingReasonCodes(state: rolling, priority: priority))
        }
        reasonCodes.append(contentsOf: planReasonCodes(input: input, plan: plan, catalog: catalog))

        if rower.allowed {
            reasonCodes.append("rower.hard_finisher_eligible")
        } else if rower.blockedByRecentFinisher {
            reasonCodes.append("rower.hard_finisher_within_7_days")
        }

        if finalBudget < baseBudget && readinessResult.value.factor == 1 {
            reasonCodes.append("equipment.pattern_capacity_cap")
        }

        let progressionResult = progression(input: input).flatMap { result in
            plan.contains { $0.exerciseKey == result.value.exerciseKey } ? result : nil
        }
        if let progressionResult {
            reasonCodes.append(contentsOf: progressionResult.reasonCodes)
        }

        var decision = EngineDecision(
            decision: "generate_workout",
            reasonCodes: stableUnique(reasonCodes)
        )
        decision.readiness = readinessResult.value
        decision.basePrimarySetBudget = baseBudget
        decision.finalPrimarySetBudget = finalBudget
        decision.planProfileId = profileId
        decision.plan = plan
        decision.movements = plan.map { row in
            let exercise = catalog.exercises[row.exerciseKey]!
            return PrescribedMovement(
                exerciseKey: row.exerciseKey,
                variant: exercise.variant,
                pattern: exercise.pattern,
                sets: row.sets,
                target: exercise.target,
                restSeconds: exercise.restSeconds,
                equipment: exercise.equipment
            )
        }
        decision.recommendedLoads = loadRecommendations(input: input, plan: plan, catalog: catalog)
        decision.allowHardRower = rower.allowed
        decision.progression = progressionResult?.value
        decision.rollingPriorityFirst = rollingPriority
        decision.excludedExerciseKeys = requestedExcludedExerciseKeys(input)
        return decision
    }

    public static func reduceActiveSession(
        snapshot: ActiveSessionSnapshot,
        event: SessionEvent,
        now: Date
    ) -> EngineDecision {
        let completed = snapshot.completedSetCount ?? 0
        if snapshot.processedEventIds?.contains(event.eventId) == true {
            var decision = EngineDecision(
                decision: "active_session_transition",
                reasonCodes: ["session.duplicate_event_ignored"]
            )
            decision.transition = "duplicate_event_ignored"
            decision.completedSetCount = completed
            return decision
        }

        var decision = EngineDecision(decision: "active_session_transition", reasonCodes: [])
        decision.completedSetCount = completed
        switch event.type {
        case "pain_reported" where (3...4).contains(event.painScore ?? -1):
            decision.transition = "stop_current_set"
            decision.offeredActions = ["reduce_range", "substitute_exercise", "stop_exercise"]
            decision.reasonCodes = ["safety.pain_three_or_four"]
        case "pain_reported" where (event.painScore ?? -1) >= 5:
            decision.transition = "stop_current_exercise"
            decision.reasonCodes = ["safety.pain_five_or_more"]
        case "alert_reported" where !(event.redFlags ?? []).isEmpty:
            decision.transition = "stop_session_and_orient"
            decision.mustNotDiagnose = true
            decision.reasonCodes = ["safety.systemic_red_flag"]
        case "pause_rest":
            let remaining = snapshot.restDeadline
                .flatMap(date)
                .map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? 0
            decision.transition = "rest_paused"
            decision.pausedRemainingSeconds = remaining
            decision.restDeadline = nil
            decision.reasonCodes = ["session.rest_paused_explicitly"]
        case "resume_rest":
            let seconds = snapshot.pausedRemainingSeconds ?? 0
            decision.transition = "rest_resumed"
            decision.restDeadline = isoDate(now.addingTimeInterval(TimeInterval(seconds)))
            decision.pausedRemainingSeconds = nil
            decision.reasonCodes = ["session.rest_resumed_explicitly"]
        case "skip_rest":
            decision.transition = "rest_completed"
            decision.restDeadline = nil
            decision.reasonCodes = ["session.rest_skipped_explicitly"]
        case "restart_rest":
            let seconds = snapshot.originalRestSeconds ?? 0
            decision.transition = "rest_restarted"
            decision.restDeadline = isoDate(now.addingTimeInterval(TimeInterval(seconds)))
            decision.reasonCodes = ["session.rest_restarted_explicitly"]
        case "persistence_failed":
            decision.transition = "save_failed_visible"
            decision.inMemoryStatePreserved = true
            decision.canRetry = true
            decision.canExportRecovery = true
            decision.reasonCodes = ["persistence.write_failed_visible"]
        case "complete_set":
            decision.transition = "set_completed"
            decision.completedSetCount = completed + 1
            decision.reasonCodes = ["session.set_completed"]
        default:
            decision.transition = "event_ignored"
            decision.reasonCodes = ["session.event_unsupported"]
        }
        return decision
    }

    private static func optionalMakeup(input: EngineInput, now: Date) -> EngineDecision? {
        guard input.allowOptionalMakeup != false,
              let last = input.history.sorted(by: historyOrder).last,
              last.endedEarly == true,
              let painScore = last.painScore,
              painScore >= 0,
              painScore < 3,
              let endedAt = date(last.endedAt),
              now.timeIntervalSince(endedAt) >= 0,
              now.timeIntervalSince(endedAt) < 48 * 3_600,
              let skipped = last.skippedExerciseKeys,
              !skipped.isEmpty else { return nil }

        var decision = EngineDecision(
            decision: "generate_makeup",
            reasonCodes: ["session.optional_makeup_after_interruption"]
        )
        decision.allowHardRower = false
        decision.makeup = MakeupDecision(
            includedExerciseKeys: skipped,
            excludedExerciseKeys: last.completedExerciseKeys ?? [],
            includeConditioning: false,
            createsDebt: false
        )
        return decision
    }

    private static func readiness(input: EngineInput, now: Date) -> (value: Readiness, reasonCodes: [String]) {
        let sessions = input.history
            .filter { date($0.endedAt) != nil && $0.effort != nil && $0.painScore != nil }
            .sorted(by: historyOrder)
        var label = "green"
        var factor = 1.0
        var codes: [String] = []

        if let last = sessions.last, let endedAt = date(last.endedAt) {
            let recent = sessions.suffix(3)
            let repeatedHigh = recent.filter { ($0.effort ?? 0) >= 9 }.count >= 2
            let hours = now.timeIntervalSince(endedAt) / 3_600
            let days = hours / 24

            if (last.painScore ?? 0) >= 5 {
                label = "technical"; factor = 0.55
                codes = ["readiness.previous_pain_five", "safety.stop_if_pain_persists"]
            } else if repeatedHigh {
                label = "reduced"; factor = 0.65
                codes = ["readiness.repeated_high_effort"]
            } else if hours < 24 {
                label = "technical"; factor = 0.55
                codes = ["readiness.less_than_24_hours"]
            } else if hours < 48, (last.effort ?? 0) >= 8 {
                label = "reduced"; factor = 0.75
                codes = ["readiness.less_than_48_hours_after_high_effort"]
            } else if days > 14 {
                label = "recalibration"; factor = 0.60
                codes = ["readiness.return_over_14_days"]
            } else if days >= 8 {
                label = "return"; factor = 0.75
                codes = ["readiness.return_8_to_14_days"]
            } else if (last.effort ?? 0) >= 9 {
                label = "reduced"; factor = 0.75
                codes = ["readiness.isolated_effort_nine"]
            } else if (last.painScore ?? 0) >= 3 {
                label = "reduced"; factor = 0.75
                codes = ["readiness.previous_pain_three_or_four"]
            }
        }

        if input.symptomTracking.enabled, (input.symptomTracking.todayScore ?? 0) >= 6 {
            factor = min(factor, 0.65)
            label = "reduced"
        } else if input.symptomTracking.enabled, (input.symptomTracking.todayScore ?? 0) >= 3, factor == 1 {
            label = "green_test_start"
        }

        return (Readiness(label: label, factor: factor, rirTarget: factor == 1 ? "2-3" : "3-4"), codes)
    }

    private static func progression(input: EngineInput) -> (value: Progression, reasonCodes: [String])? {
        guard input.history.sorted(by: historyOrder).last?.painScore ?? 0 < 5 else { return nil }
        let records = input.history
            .sorted(by: historyOrder)
            .flatMap { session in (session.exerciseRecords ?? []).map { (session, $0) } }
        let comparableRecords = records.filter {
            $0.1.perUnitWeightKg != nil
                && $0.1.completedReps != nil
                && $0.1.topRangeReps != nil
                && $0.1.lastSetRir != nil
        }
        guard let lastPair = comparableRecords.last,
              let weight = lastPair.1.perUnitWeightKg,
              let completed = lastPair.1.completedReps,
              let top = lastPair.1.topRangeReps,
              let rir = lastPair.1.lastSetRir,
              (lastPair.0.effort ?? 10) <= 8,
              (lastPair.0.painScore ?? 10) <= 2,
              rir >= 2 else { return nil }

        let exerciseKey = lastPair.1.exerciseKey
        if completed < top {
            return (
                Progression(
                    exerciseKey: exerciseKey,
                    action: "increase_reps",
                    perUnitWeightKg: weight,
                    repsDelta: 1,
                    variablesChanged: ["reps"]
                ),
                ["progression.reps_first"]
            )
        }

        let cleanAtCeiling = comparableRecords
            .filter { pair in
                pair.1.exerciseKey == exerciseKey
                    && pair.1.perUnitWeightKg == weight
                    && pair.1.completedReps == pair.1.topRangeReps
                    && (pair.0.effort ?? 10) <= 8
                    && (pair.0.painScore ?? 10) <= 2
                    && (pair.1.lastSetRir ?? -1) >= 2
            }
        guard cleanAtCeiling.count >= 2 else { return nil }

        let weights = input.inventory
            .flatMap { item -> [Double] in
                if item.category == "adjustable_dumbbell" { return item.perUnitWeightsKg ?? [] }
                if item.category == "fixed_dumbbell", let fixed = item.weightKg { return [fixed] }
                return []
            }
            .sorted()
        if let next = weights.first(where: { $0 > weight }) {
            return (
                Progression(
                    exerciseKey: exerciseKey,
                    action: "increase_load",
                    perUnitWeightKg: next,
                    repsDelta: -4,
                    variablesChanged: ["load", "reps_reset"]
                ),
                ["progression.two_clean_ceiling_sessions", "progression.next_available_load"]
            )
        }
        return (
            Progression(
                exerciseKey: exerciseKey,
                action: "hold_load",
                perUnitWeightKg: weight,
                repsDelta: 0,
                variablesChanged: []
            ),
            ["progression.no_higher_available"]
        )
    }

    private static func selectExercises(
        input: EngineInput,
        catalog: EngineCatalog
    ) -> [String: String] {
        let excluded = effectiveExcludedExerciseKeys(input: input, catalog: catalog)
        let categories = Set(input.inventory.map(\.category))
        let splitCalibration = input.calibrations.map { $0.upper != $0.lower } ?? false
        let applyCalibration = input.calibrationIsExplicit == true || splitCalibration

        var result: [String: String] = [:]
        for pattern in patterns {
            let wantedBand = ["pull", "push"].contains(pattern)
                ? input.calibrations?.upper
                : input.calibrations?.lower
            let candidates = catalog.exercises
                .filter { key, exercise in
                    exercise.pattern == pattern
                        && !excluded.contains(key)
                        && exercise.equipment.allSatisfy { requirement in
                            input.inventory.contains { item in
                                item.category == requirement.category
                                    && item.supports(requirement.configuration)
                            }
                        }
                }
                .sorted { left, right in
                    let leftScore = exerciseSelectionScore(
                        exercise: left.value,
                        pattern: pattern,
                        wantedBand: wantedBand,
                        applyCalibration: applyCalibration,
                        categories: categories
                    )
                    let rightScore = exerciseSelectionScore(
                        exercise: right.value,
                        pattern: pattern,
                        wantedBand: wantedBand,
                        applyCalibration: applyCalibration,
                        categories: categories
                    )
                    if leftScore != rightScore { return leftScore > rightScore }
                    return left.key < right.key
                }
            if let selected = candidates.first { result[pattern] = selected.key }
        }
        return result
    }

    private static func exerciseSelectionScore(
        exercise: ExerciseDefinition,
        pattern: String,
        wantedBand: String?,
        applyCalibration: Bool,
        categories: Set<String>
    ) -> Int {
        var score = 0
        if applyCalibration {
            score += effectiveCalibrationBand(for: exercise, pattern: pattern) == wantedBand ? 100 : 0
        } else {
            score += exercise.calibrationBand == nil ? 20 : 0
        }

        let equipmentCategories = Set(exercise.equipment.map(\.category))
        if equipmentCategories.contains("adjustable_dumbbell") { score += 12 }
        if equipmentCategories.contains("fixed_dumbbell") { score += 10 }
        if equipmentCategories.contains("pullup_bar") { score += 8 }
        if equipmentCategories == ["bodyweight"] { score += 4 }

        let foundationPushAtHome = pattern == "push"
            && wantedBand == "foundation"
            && categories.contains("bodyweight")
            && categories.contains("adjustable_dumbbell")
        if foundationPushAtHome && equipmentCategories == ["bodyweight"] { score += 20 }
        return score
    }

    private static func effectiveCalibrationBand(
        for exercise: ExerciseDefinition,
        pattern: String
    ) -> String? {
        if let calibrationBand = exercise.calibrationBand { return calibrationBand }
        guard exercise.equipment.contains(where: { $0.category == "adjustable_dumbbell" }) else {
            return nil
        }
        return ["pull", "push"].contains(pattern) ? "established" : "foundation"
    }

    private static func allocatePlan(
        selectedExercises: [String: String],
        budget: Int,
        rollingState: RollingState?
    ) -> [PlanRow] {
        var sets = Dictionary(uniqueKeysWithValues: selectedExercises.keys.map { ($0, 0) })
        var credits7 = Dictionary(uniqueKeysWithValues: patterns.map { ($0, rollingState?.credits7[$0] ?? 0) })
        var credits21 = Dictionary(uniqueKeysWithValues: patterns.map { ($0, rollingState?.credits21[$0] ?? 0) })

        for _ in 0..<budget {
            let eligible = patterns.filter { selectedExercises[$0] != nil && (sets[$0] ?? 0) < 4 }
            guard !eligible.isEmpty else { break }
            let next: String
            let minimum = eligible.map { sets[$0] ?? 0 }.min() ?? 0
            let leastAllocated = eligible.filter { sets[$0] == minimum }
            let isBaseAllocation = minimum < 2
            if isBaseAllocation || rollingState == nil {
                next = leastAllocated.first ?? eligible[0]
            } else {
                next = rollingPriorityFirst(
                    rollingState!,
                    credits7: credits7,
                    credits21: credits21,
                    eligible: Set(eligible)
                )
            }
            sets[next, default: 0] += 1
            if !isBaseAllocation {
                credits7[next, default: 0] += 1
                credits21[next, default: 0] += 1
            }
        }

        let outputOrder = selectedExercises["pull"] == nil
            ? ["push", "knee", "hinge"]
            : planPatternOrder
        return outputOrder.compactMap { pattern in
            guard let key = selectedExercises[pattern], let count = sets[pattern], count > 0 else { return nil }
            return PlanRow(exerciseKey: key, sets: count)
        }
    }

    private static func matchingProfileId(plan: [PlanRow], catalog: EngineCatalog) -> String? {
        catalog.planProfiles.keys.sorted().first { catalog.planProfiles[$0] == plan }
    }

    private static func validPlan(
        _ plan: [PlanRow],
        budget: Int,
        input: EngineInput,
        catalog: EngineCatalog
    ) -> Bool {
        let excluded = effectiveExcludedExerciseKeys(input: input, catalog: catalog)
        guard !plan.isEmpty, plan.reduce(0, { $0 + $1.sets }) == budget else { return false }
        return plan.allSatisfy { row in
            guard (1...4).contains(row.sets),
                  !excluded.contains(row.exerciseKey),
                  let exercise = catalog.exercises[row.exerciseKey] else { return false }
            return exercise.equipment.allSatisfy { requirement in
                input.inventory.contains { item in
                    item.category == requirement.category && item.supports(requirement.configuration)
                }
            }
        }
    }

    private static func planReasonCodes(
        input: EngineInput,
        plan: [PlanRow],
        catalog: EngineCatalog
    ) -> [String] {
        let keys = Set(plan.map(\.exerciseKey))
        let excluded = requestedExcludedExerciseKeys(input)
        var codes: [String] = []
        if input.calibrationIsExplicit == true {
            codes.append("calibration.user_selected_variants")
        }
        if input.calibrations?.upper != input.calibrations?.lower {
            codes.append("calibration.upper_lower_independent")
        }
        if !excluded.isEmpty { codes.append("limitation.user_excluded_movement") }
        let declaredWristLimitation = (input.limitations ?? []).contains {
            $0.id == "avoid_loaded_wrist_extension"
                && $0.excludedExerciseKeys.contains("incline_pushup")
        }
        if declaredWristLimitation, keys.contains("floor_press") {
            codes.append("limitation.push_variant_substituted")
        }
        let categories = Set(input.inventory.map(\.category))
        if excluded.isEmpty,
           categories.contains("bodyweight"),
           categories.contains("adjustable_dumbbell"),
           keys.contains("incline_pushup") {
            codes.append("calibration.no_limitation_substitution")
        }
        return codes
    }

    private static func requestedExcludedExerciseKeys(_ input: EngineInput) -> [String] {
        Array(Set((input.limitations ?? []).flatMap(\.excludedExerciseKeys))).sorted()
    }

    private static func effectiveExcludedExerciseKeys(
        input: EngineInput,
        catalog: EngineCatalog
    ) -> Set<String> {
        let requested = Set(requestedExcludedExerciseKeys(input))
        let variants = Set(requested.compactMap { catalog.exercises[$0]?.variant })
        let equivalent = catalog.exercises.compactMap { key, exercise in
            variants.contains(exercise.variant) ? key : nil
        }
        return requested.union(equivalent)
    }

    private static func defaultReasonCodes(
        input: EngineInput,
        now: Date,
        compatiblePatterns: Set<String>,
        readiness: Readiness
    ) -> [String] {
        var codes: [String] = []
        if readiness.factor == 1,
           let last = input.history.sorted(by: historyOrder).last,
           let endedAt = date(last.endedAt) {
            let hours = now.timeIntervalSince(endedAt) / 3_600
            if abs(hours - 24) < 0.000_1 { codes.append("readiness.green_at_24_hour_boundary") }
            if (last.effort ?? 0) >= 8, abs(hours - 48) < 0.000_1 {
                codes.append("readiness.green_at_48_hour_boundary")
            }
        }
        if !compatiblePatterns.contains("pull") {
            codes.append("equipment.no_supported_pull")
        } else {
            codes.append("session.full_body_anchors_supported")
        }
        return codes
    }

    private static func rollingPriorityFirst(_ state: RollingState) -> String {
        rollingPriorityFirst(
            state,
            credits7: Dictionary(uniqueKeysWithValues: patterns.map { ($0, state.credits7[$0]) }),
            credits21: Dictionary(uniqueKeysWithValues: patterns.map { ($0, state.credits21[$0]) }),
            eligible: Set(patterns)
        )
    }

    private static func rollingPriorityFirst(
        _ state: RollingState,
        credits7: [String: Double],
        credits21: [String: Double],
        eligible: Set<String>
    ) -> String {
        patterns.filter(eligible.contains).sorted { left, right in
            let lhs = rollingTuple(state, left, credits7: credits7, credits21: credits21)
            let rhs = rollingTuple(state, right, credits7: credits7, credits21: credits21)
            for index in lhs.indices where lhs[index] != rhs[index] {
                return lhs[index] > rhs[index]
            }
            return false
        }.first ?? "pull"
    }

    private static func rollingTuple(
        _ state: RollingState,
        _ pattern: String,
        credits7: [String: Double]? = nil,
        credits21: [String: Double]? = nil
    ) -> [Double] {
        let target7 = state.targets7[pattern]
        let target21 = state.targets21[pattern]
        let current7 = credits7?[pattern] ?? state.credits7[pattern]
        let current21 = credits21?[pattern] ?? state.credits21[pattern]
        return [
            max(0, target7 - current7) / target7,
            max(0, target21 - current21) / target21,
            state.profilePriorities[pattern],
            state.daysSinceExposure[pattern],
            -Double(patterns.firstIndex(of: pattern) ?? 0),
        ]
    }

    private static func rollingReasonCodes(state: RollingState, priority: String) -> [String] {
        let reference = Array(rollingTuple(state, "pull").prefix(4))
        let allTied = patterns.dropFirst().allSatisfy {
            Array(rollingTuple(state, $0).prefix(4)) == reference
        }
        if allTied { return ["rolling.stable_tie_break_pull_first"] }
        if priority == "push", state.credits21.pull < state.targets21.pull {
            return ["rolling.push_deficit_7d_precedes_pull_deficit_21d"]
        }
        return ["rolling.pull_underexposed_7d", "rolling.variants_kept_stable"]
    }

    private static func hardRowerDecision(
        input: EngineInput,
        now: Date,
        factor: Double
    ) -> (allowed: Bool, blockedByRecentFinisher: Bool) {
        guard input.durationMinutes == 45,
              factor == 1,
              input.inventory.contains(where: { $0.category == "rower" }),
              !(input.symptomTracking.enabled && (input.symptomTracking.todayScore ?? 0) >= 3)
        else { return (false, false) }

        let recent = input.history.contains { session in
            guard session.hardRowerFinisher == true, let endedAt = date(session.endedAt) else { return false }
            let hours = now.timeIntervalSince(endedAt) / 3_600
            return hours >= 0 && hours < 168
        }
        return (!recent, recent)
    }

    private static func loadRecommendations(
        input: EngineInput,
        plan: [PlanRow],
        catalog: EngineCatalog
    ) -> [LoadRecommendation] {
        let requirements = plan.flatMap { catalog.exercises[$0.exerciseKey]?.equipment ?? [] }
        guard requirements.contains(where: { $0.category == "fixed_dumbbell" && $0.configuration == "pair" }),
              let item = input.inventory.first(where: { $0.category == "fixed_dumbbell" }),
              let weight = item.weightKg,
              item.supports("pair") else { return [] }
        return [LoadRecommendation(
            category: "fixed_dumbbell",
            configuration: "pair",
            perUnitWeightKg: weight
        )]
    }

    private static func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func historyOrder(_ left: HistorySession, _ right: HistorySession) -> Bool {
        (date(left.endedAt) ?? .distantPast) < (date(right.endedAt) ?? .distantPast)
    }

    private static func date(_ value: String) -> Date? {
        makeISOFormatter().date(from: value)
    }

    private static func isoDate(_ value: Date) -> String {
        makeISOFormatter().string(from: value)
    }

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
