import CadenceEngine
import Foundation

enum WorkoutEngineVersion: Equatable {
    case productionV1
    case previewV2
    case releaseV2
}

enum WorkoutEngineRuntime {
    static func selectedVersion(arguments: [String] = ProcessInfo.processInfo.arguments) -> WorkoutEngineVersion {
#if DEBUG
        arguments.contains("-OpenCadenceForceV1") ? .productionV1 : .previewV2
#else
        .releaseV2
#endif
    }
}

// Kept only so historical unit tests can express the former V1 assumptions.
// The product flow no longer injects these values and reads UserSupportProfile.
enum WorkoutSupportProfile {
    static let internalV1Assumptions = [
        "wall_or_stable_plane",
        "floor_allowed",
        "stable_hand_support",
    ]
}

enum WorkoutEngineBridge {
    static func prepareWorkout(
        inventory: [EquipmentItem],
        todayInventory: [EquipmentItem]? = nil,
        durationMinutes: Int,
        completedWorkouts: [CompletedWorkoutRecord] = [],
        historyEvidenceSource: V2HistoryEvidenceSource = .nativeConfirmed,
        calibrations: Calibrations? = nil,
        calibrationIsExplicit: Bool = false,
        limitations: [Limitation] = [],
        persistentRefusals: [String] = [],
        allowOptionalMakeup: Bool = true,
        engineVersion: WorkoutEngineVersion,
        todaySupports: [String],
        previewMode: V2SessionMode = .normal,
        declaredCurrentHealthSignal: Bool = false,
        declaredScope: V2DeclaredScope? = nil,
        person: V2Personalization? = nil,
        now: Date = .now
    ) -> PreparedWorkout {
        guard engineVersion != .productionV1 else {
            return PreparedWorkout(
                decision: nextWorkout(
                    inventory: inventory,
                    durationMinutes: durationMinutes,
                    completedWorkouts: completedWorkouts,
                    calibrations: calibrations,
                    calibrationIsExplicit: calibrationIsExplicit,
                    limitations: limitations,
                    allowOptionalMakeup: allowOptionalMakeup,
                    engineVersion: .productionV1,
                    now: now
                ),
                v2Context: nil
            )
        }

        if engineVersion == .releaseV2, !MovementMediaManifest.releaseIsComplete {
            var decision = EngineDecision(
                decision: "request_valid_input",
                reasonCodes: ["release.movement_media_incomplete"]
            )
            decision.errorCode = "v2.movement_media_incomplete"
            decision.preserveInput = true
            return PreparedWorkout(decision: decision, v2Context: nil)
        }

        let payloads = completedWorkouts
            .compactMap(\.payload)
            .sorted { $0.endedAt < $1.endedAt }
        let history = migratedV2History(from: payloads, source: historyEvidenceSource)
        let effectiveTodayInventory = todayInventory ?? inventory
        let configuration: V2EngineConfiguration = engineVersion == .releaseV2
            ? .releaseV2
            : .productPreview
        let personalized = person.map { person in
            NativePersonalization.prepare(person: person, inventory: previewInventory(from: inventory, configuration: configuration),
                todayInventory: previewInventory(from: effectiveTodayInventory, configuration: configuration),
                supports: todaySupports, history: history, limitations: limitations, refusals: persistentRefusals,
                mode: previewMode, healthSignal: declaredCurrentHealthSignal, scope: declaredScope,
                configuration: configuration, source: historyEvidenceSource, now: now)
        }
        let session = personalized?.decision ?? nextWorkoutV2Preview(
            persistentInventory: inventory,
            todayInventory: effectiveTodayInventory,
            durationMinutes: durationMinutes,
            history: history,
            limitations: limitations,
            persistentRefusals: persistentRefusals,
            todaySupports: todaySupports,
            mode: previewMode,
            declaredCurrentHealthSignal: declaredCurrentHealthSignal,
            declaredScope: declaredScope,
            configuration: configuration,
            now: now
        )
        let hasLegacyHistory = payloads.contains {
            $0.snapshot.v2Context == nil && !($0.historySession.completedExerciseKeys ?? []).isEmpty
        }
        let decision = legacyDecision(
            from: session,
            limitations: limitations,
            migratedHistory: hasLegacyHistory,
            configuration: configuration
        )
        var context: ActiveWorkoutV2Context?
        if session.decision == .generateSession, !session.plan.isEmpty {
            context = ActiveWorkoutV2Context(
                catalogVersion: session.catalogVersion,
                decisionPolicyVersion: session.decisionPolicyVersion,
                mode: session.mode,
                durationMinutes: durationMinutes,
                estimatedSeconds: session.estimatedSeconds,
                plan: session.plan,
                inventory: previewInventory(from: effectiveTodayInventory, configuration: configuration),
                supports: todaySupports
            )
        } else {
            context = nil
        }
        if let personalized, let person {
            context?.personalization = NativePersonalizationContext(person: person, result: personalized, refusals: persistentRefusals + limitations.flatMap(\.excludedExerciseKeys), releaseConfiguration: engineVersion == .releaseV2)
        }
        return PreparedWorkout(decision: decision, v2Context: context, personalizationResult: personalized)
    }

    static func nextWorkout(
        inventory: [EquipmentItem],
        durationMinutes: Int,
        completedWorkouts: [CompletedWorkoutRecord] = [],
        calibrations: Calibrations? = nil,
        calibrationIsExplicit: Bool = false,
        limitations: [Limitation] = [],
        persistentRefusals: [String] = [],
        allowOptionalMakeup: Bool = true,
        engineVersion: WorkoutEngineVersion = .productionV1,
        todaySupports: [String] = [],
        previewMode: V2SessionMode = .normal,
        now: Date = .now
    ) -> EngineDecision {
        if engineVersion != .productionV1 {
            return prepareWorkout(
                inventory: inventory,
                durationMinutes: durationMinutes,
                completedWorkouts: completedWorkouts,
                calibrations: calibrations,
                calibrationIsExplicit: calibrationIsExplicit,
                limitations: limitations,
                persistentRefusals: persistentRefusals,
                allowOptionalMakeup: allowOptionalMakeup,
                engineVersion: engineVersion,
                todaySupports: todaySupports,
                previewMode: previewMode,
                now: now
            ).decision
        }
        let payloads = completedWorkouts
            .compactMap(\.payload)
            .sorted { $0.endedAt < $1.endedAt }
        return CadenceEngine.generateNextWorkout(
            input: EngineInput(
                durationMinutes: durationMinutes,
                inventory: inventory,
                history: payloads.map(\.historySession),
                calibrations: calibrations,
                calibrationIsExplicit: calibrationIsExplicit,
                limitations: limitations,
                rollingState: rollingState(from: payloads, now: now),
                allowOptionalMakeup: allowOptionalMakeup
            ),
            now: now,
            catalog: .referenceV1
        )
    }

    static func nextWorkoutV2Preview(
        persistentInventory: [EquipmentItem],
        todayInventory: [EquipmentItem]? = nil,
        durationMinutes: Int,
        history: [V2HistoryEntry] = [],
        limitations: [Limitation] = [],
        persistentRefusals: [String] = [],
        todaySupports: [String],
        mode: V2SessionMode = .normal,
        declaredCurrentHealthSignal: Bool = false,
        declaredScope: V2DeclaredScope? = nil,
        configuration: V2EngineConfiguration = .productPreview,
        now: Date = .now
    ) -> V2SessionDecision {
        let persistentV2Inventory = previewInventory(from: persistentInventory, configuration: configuration)
        let todayV2Inventory = previewInventory(
            from: todayInventory ?? persistentInventory,
            configuration: configuration
        )
        let todayRefusals = limitations.flatMap { limitation in
            limitation.excludedExerciseKeys.compactMap { exerciseID -> V2Refusal? in
                guard configuration.catalog[exerciseID] != nil else { return nil }
                return V2Refusal(
                    scope: "movement",
                    temporalScope: "today",
                    exerciseId: exerciseID
                )
            }
        }
        let durableRefusals = persistentRefusals.compactMap { exerciseID -> V2Refusal? in
            guard let exercise = configuration.catalog[exerciseID] else { return nil }
            return V2Refusal(
                scope: "configuration",
                temporalScope: "persistent",
                exerciseId: exerciseID,
                progressionContext: exercise.progressionContext
            )
        }
        let input = V2SessionDecisionInput(
            request: V2SessionRequest(durationMinutes: durationMinutes, mode: mode),
            persistentInventory: persistentV2Inventory,
            todayInventory: todayV2Inventory,
            todaySupports: todaySupports,
            history: history,
            refusals: todayRefusals + durableRefusals,
            declaredCurrentHealthSignal: declaredCurrentHealthSignal,
            declaredScope: declaredScope
        )
        let result = CadenceEngine.decideV2(
            request: .sessionDecision(input, now: now),
            configuration: configuration
        )
        guard case let .sessionDecision(decision) = result else {
            return V2SessionDecision(
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                decision: .requestValidInput,
                mode: mode,
                reasons: [
                    V2Reason(
                        code: "invalid_bridge_result",
                        scope: "session",
                        source: "product_scope",
                        message: "Le bridge attendait une décision de séance V2.",
                        decisionPolicyVersion: configuration.decisionPolicyVersion
                    )
                ]
            )
        }
        return decision
    }

    private static func rollingState(
        from payloads: [CompletedWorkoutPayload],
        now: Date
    ) -> RollingState? {
        let results = payloads.flatMap { $0.snapshot.recordedSets }
        guard !results.isEmpty else { return nil }
        let patterns = ["pull", "push", "knee", "hinge"]
        var credits7 = Dictionary(uniqueKeysWithValues: patterns.map { ($0, 0.0) })
        var credits21 = credits7
        var lastExposure: [String: Date] = [:]

        for result in results {
            guard let pattern = EngineCatalog.referenceV1.exercises[result.exerciseKey]?.pattern else { continue }
            let age = now.timeIntervalSince(result.completedAt)
            guard age >= 0 else { continue }
            if age <= 7 * 86_400 { credits7[pattern, default: 0] += 1 }
            if age <= 21 * 86_400 { credits21[pattern, default: 0] += 1 }
            if result.completedAt > (lastExposure[pattern] ?? .distantPast) {
                lastExposure[pattern] = result.completedAt
            }
        }

        let daysSince = Dictionary(uniqueKeysWithValues: patterns.map { pattern in
            let days = lastExposure[pattern].map { now.timeIntervalSince($0) / 86_400 } ?? 365
            return (pattern, max(0, days))
        })
        return RollingState(
            credits7: values(credits7),
            credits21: values(credits21),
            targets7: PatternValues(pull: 4, push: 4, knee: 4, hinge: 4),
            targets21: PatternValues(pull: 12, push: 12, knee: 12, hinge: 12),
            profilePriorities: PatternValues(pull: 1, push: 1, knee: 1, hinge: 1),
            daysSinceExposure: values(daysSince)
        )
    }

    private static func values(_ dictionary: [String: Double]) -> PatternValues {
        PatternValues(
            pull: dictionary["pull", default: 0],
            push: dictionary["push", default: 0],
            knee: dictionary["knee", default: 0],
            hinge: dictionary["hinge", default: 0]
        )
    }

    static func migratedV2History(
        from payloads: [CompletedWorkoutPayload],
        source: V2HistoryEvidenceSource = .nativeConfirmed
    ) -> [V2HistoryEntry] {
        let configuration = V2EngineConfiguration.productPreview
        var exposuresByContext: [String: [V2Exposure]] = [:]
        return payloads.sorted { $0.endedAt < $1.endedAt }.compactMap { payload in
            if let context = payload.snapshot.v2Context {
                let evidence = context.plan.compactMap { item -> V2ConfirmedWorkEvidence? in
                    let results = payload.snapshot.recordedSets.filter { $0.exerciseKey == item.exerciseId }
                    guard !results.isEmpty else { return nil }
                    return V2ConfirmedWorkEvidence(
                        exerciseId: item.exerciseId, progressionContext: item.progressionContext,
                        plannedSets: context.personalization?.prescribedSets[item.exerciseId] ?? item.sets, targetUnit: item.resolvedTargetUnit,
                        confirmedSets: results.map { result in
                            V2ConfirmedSetEvidence(eventID: result.eventID, repetitions: result.repetitions,
                                loadKg: result.perUnitWeightKg, loadOptionID: result.loadOptionID,
                                completedAt: result.completedAt.ISO8601Format(), prescribedRepetitions: result.prescribedRepetitions)
                        },
                        wasSkipped: payload.snapshot.skippedExerciseKeys.contains(item.exerciseId),
                        interruptedBySafetySignal: payload.snapshot.recordedSafetyEvents.contains { $0.exerciseKey == item.exerciseId },
                        source: source)
                }
                guard context.catalogVersion == configuration.catalogVersion,
                      context.decisionPolicyVersion == configuration.decisionPolicyVersion else {
                    guard !evidence.isEmpty else { return nil }
                    let recordedRests = context.plan.flatMap { item in
                        payload.snapshot.recordedSets.filter { $0.exerciseKey == item.exerciseId }.compactMap { result -> V2RestObservation? in
                            guard let planned = result.plannedRestSeconds, let actual = result.actualRestSeconds else { return nil }
                            return V2RestObservation(progressionContext: item.progressionContext, plannedSeconds: planned, actualSeconds: actual)
                        }
                    }
                    return V2HistoryEntry(endedAt: payload.endedAt.ISO8601Format(),
                        restObservations: recordedRests.isEmpty ? nil : recordedRests,
                        confirmedWorkEvidence: evidence, catalogVersion: context.catalogVersion,
                        decisionPolicyVersion: context.decisionPolicyVersion)
                }
                var completedExerciseIDs: [String] = []
                var references: [V2Reference] = []
                var restObservations: [V2RestObservation] = []

                for item in context.plan {
                    let results = payload.snapshot.recordedSets
                        .filter { $0.exerciseKey == item.exerciseId }
                        .prefix(item.sets)
                    guard !results.isEmpty else { continue }
                    let allSetsRecorded = results.count == (context.personalization?.prescribedSets[item.exerciseId] ?? item.sets)
                    let wasSkipped = payload.snapshot.skippedExerciseKeys.contains(item.exerciseId)
                    if allSetsRecorded && !wasSkipped {
                        completedExerciseIDs.append(item.exerciseId)
                    }
                    let loadIsComparable: Bool
                    if let prescribedLoad = item.load?.kg {
                        loadIsComparable = results.allSatisfy {
                            $0.perUnitWeightKg.map { abs($0 - prescribedLoad) < 0.000_1 } == true
                        }
                    } else if let prescribedOption = item.load?.optionID {
                        loadIsComparable = results.allSatisfy { $0.loadOptionID == prescribedOption }
                    } else {
                        loadIsComparable = results.allSatisfy {
                            $0.perUnitWeightKg == nil && $0.loadOptionID == nil
                        }
                    }

                    let interruptedBySafetySignal = payload.snapshot.recordedSafetyEvents.contains {
                        $0.exerciseKey == item.exerciseId
                    }
                    restObservations += results.compactMap { result in
                        guard let planned = result.plannedRestSeconds,
                              let actual = result.actualRestSeconds else { return nil }
                        return V2RestObservation(
                            progressionContext: item.progressionContext,
                            plannedSeconds: planned,
                            actualSeconds: actual
                        )
                    }
                    let exposure = V2Exposure(
                        confirmedReps: results.map(\.repetitions),
                        loadKg: results.last?.perUnitWeightKg,
                        loadOptionID: results.last?.loadOptionID,
                        allPrescribedSetsConfirmed: allSetsRecorded && loadIsComparable && !wasSkipped,
                        progressionContext: item.progressionContext,
                        catalogVersion: context.catalogVersion,
                        decisionPolicyVersion: context.decisionPolicyVersion,
                        interruptedBySafetySignal: interruptedBySafetySignal
                    )
                    exposuresByContext[item.progressionContext, default: []].append(exposure)
                    guard allSetsRecorded && loadIsComparable && !wasSkipped && !interruptedBySafetySignal else { continue }

                    let previous = V2Prescription(
                        exerciseId: item.exerciseId,
                        sets: item.sets,
                        targetReps: item.targetReps,
                        load: item.load,
                        progressionContext: item.progressionContext,
                        catalogVersion: context.catalogVersion,
                        decisionPolicyVersion: context.decisionPolicyVersion
                    )
                    let result = CadenceEngine.decideV2(
                        request: .progressionTransition(
                            V2ProgressionInput(
                                todayInventory: context.inventory,
                                previousPrescription: previous,
                                exposures: exposuresByContext[item.progressionContext] ?? [],
                                todaySupports: context.supports
                            )
                        ),
                        configuration: configuration
                    )
                    guard case let .progressionTransition(progression) = result else { continue }
                    references.append(
                        V2Reference(
                            exerciseId: progression.nextPrescription.exerciseId,
                            loadKg: progression.nextPrescription.load?.kg,
                            loadOptionID: progression.nextPrescription.load?.optionID,
                            targetReps: progression.nextPrescription.targetReps,
                            progressionContext: progression.nextPrescription.progressionContext
                        )
                    )
                }

                let previouslyEligible = !completedExerciseIDs.isEmpty || !references.isEmpty
                guard previouslyEligible || !evidence.isEmpty else { return nil }
                return V2HistoryEntry(
                    endedAt: payload.endedAt.ISO8601Format(),
                    completedExerciseIds: stableUnique(completedExerciseIDs),
                    references: references.isEmpty ? nil : references,
                    restObservations: restObservations.isEmpty ? nil : restObservations,
                    confirmedWorkEvidence: evidence.isEmpty ? nil : evidence,
                    catalogVersion: context.catalogVersion,
                    decisionPolicyVersion: context.decisionPolicyVersion
                )
            }

            let factualIDs = stableUnique(payload.historySession.completedExerciseKeys ?? [])
                .compactMap(productV2ExerciseID(fromLegacyID:))
                .filter { configuration.catalog[$0] != nil }
            guard !factualIDs.isEmpty else { return nil }
            return V2HistoryEntry(
                endedAt: payload.historySession.endedAt,
                completedExerciseIds: factualIDs,
                references: nil,
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion
            )
        }
    }

    static func previewInventory(
        from inventory: [EquipmentItem],
        configuration: V2EngineConfiguration
    ) -> [V2InventoryItem] {
        inventory.compactMap { item in
            let requiredConfigurations = Set(
                configuration.catalog.values
                    .flatMap(\.equipment)
                    .filter { $0.category == item.category }
                    .map(\.configuration)
            )
            if requiredConfigurations.contains("single"), !item.supports("single") {
                return nil
            }
            let units = requiredConfigurations.contains("pair") && !item.supports("pair")
                ? min(item.units, 1)
                : item.units
            return V2InventoryItem(
                category: item.category,
                units: units,
                perUnitWeightsKg: item.perUnitWeightsKg ?? item.weightKg.map { [$0] } ?? [],
                optionIDs: item.optionIDs ?? []
            )
        }
    }

    static func legacyDecision(
        from session: V2SessionDecision,
        limitations: [Limitation],
        migratedHistory: Bool,
        configuration: V2EngineConfiguration
    ) -> EngineDecision {
        let mappedDecision: String
        switch session.decision {
        case .generateSession:
            mappedDecision = "generate_workout"
        case .blockStandardMode:
            mappedDecision = "block_standard_mode"
        default:
            mappedDecision = "request_valid_input"
        }

        var reasons = ["engine.preview_v2"] + session.reasons.map(\.code)
        if migratedHistory { reasons.append("history.v1_completion_migrated_without_reference") }
        var decision = EngineDecision(
            decision: mappedDecision,
            reasonCodes: stableUnique(reasons)
        )
        decision.excludedExerciseKeys = limitations.flatMap(\.excludedExerciseKeys)

        guard session.decision == .generateSession else {
            decision.errorCode = "v2.\(session.decision.rawValue)"
            decision.preserveInput = true
            if session.decision == .blockStandardMode {
                decision.blockReason = "v2.standard_mode_outside_scope"
            }
            return decision
        }

        decision.planProfileId = "product-v2.1.0"
        decision.plan = session.plan.map {
            PlanRow(exerciseKey: $0.exerciseId, sets: $0.sets)
        }
        decision.movements = session.plan.compactMap { item -> PrescribedMovement? in
            guard let exercise = configuration.catalog[item.exerciseId] else { return nil }
            let legacy = EngineCatalog.referenceV1.exercises[item.exerciseId]
            let equipment = exercise.equipment.map { requirement in
                EquipmentRequirement(
                    category: requirement.category,
                    configuration: requirement.configuration
                )
            }
            let target: String
            switch (item.resolvedTargetUnit, exercise.timingSeconds.secondSide > 0) {
            case (.repetitions, false):
                target = String.localizedStringWithFormat(String(localized: "%lld reps"), item.targetReps)
            case (.repetitions, true):
                target = String.localizedStringWithFormat(String(localized: "%lld reps par côté"), item.targetReps)
            case (.seconds, false):
                target = String.localizedStringWithFormat(String(localized: "%lld s"), item.targetReps)
            case (.seconds, true):
                target = String.localizedStringWithFormat(String(localized: "%lld s par côté"), item.targetReps)
            case (.intervals, _):
                target = String.localizedStringWithFormat(String(localized: "%lld intervalles"), item.targetReps)
            }
            return PrescribedMovement(
                exerciseKey: item.exerciseId,
                variant: legacy?.variant ?? exercise.resolvedMovementId,
                pattern: exercise.anchor,
                sets: item.sets,
                target: target,
                restSeconds: item.restSeconds,
                equipment: equipment
            )
        }
        decision.recommendedLoads = session.plan.compactMap { item -> LoadRecommendation? in
            guard let load = item.load,
                  let kg = load.kg,
                  let requirement = configuration.catalog[item.exerciseId]?.equipment.first else {
                return nil
            }
            return LoadRecommendation(
                category: requirement.category,
                configuration: requirement.configuration,
                perUnitWeightKg: kg
            )
        }
        return decision
    }

    private static func legacyConfiguration(for mode: V2LoadMode) -> String {
        switch mode {
        case .bodyweight: "bodyweight"
        case .singleTotalKg: "unilateral"
        case .centralTotalKg: "central"
        case .pairEachKg: "pair"
        case .bandOption: "band"
        }
    }

    private static func productV2ExerciseID(fromLegacyID id: String) -> String? {
        switch id {
        case "incline_pushup": "incline_push_up"
        case "bodyweight_squat": "squat"
        case "bodyweight_hinge": "wall_hip_hinge"
        // V1 used foot assistance. No equivalent V2 context is available:
        // retain the original archive, but never project it as strict capacity.
        case "assisted_pullup": nil
        case "one_arm_row", "foundation_one_arm_row": "supported_one_arm_row__adjustable"
        case "goblet_squat", "established_goblet_squat": "goblet_squat__adjustable"
        case "fixed_goblet_squat": "goblet_squat__fixed"
        case "floor_press", "foundation_floor_press": "dumbbell_floor_press__adjustable"
        case "fixed_floor_press": "dumbbell_floor_press__fixed"
        case "romanian_deadlift", "established_romanian_deadlift": "dumbbell_romanian_deadlift__adjustable"
        case "fixed_romanian_deadlift": "dumbbell_romanian_deadlift__fixed"
        default: V2EngineConfiguration.productPreview.catalog[id] == nil ? nil : id
        }
    }

    private static func stableUnique(_ values: [String]) -> [String] {
        values.reduce(into: []) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }

}
