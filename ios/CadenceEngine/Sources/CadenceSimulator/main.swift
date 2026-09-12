@_spi(AutomaticPolicyExperiment) import CadenceEngine
import Foundation

enum RhythmPolicy: String, CaseIterable {
    case strictTimer = "strict_timer"
    case fullyFree = "fully_free"
    case guidedUserControlled = "guided_user_controlled"
    case autoMax = "auto_max"
    case autoMin = "auto_min"
    case autoTwo = "auto_two"
    case doseCandidate = "dose_candidate"

    var automaticSizing: V2AutomaticSizingExperiment? {
        switch self {
        case .autoMax: .catalogMaximum
        case .autoMin: .catalogMinimum
        case .autoTwo, .doseCandidate: .capAtTwo
        default: nil
        }
    }
}

enum AdherenceCurve {
    case stable(Double)
    case motivationWave

    func probability(week: Int) -> Double {
        switch self {
        case let .stable(value):
            return value
        case .motivationWave:
            if week < 2 { return 0.95 }
            if week < 5 { return 0.60 }
            if week < 9 { return 0.25 }
            return 0.45
        }
    }
}

struct Persona {
    let id: String
    let title: String
    let opportunityWeekdays: Set<Int>
    let adherence: AdherenceCurve
    let durations: [Int]
    let inventory: [V2InventoryItem]
    let paceMultiplier: Double
    let restMultiplier: Double
    let interruptionProbability: Double
    let equipmentAbsenceProbability: Double
    let floorUnavailableProbability: Double
    let lightModeProbability: Double
    let successfulSetProbability: Double
    let preSessionStopProbability: Double
    let duringSessionStopProbability: Double
    let persistentRefusals: [String]
    var hiatusDays: Range<Int>? = nil
    var inventoryChangeDay: Int? = nil
    var changedInventory: [V2InventoryItem]? = nil
}

struct Options {
    var weeks = 12
    var seeds = 20
    var seedStart = 1
    var outputJSON: String? = nil
    var contrasts = false
    var automatic = false
    var dosePolicy = false
    var legacyHistoryProjection = false
    var tracePersonas: Set<String> = []
    var traceSeeds = 1
    var traceLimit = 1_000
}

struct Metrics: Codable {
    var opportunities = 0
    var sessionsStarted = 0
    var sessionsGenerated = 0
    var sessionsCompleted = 0
    var sessionsInterrupted = 0
    var noCleanSession = 0
    var safetyStops = 0
    var plannedSets = 0
    var confirmedSets = 0
    var engineRemovedSets = 0
    var strictAbandonedSets = 0
    var rushedStarts = 0
    var overtimeSeconds = 0
    var totalActualSeconds = 0
    var repetitionProgressions = 0
    var loadProgressions = 0
    var progressionHolds = 0
    var comparableSessionPairs = 0
    var retainedMovements = 0
    var previousMovementCount = 0
    var questionsConsumed = 0
    var doseChanges = 0
    var equipmentLimits = 0
    var invariantViolations: [String: Int] = [:]

    mutating func recordViolation(_ code: String) {
        invariantViolations[code, default: 0] += 1
    }

    mutating func merge(_ other: Metrics) {
        questionsConsumed += other.questionsConsumed
        doseChanges += other.doseChanges
        equipmentLimits += other.equipmentLimits
        opportunities += other.opportunities
        sessionsStarted += other.sessionsStarted
        sessionsGenerated += other.sessionsGenerated
        sessionsCompleted += other.sessionsCompleted
        sessionsInterrupted += other.sessionsInterrupted
        noCleanSession += other.noCleanSession
        safetyStops += other.safetyStops
        plannedSets += other.plannedSets
        confirmedSets += other.confirmedSets
        engineRemovedSets += other.engineRemovedSets
        strictAbandonedSets += other.strictAbandonedSets
        rushedStarts += other.rushedStarts
        overtimeSeconds += other.overtimeSeconds
        totalActualSeconds += other.totalActualSeconds
        repetitionProgressions += other.repetitionProgressions
        loadProgressions += other.loadProgressions
        progressionHolds += other.progressionHolds
        comparableSessionPairs += other.comparableSessionPairs
        retainedMovements += other.retainedMovements
        previousMovementCount += other.previousMovementCount
        for (code, count) in other.invariantViolations {
            invariantViolations[code, default: 0] += count
        }
    }
}

struct SimulationState {
    var history: [V2HistoryEntry] = []
    var doseMemory: [V2DoseMemory] = []
    var previousDosePlan: [V2PlanItem] = []
    var exposures: [String: [V2Exposure]] = [:]
    var previousMovementIds: Set<String> = []
}

struct ExecutionResult {
    let confirmedByExercise: [String: Int]
    let repetitionsByExercise: [String: [Int]]
    let restObservations: [V2RestObservation]
    let completedAtOffsetsByExercise: [String: [Int]]
    let finalPrescribedSetsByExercise: [String: Int]
    let actualSeconds: Int
    let engineRemovedSets: Int
    let strictAbandonedSets: Int
    let rushedStarts: Int
    let interrupted: Bool
    let safetyStopped: Bool
    let safetyStoppedExerciseID: String?
}

struct SimulationRun: Codable {
    let policy: String
    let persona: String
    let seed: Int
    let metrics: Metrics
}

struct SessionTrace: Codable {
    let policy: String
    let persona: String
    let seed: UInt64
    let day: Int
    let startedAt: String
    let decision: String
    let mode: String
    let reasons: [V2Reason]
    let estimatedSeconds: Int
    let observationReferenceSeconds: Int
    let plan: [V2PlanItem]
    let historyBefore: [V2HistoryEntry]
    let historyWritten: V2HistoryEntry?
    let progressionReasons: [String: [V2Reason]]
    let actualSeconds: Int?
    let interruptionCause: String?
    let todayInventory: [V2InventoryItem]
    var exogenousFeedback: [V2DoseFeedback] = []
    var doseQuestionOffered = false
    var doseMemoryBefore: [V2DoseMemory] = []
    var doseMemoryAfter: [V2DoseMemory] = []
}

struct SimulationReport: Codable {
    let schemaVersion: Int
    let evidenceSource: String
    let catalogVersion: String
    let decisionPolicyVersion: String
    let weeks: Int
    let seedStart: Int
    let seeds: Int
    let automatic: Bool
    let dosePolicy: Bool
    let legacyHistoryProjection: Bool
    let tracePersonas: [String]
    let traceSeeds: Int
    let contrasts: Bool
    let traceLimit: Int
    let traceLimitReached: Bool
    let runs: [SimulationRun]
    let traces: [SessionTrace]
}

let configuration = V2EngineConfiguration.productPreview
let options = parseOptions(CommandLine.arguments)
let personas = options.dosePolicy ? dosePersonas() : referencePersonas() + (options.contrasts ? contrastPersonas() : [])
let policies: [RhythmPolicy] = options.dosePolicy ? [.autoTwo, .doseCandidate] : RhythmPolicy.allCases.filter { $0 != .doseCandidate && ($0.automaticSizing != nil) == options.automatic }
let wallStart = ContinuousClock.now
var totals = Dictionary(uniqueKeysWithValues: policies.map { ($0, Metrics()) })
var guidedByPersona: [String: Metrics] = [:]
var runs: [SimulationRun] = []
var traces: [SessionTrace] = []

for policy in policies {
    for persona in personas {
        for seed in options.seedStart..<(options.seedStart + options.seeds) {
            let traceSelected = options.outputJSON != nil
                && (options.tracePersonas.isEmpty ? persona.id == personas.first?.id : options.tracePersonas.contains(persona.id))
                && seed < options.seedStart + options.traceSeeds
            let metrics = simulate(
                persona: persona,
                policy: policy,
                weeks: options.weeks,
                seed: UInt64(seed),
                configuration: configuration,
                legacyHistoryProjection: options.legacyHistoryProjection,
                dosePolicy: options.dosePolicy,
                traceLimit: traceSelected ? options.traceLimit : 0,
                traces: &traces
            )
            totals[policy, default: Metrics()].merge(metrics)
            runs.append(SimulationRun(policy: policy.rawValue, persona: persona.id, seed: seed, metrics: metrics))
            if policy == .guidedUserControlled {
                guidedByPersona[persona.id, default: Metrics()].merge(metrics)
            }
        }
    }
}

let wallElapsed = wallStart.duration(to: .now)
printReport(options: options, personas: personas, totals: totals,
            guidedByPersona: guidedByPersona, wallElapsed: wallElapsed)
if let outputPath = options.outputJSON {
    let report = SimulationReport(
        schemaVersion: 1, evidenceSource: "syntheticScenario", catalogVersion: configuration.catalogVersion,
        decisionPolicyVersion: configuration.decisionPolicyVersion, weeks: options.weeks,
        seedStart: options.seedStart, seeds: options.seeds, automatic: options.automatic, dosePolicy: options.dosePolicy,
        legacyHistoryProjection: options.legacyHistoryProjection, tracePersonas: options.tracePersonas.sorted(), traceSeeds: options.traceSeeds,
        contrasts: options.contrasts, traceLimit: options.traceLimit,
        traceLimitReached: traces.count >= options.traceLimit, runs: runs, traces: traces
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        print("JSON reproductible : \(outputPath) — \(traces.count) traces synthétiques")
    } catch {
        fputs("Écriture JSON impossible : \(error)\n", stderr)
        exit(2)
    }
}
if totals.values.contains(where: { !$0.invariantViolations.isEmpty }) { exit(1) }

func decide(_ request: V2EngineRequest, policy: RhythmPolicy, configuration: V2EngineConfiguration) -> V2EngineResult {
    if let sizing = policy.automaticSizing {
        return CadenceEngine.decideAutomaticExperiment(request: request, configuration: configuration, sizing: sizing)
    }
    return CadenceEngine.decideV2(request: request, configuration: configuration)
}

func simulate(
    persona: Persona,
    policy: RhythmPolicy,
    weeks: Int,
    seed: UInt64,
    configuration: V2EngineConfiguration,
    legacyHistoryProjection: Bool,
    dosePolicy: Bool,
    traceLimit: Int,
    traces: inout [SessionTrace]
) -> Metrics {
    var metrics = Metrics()
    var state = SimulationState()
    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    if dosePolicy { state.history = doseInitialHistory(persona: persona, now: baseDate, configuration: configuration) }
    let totalDays = weeks * 7

    for day in 0..<totalDays {
        let weekday = day % 7
        let weekdays: Set<Int> = dosePolicy && persona.id == "variable_frequency"
            ? (day < 56 ? [0] : (day < 112 ? [0, 1, 2, 3, 4, 5] : [0, 3])) : persona.opportunityWeekdays
        guard weekdays.contains(weekday) else { continue }
        metrics.opportunities += 1
        let week = day / 7
        if persona.hiatusDays?.contains(day) == true { continue }
        let adherence = persona.adherence.probability(week: week)
        guard deterministicUnit(seed: seed, persona: persona.id, day: day, channel: 1) < adherence else {
            continue
        }
        metrics.sessionsStarted += 1

        let now = baseDate.addingTimeInterval(Double(day * 86_400))
        let durationIndex = deterministicIndex(
            count: persona.durations.count,
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 2
        )
        let duration = persona.durations[durationIndex]
        let equipmentMissing = deterministicUnit(
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 3
        ) < persona.equipmentAbsenceProbability
        let persistentInventory = (persona.inventoryChangeDay.map { day >= $0 } == true)
            ? (persona.changedInventory ?? persona.inventory) : persona.inventory
        let todayInventory = equipmentMissing
            ? persistentInventory.filter { $0.category == "bodyweight" }
            : persistentInventory
        let floorUnavailable = deterministicUnit(
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 4
        ) < persona.floorUnavailableProbability
        var supports = ["wall_or_stable_plane", "stable_hand_support"]
        if !floorUnavailable { supports.append("floor_allowed") }

        let randomMode: V2SessionMode = deterministicUnit(
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 5
        ) < persona.lightModeProbability ? .light : .normal

        let mode: V2SessionMode = dosePolicy && persona.id == "return_chosen" && day >= 118 && day <= 124
            ? .recalibration : randomMode
        let transientRefusal = deterministicUnit(
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 7
        ) < persona.floorUnavailableProbability ? ["dumbbell_floor_press__adjustable"] : []
        let refusals = (persona.persistentRefusals + transientRefusal).map {
            V2Refusal(
                scope: "movement",
                temporalScope: persona.persistentRefusals.contains($0) ? "persistent" : "today",
                exerciseId: $0
            )
        }
        let preSessionStop = deterministicUnit(
            seed: seed,
            persona: persona.id,
            day: day,
            channel: 8
        ) < persona.preSessionStopProbability
        let input = V2SessionDecisionInput(
            request: V2SessionRequest(durationMinutes: duration, mode: mode),
            persistentInventory: persistentInventory,
            todayInventory: todayInventory,
            todaySupports: supports,
            history: Array(state.history.suffix(configuration.policy.historyDepthCompletedSessions)),
            refusals: refusals,
            declaredCurrentHealthSignal: preSessionStop
        )
        let feedback = dosePolicy ? doseFeedback(persona: persona, now: now, day: day, configuration: configuration) : []
        let questionOffered = dosePolicy && (!feedback.isEmpty ||
            (["absent_response", "historical_three_unanswered"].contains(persona.id) && day == 14) ||
            (["return_no_answer", "return_external_unknown"].contains(persona.id) && day == 119))
        let memoryBefore = state.doseMemory
        let initialDecision: V2SessionDecision
        if policy == .doseCandidate {
            let result = CadenceEngine.decideDoseExperiment(input: input, now: now,
                configuration: configuration, memory: state.doseMemory, feedback: feedback)
            initialDecision = result.decision
            state.doseMemory = result.memory
        } else {
            guard case let .sessionDecision(value) = decide(.sessionDecision(input, now: now),
                policy: policy, configuration: configuration) else {
                metrics.recordViolation("unexpected_engine_result"); continue
            }
            initialDecision = value
        }
        var decision = initialDecision
        if !dosePolicy, mode == .normal,
           initialDecision.plan.contains(where: { $0.referenceStatus == "reconfirmation_pending" }),
           deterministicUnit(seed: seed, persona: persona.id, day: day, channel: 6) < 0.75 {
            let recalibrationInput = V2SessionDecisionInput(
                request: V2SessionRequest(durationMinutes: duration, mode: .recalibration),
                persistentInventory: persistentInventory,
                todayInventory: todayInventory,
                todaySupports: supports,
                history: Array(state.history.suffix(configuration.policy.historyDepthCompletedSessions)),
                refusals: refusals,
                declaredCurrentHealthSignal: preSessionStop
            )
            guard case let .sessionDecision(recalibrationDecision) = decide(
                .sessionDecision(recalibrationInput, now: now), policy: policy,
                configuration: configuration
            ) else {
                metrics.recordViolation("unexpected_recalibration_result")
                continue
            }
            decision = recalibrationDecision
        }
        if dosePolicy {
            metrics.questionsConsumed += decision.reasons.filter { $0.code.hasPrefix("dose_feedback_") && $0.code != "dose_feedback_ignored" && $0.code != "dose_feedback_not_applicable" }.count
            metrics.equipmentLimits += decision.reasons.filter { $0.code == "dose_equipment_limit" }.count
            for item in decision.plan {
                guard let prior = state.previousDosePlan.first(where: { $0.progressionContext == item.progressionContext }) else { continue }
                if item.sets != prior.sets { metrics.doseChanges += 1 }
                if item.sets > prior.sets && (item.targetReps != prior.targetReps || item.load != prior.load) {
                    metrics.recordViolation("dose_and_difficulty_increased_together")
                }
            }
        }
        state.previousDosePlan = decision.plan
        let historyBefore = Array(state.history.suffix(configuration.policy.historyDepthCompletedSessions))
        let observationReferenceSeconds = policy.automaticSizing == nil ? duration * 60 : decision.estimatedSeconds
        if decision.decision != .generateSession, traces.count < traceLimit {
            traces.append(SessionTrace(policy: policy.rawValue, persona: persona.id, seed: seed, day: day,
                startedAt: isoDate(now), decision: decision.decision.rawValue, mode: decision.mode.rawValue,
                reasons: decision.reasons, estimatedSeconds: decision.estimatedSeconds,
                observationReferenceSeconds: observationReferenceSeconds, plan: decision.plan,
                historyBefore: historyBefore, historyWritten: nil, progressionReasons: [:], actualSeconds: nil,
                interruptionCause: preSessionStop ? "explicit_safety_signal" : nil, todayInventory: todayInventory,
                exogenousFeedback: feedback, doseQuestionOffered: questionOffered, doseMemoryBefore: memoryBefore, doseMemoryAfter: state.doseMemory))
        }
        if decision.createsDebt { metrics.recordViolation("session_created_debt") }
        if decision.automaticProgression { metrics.recordViolation("session_progressed_automatically") }
        if decision.decision == .stopStandardSession {
            metrics.safetyStops += 1
            continue
        }
        if decision.decision == .noCleanSession {
            metrics.noCleanSession += 1
            continue
        }
        guard decision.decision == .generateSession else {
            metrics.recordViolation("unexpected_session_decision_\(decision.decision.rawValue)")
            continue
        }

        metrics.sessionsGenerated += 1
        metrics.plannedSets += decision.plan.reduce(0) { $0 + $1.sets }
        validatePlan(
            decision.plan,
            inventory: todayInventory,
            supports: supports,
            configuration: configuration,
            metrics: &metrics
        )
        let movementIds = Set(decision.plan.map(\.exerciseId))
        if !state.previousMovementIds.isEmpty {
            metrics.comparableSessionPairs += 1
            metrics.retainedMovements += movementIds.intersection(state.previousMovementIds).count
            metrics.previousMovementCount += state.previousMovementIds.count
        }
        state.previousMovementIds = movementIds

        let execution = execute(
            plan: decision.plan,
            persona: persona,
            policy: policy,
            durationSeconds: observationReferenceSeconds,
            day: day,
            seed: seed,
            configuration: configuration, dosePolicy: dosePolicy
        )
        metrics.confirmedSets += execution.confirmedByExercise.values.reduce(0, +)
        metrics.engineRemovedSets += execution.engineRemovedSets
        metrics.strictAbandonedSets += execution.strictAbandonedSets
        metrics.rushedStarts += execution.rushedStarts
        metrics.totalActualSeconds += execution.actualSeconds
        metrics.overtimeSeconds += max(0, execution.actualSeconds - observationReferenceSeconds)
        if execution.interrupted {
            metrics.sessionsInterrupted += 1
        } else if execution.safetyStopped {
            metrics.safetyStops += 1
        } else {
            metrics.sessionsCompleted += 1
        }

        var progressionReasons: [String: [V2Reason]] = [:]
        var completedExerciseIds: [String] = []
        var completedReferences: [V2Reference] = []
        for item in decision.plan {
            let finalPrescribedSets = execution.finalPrescribedSetsByExercise[item.exerciseId] ?? item.sets
            guard finalPrescribedSets > 0 else { continue }
            let confirmedSets = execution.confirmedByExercise[item.exerciseId, default: 0]
            guard confirmedSets > 0 else { continue }
            let allSetsConfirmed = confirmedSets == finalPrescribedSets
            if allSetsConfirmed && (!dosePolicy || execution.safetyStoppedExerciseID != item.exerciseId) { completedExerciseIds.append(item.exerciseId) }
            let exposure = V2Exposure(
                confirmedReps: execution.repetitionsByExercise[item.exerciseId, default: []],
            loadKg: item.load?.kg,
            loadOptionID: item.load?.optionID,
                allPrescribedSetsConfirmed: allSetsConfirmed,
                progressionContext: item.progressionContext,
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion,
                interruptedBySafetySignal: dosePolicy ? execution.safetyStoppedExerciseID == item.exerciseId : execution.safetyStopped
            )
            state.exposures[item.progressionContext, default: []].append(exposure)
            let current = V2Prescription(
                exerciseId: item.exerciseId,
                sets: finalPrescribedSets,
                targetReps: item.targetReps,
                load: item.load,
                progressionContext: item.progressionContext,
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion
            )
            guard case let .progressionTransition(progression) = CadenceEngine.decideV2(
                request: .progressionTransition(V2ProgressionInput(
                    todayInventory: todayInventory,
                    previousPrescription: current,
                    exposures: Array(state.exposures[item.progressionContext, default: []].suffix(6)),
                    todaySupports: supports
                )),
                configuration: configuration
            ) else {
                metrics.recordViolation("unexpected_progression_result")
                continue
            }
            progressionReasons[item.progressionContext] = progression.reasons
            validateProgression(
                progression,
                inventory: todayInventory,
                configuration: configuration,
                metrics: &metrics
            )
            if allSetsConfirmed && (!dosePolicy || execution.safetyStoppedExerciseID != item.exerciseId) {
                completedReferences.append(V2Reference(
                    exerciseId: progression.nextPrescription.exerciseId,
                    loadKg: progression.nextPrescription.load?.kg,
                    loadOptionID: progression.nextPrescription.load?.optionID,
                    targetReps: progression.nextPrescription.targetReps,
                    progressionContext: progression.nextPrescription.progressionContext
                ))
            }
            switch progression.atomicChange {
            case "load_step_with_range_reset": metrics.loadProgressions += 1
            default:
                if progression.changedFields == ["targetReps"] {
                    metrics.repetitionProgressions += 1
                } else if progression.decision == .holdPrescription {
                    metrics.progressionHolds += 1
                }
            }
        }

        let confirmedWork = decision.plan.compactMap { item -> V2ConfirmedWorkEvidence? in
            guard let exercise = configuration.catalog[item.exerciseId] else { return nil }
            let repetitions = execution.repetitionsByExercise[item.exerciseId, default: []]
            let offsets = execution.completedAtOffsetsByExercise[item.exerciseId, default: []]
            let sets = repetitions.enumerated().map { index, repetitions in
                V2ConfirmedSetEvidence(
                    eventID: "synthetic:\(policy.rawValue):\(persona.id):\(seed):\(day):\(item.exerciseId):\(index)",
                    repetitions: repetitions, loadKg: item.load?.kg, loadOptionID: item.load?.optionID,
                    completedAt: isoDate(now.addingTimeInterval(Double(offsets[index])))
                )
            }
            return V2ConfirmedWorkEvidence(
                exerciseId: item.exerciseId, progressionContext: item.progressionContext,
                plannedSets: item.sets, targetUnit: exercise.resolvedTargetUnit, confirmedSets: sets,
                wasSkipped: false, interruptedBySafetySignal: execution.safetyStoppedExerciseID == item.exerciseId,
                source: .syntheticScenario
            )
        }
        let historyEntry = V2HistoryEntry(
            endedAt: isoDate(now.addingTimeInterval(Double(execution.actualSeconds))),
            completedExerciseIds: completedExerciseIds,
            references: completedReferences.sorted {
                ($0.exerciseId, $0.progressionContext) < ($1.exerciseId, $1.progressionContext)
            },
            restObservations: execution.restObservations,
            confirmedWorkEvidence: legacyHistoryProjection || (dosePolicy && persona.id == "missing_facts") ? nil : confirmedWork,
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion
        )
        state.history.append(historyEntry)
        if traces.count < traceLimit {
            traces.append(SessionTrace(policy: policy.rawValue, persona: persona.id, seed: seed, day: day,
                startedAt: isoDate(now), decision: decision.decision.rawValue, mode: decision.mode.rawValue,
                reasons: decision.reasons, estimatedSeconds: decision.estimatedSeconds,
                observationReferenceSeconds: observationReferenceSeconds, plan: decision.plan,
                historyBefore: historyBefore, historyWritten: historyEntry, progressionReasons: progressionReasons, actualSeconds: execution.actualSeconds,
                interruptionCause: execution.safetyStopped ? "explicit_safety_signal" : (execution.strictAbandonedSets > 0 ? "strict_time_limit" : (execution.interrupted ? "unknown" : nil)),
                todayInventory: todayInventory,
                exogenousFeedback: feedback, doseQuestionOffered: questionOffered, doseMemoryBefore: memoryBefore, doseMemoryAfter: state.doseMemory))
        }

    }
    return metrics
}

func execute(
    plan: [V2PlanItem],
    persona: Persona,
    policy: RhythmPolicy,
    durationSeconds: Int,
    day: Int,
    seed: UInt64,
    configuration: V2EngineConfiguration,
    dosePolicy: Bool = false
) -> ExecutionResult {
    var remaining = plan
    var confirmedByExercise: [String: Int] = [:]
    var repetitionsByExercise: [String: [Int]] = [:]
    var completedAtOffsetsByExercise: [String: [Int]] = [:]
    var restObservations: [V2RestObservation] = []
    var finalPrescribedSetsByExercise = Dictionary(
        uniqueKeysWithValues: plan.map { ($0.exerciseId, $0.sets) }
    )
    var actualSeconds = 0
    var nominalSeconds = 0
    var engineRemovedSets = 0
    var strictAbandonedSets = 0
    var rushedStarts = 0
    var interrupted = false
    var safetyStopped = false
    var safetyStoppedExerciseID: String?
    let interruption = deterministicUnit(seed: seed, persona: persona.id, day: day, channel: 20)
        < persona.interruptionProbability
    let plannedSetCount = max(1, plan.reduce(0) { $0 + $1.sets })
    let interruptionIndex = interruption
        ? deterministicIndex(count: dosePolicy ? 8 : plannedSetCount, seed: seed, persona: persona.id, day: day, channel: 21)
        : nil
    let healthStopIndex = deterministicUnit(seed: seed, persona: persona.id, day: day, channel: 22)
        < persona.duringSessionStopProbability ? 0 : nil
    var globalSetIndex = 0

    executionLoop: while !remaining.isEmpty {
        let item = remaining.removeFirst()
        guard let exercise = configuration.catalog[item.exerciseId] else { continue }
        let jitter = movementJitter(item, persona: persona, seed: seed, day: day)
        let setupSeconds = scaledSeconds(
            exercise.timingSeconds.setup,
            multiplier: persona.paceMultiplier * jitter
        )
        let transitionSeconds = scaledSeconds(
            exercise.timingSeconds.transition,
            multiplier: persona.paceMultiplier * jitter
        )
        let firstExecutionSeconds = scaledSeconds(
            exercise.timingSeconds.execution + exercise.timingSeconds.secondSide,
            multiplier: persona.paceMultiplier * jitter
        )
        if policy == .strictTimer,
           actualSeconds + setupSeconds + firstExecutionSeconds
            + (item.sets == 1 ? transitionSeconds : 0) > durationSeconds {
            strictAbandonedSets += item.sets + remaining.reduce(0) { $0 + $1.sets }
            interrupted = true
            break
        }
        actualSeconds += setupSeconds
        nominalSeconds += exercise.timingSeconds.setup
        let channelBase = 100 + Int(stableHash(item.exerciseId) % 10_000)
        var completedSets = 0

        for setIndex in 0..<item.sets {
            let nominalRest = setIndex == 0 ? 0 : item.restSeconds
            let desiredRest = scaledSeconds(
                nominalRest,
                multiplier: persona.restMultiplier * jitter
            )
            let actualRest: Int
            if policy == .strictTimer {
                actualRest = min(desiredRest, nominalRest)
            } else {
                actualRest = desiredRest
            }
            let executionSeconds = scaledSeconds(
                exercise.timingSeconds.execution + exercise.timingSeconds.secondSide,
                multiplier: persona.paceMultiplier * jitter
            )
            let closesMovement = setIndex == item.sets - 1
            if policy == .strictTimer,
               actualSeconds + actualRest + executionSeconds
                + (closesMovement ? transitionSeconds : 0) > durationSeconds {
                strictAbandonedSets += item.sets - setIndex
                    + remaining.reduce(0) { $0 + $1.sets }
                interrupted = true
                break executionLoop
            }
            if policy == .strictTimer, desiredRest > nominalRest + 1 {
                rushedStarts += 1
            }
            actualSeconds += actualRest + executionSeconds
            if nominalRest > 0 {
                restObservations.append(
                    V2RestObservation(
                        progressionContext: item.progressionContext,
                        plannedSeconds: nominalRest,
                        actualSeconds: actualRest
                    )
                )
            }
            nominalSeconds += nominalRest
                + exercise.timingSeconds.execution
                + exercise.timingSeconds.secondSide
            completedSets += 1
            confirmedByExercise[item.exerciseId] = completedSets
            let succeeds = deterministicUnit(
                seed: seed,
                persona: persona.id,
                day: day,
                channel: channelBase + setIndex
            ) < persona.successfulSetProbability
            repetitionsByExercise[item.exerciseId, default: []].append(
                succeeds ? item.targetReps : max(1, item.targetReps - 1)
            )

            completedAtOffsetsByExercise[item.exerciseId, default: []].append(actualSeconds)

            let unstartedCurrent = item.sets - completedSets
            let unstarted = (unstartedCurrent > 0 ? [withSets(item, unstartedCurrent)] : []) + remaining
            if healthStopIndex == globalSetIndex {
                let transition = activeTransition(
                    action: .declareHealthSignal,
                    remainingSeconds: nil,
                    confirmedByExercise: confirmedByExercise,
                    plan: plan,
                    unstarted: unstarted,
                    configuration: configuration,
                    policy: policy
                )
                precondition(transition.decision == .stopCurrentMovement)
                precondition(transition.confirmedImmutable && !transition.createsDebt)
                safetyStopped = true
                safetyStoppedExerciseID = item.exerciseId
                break executionLoop
            }
            if interruptionIndex == globalSetIndex {
                interrupted = true
                break executionLoop
            }
            globalSetIndex += 1
        }

        actualSeconds += transitionSeconds
        nominalSeconds += exercise.timingSeconds.transition

        if policy == .guidedUserControlled, !remaining.isEmpty {
            let remainingWallSeconds = max(0, durationSeconds - actualSeconds)
            let observedMultiplier = nominalSeconds > 0
                ? max(1, Double(actualSeconds) / Double(nominalSeconds))
                : 1
            let nominalRemaining = remaining.reduce(0) { total, next in
                guard let nextExercise = configuration.catalog[next.exerciseId] else { return total }
                return total + nextExercise.timingSeconds.cost(forSets: next.sets)
            }
            let projectedRemaining = Int((Double(nominalRemaining) * observedMultiplier).rounded())
            if projectedRemaining > remainingWallSeconds {
                let effectiveBudget = Int(Double(remainingWallSeconds) / observedMultiplier)
                let transition = activeTransition(
                    action: .finishOnTime,
                    remainingSeconds: effectiveBudget,
                    confirmedByExercise: confirmedByExercise,
                    plan: plan,
                    unstarted: remaining,
                    configuration: configuration,
                    policy: policy
                )
                precondition(transition.decision == .activeSessionTransition)
                precondition(transition.confirmedImmutable && !transition.createsDebt)
                engineRemovedSets += transition.removed.reduce(0) { $0 + $1.sets }
                for item in remaining {
                    finalPrescribedSetsByExercise[item.exerciseId] = 0
                }
                for item in transition.plan {
                    finalPrescribedSetsByExercise[item.exerciseId] = item.sets
                }
                remaining = transition.plan
            }
        }
    }

    return ExecutionResult(
        confirmedByExercise: confirmedByExercise,
        repetitionsByExercise: repetitionsByExercise,
        restObservations: restObservations,
        completedAtOffsetsByExercise: completedAtOffsetsByExercise,
        finalPrescribedSetsByExercise: finalPrescribedSetsByExercise,
        actualSeconds: actualSeconds,
        engineRemovedSets: engineRemovedSets,
        strictAbandonedSets: strictAbandonedSets,
        rushedStarts: rushedStarts,
        interrupted: interrupted,
        safetyStopped: safetyStopped,
        safetyStoppedExerciseID: safetyStoppedExerciseID
    )
}

func withSets(_ item: V2PlanItem, _ sets: Int) -> V2PlanItem {
    V2PlanItem(
        exerciseId: item.exerciseId,
        sourceExerciseId: item.sourceExerciseId,
        sets: sets,
        targetReps: item.targetReps,
        restSeconds: item.restSeconds,
        load: item.load,
        referenceStatus: item.referenceStatus,
        progressionContext: item.progressionContext,
        targetUnit: item.targetUnit
    )
}

func activeTransition(
    action: V2ActiveAction,
    remainingSeconds: Int?,
    confirmedByExercise: [String: Int],
    plan: [V2PlanItem],
    unstarted: [V2PlanItem],
    configuration: V2EngineConfiguration,
    policy: RhythmPolicy
) -> V2ActiveTransitionDecision {
    let confirmed = confirmedByExercise.compactMap { exerciseId, sets -> V2ConfirmedWork? in
        guard let item = plan.first(where: { $0.exerciseId == exerciseId }) else { return nil }
        return V2ConfirmedWork(
            exerciseId: exerciseId,
            sets: sets,
            targetReps: item.targetReps,
            load: item.load,
            progressionContext: item.progressionContext
        )
    }
    let unstartedWork = unstarted.map {
        V2UnstartedWork(
            exerciseId: $0.exerciseId,
            sets: $0.sets,
            targetReps: $0.targetReps,
            restSeconds: $0.restSeconds,
            load: $0.load,
            sourceExerciseId: $0.sourceExerciseId,
            referenceStatus: $0.referenceStatus,
            progressionContext: $0.progressionContext
        )
    }
    guard case let .activeSessionTransition(decision) = decide(
        .activeSessionTransition(V2ActiveTransitionInput(
            action: action,
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion,
            remainingSeconds: remainingSeconds,
            activeExerciseId: plan.first?.exerciseId,
            confirmed: confirmed,
            unstarted: unstartedWork
        )),
        policy: policy, configuration: configuration
    ) else {
        preconditionFailure("Résultat de transition active inattendu")
    }
    return decision
}

func movementJitter(
    _ item: V2PlanItem,
    persona: Persona,
    seed: UInt64,
    day: Int
) -> Double {
    0.90 + 0.20 * deterministicUnit(
        seed: seed,
        persona: persona.id,
        day: day,
        channel: 30 + Int(stableHash(item.exerciseId) % 10_000)
    )
}

func scaledSeconds(_ seconds: Int, multiplier: Double) -> Int {
    Int((Double(seconds) * multiplier).rounded())
}

func validatePlan(
    _ plan: [V2PlanItem],
    inventory: [V2InventoryItem],
    supports: [String],
    configuration: V2EngineConfiguration,
    metrics: inout Metrics
) {
    for item in plan {
        guard let exercise = configuration.catalog[item.exerciseId] else {
            metrics.recordViolation("unknown_exercise")
            continue
        }
        if !exercise.supports.allSatisfy(Set(supports).contains) {
            metrics.recordViolation("support_invented")
        }
        for requirement in exercise.equipment where !inventory.contains(where: {
            $0.category == requirement.category && $0.units >= requirement.units
        }) {
            metrics.recordViolation("equipment_invented")
        }
        if let kg = item.load?.kg,
           !inventory.flatMap(\.perUnitWeightsKg).contains(kg) {
            metrics.recordViolation("load_invented")
        }
    }
}

func validateProgression(
    _ progression: V2ProgressionDecision,
    inventory: [V2InventoryItem],
    configuration: V2EngineConfiguration,
    metrics: inout Metrics
) {
    if progression.catalogVersion != configuration.catalogVersion
        || progression.decisionPolicyVersion != configuration.decisionPolicyVersion {
        metrics.recordViolation("progression_version_drift")
    }
    let allowedShapes = progression.changedFields.isEmpty
        || progression.changedFields == ["targetReps"]
        || Set(progression.changedFields) == Set(["load", "targetReps"])
    if !allowedShapes { metrics.recordViolation("non_atomic_progression") }
    if let kg = progression.nextPrescription.load?.kg,
       !inventory.flatMap(\.perUnitWeightsKg).contains(kg) {
        metrics.recordViolation("progression_load_invented")
    }
}

func referencePersonas() -> [Persona] {
    let bodyweight = V2InventoryItem(category: "bodyweight", units: 1)
    let adjustable = V2InventoryItem(
        category: "adjustable_dumbbell",
        units: 2,
        perUnitWeightsKg: [4, 6, 8, 10, 12]
    )
    let single = V2InventoryItem(
        category: "adjustable_dumbbell",
        units: 1,
        perUnitWeightsKg: [6, 8, 10]
    )
    return [
        Persona(
            id: "steady_beginner",
            title: "Débutant régulier",
            opportunityWeekdays: [0, 2, 4],
            adherence: .stable(0.88),
            durations: [30],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.05,
            restMultiplier: 1.10,
            interruptionProbability: 0.04,
            equipmentAbsenceProbability: 0.04,
            floorUnavailableProbability: 0.03,
            lightModeProbability: 0.08,
            successfulSetProbability: 0.76,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "irregular_short",
            title: "Emploi du temps irrégulier",
            opportunityWeekdays: [0, 1, 3, 5],
            adherence: .stable(0.48),
            durations: [20, 20, 30],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.18,
            restMultiplier: 1.25,
            interruptionProbability: 0.18,
            equipmentAbsenceProbability: 0.18,
            floorUnavailableProbability: 0.12,
            lightModeProbability: 0.22,
            successfulSetProbability: 0.64,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "motivation_wave",
            title: "Élan puis décrochage",
            opportunityWeekdays: [0, 2, 4, 6],
            adherence: .motivationWave,
            durations: [30, 45],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.00,
            restMultiplier: 1.00,
            interruptionProbability: 0.08,
            equipmentAbsenceProbability: 0.08,
            floorUnavailableProbability: 0.05,
            lightModeProbability: 0.10,
            successfulSetProbability: 0.72,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "slow_deliberate",
            title: "Prudent et lent",
            opportunityWeekdays: [1, 4],
            adherence: .stable(0.86),
            durations: [20, 30],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.30,
            restMultiplier: 1.45,
            interruptionProbability: 0.05,
            equipmentAbsenceProbability: 0.02,
            floorUnavailableProbability: 0.04,
            lightModeProbability: 0.18,
            successfulSetProbability: 0.58,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "minimal_equipment",
            title: "Poids du corps uniquement",
            opportunityWeekdays: [1, 3, 5],
            adherence: .stable(0.72),
            durations: [20],
            inventory: [bodyweight],
            paceMultiplier: 1.10,
            restMultiplier: 1.15,
            interruptionProbability: 0.08,
            equipmentAbsenceProbability: 0,
            floorUnavailableProbability: 0.08,
            lightModeProbability: 0.12,
            successfulSetProbability: 0.68,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "single_weight",
            title: "Une seule charge",
            opportunityWeekdays: [0, 3],
            adherence: .stable(0.80),
            durations: [30],
            inventory: [bodyweight, single],
            paceMultiplier: 1.08,
            restMultiplier: 1.15,
            interruptionProbability: 0.07,
            equipmentAbsenceProbability: 0.12,
            floorUnavailableProbability: 0.05,
            lightModeProbability: 0.12,
            successfulSetProbability: 0.70,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: ["dumbbell_floor_press__adjustable"]
        ),
        Persona(
            id: "equipment_shifts",
            title: "Matériel souvent indisponible",
            opportunityWeekdays: [0, 2, 5],
            adherence: .stable(0.76),
            durations: [20, 30],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.12,
            restMultiplier: 1.18,
            interruptionProbability: 0.10,
            equipmentAbsenceProbability: 0.42,
            floorUnavailableProbability: 0.18,
            lightModeProbability: 0.15,
            successfulSetProbability: 0.66,
            preSessionStopProbability: 0,
            duringSessionStopProbability: 0,
            persistentRefusals: []
        ),
        Persona(
            id: "explicit_stop",
            title: "Arrêts explicites occasionnels",
            opportunityWeekdays: [1, 4],
            adherence: .stable(0.82),
            durations: [30],
            inventory: [bodyweight, adjustable],
            paceMultiplier: 1.12,
            restMultiplier: 1.20,
            interruptionProbability: 0.06,
            equipmentAbsenceProbability: 0.03,
            floorUnavailableProbability: 0.05,
            lightModeProbability: 0.15,
            successfulSetProbability: 0.65,
            preSessionStopProbability: 0.025,
            duringSessionStopProbability: 0.025,
            persistentRefusals: []
        ),
    ]
}

func contrastPersonas() -> [Persona] {
    let reference = referencePersonas()[0]
    func profile(_ id: String, _ title: String, success: Double = 0.76,
                 interruptions: Double = 0.04, hiatus: Range<Int>? = nil,
                 inventoryChangeDay: Int? = nil, changedInventory: [V2InventoryItem]? = nil) -> Persona {
        Persona(id: id, title: title, opportunityWeekdays: reference.opportunityWeekdays,
                adherence: .stable(0.88), durations: reference.durations, inventory: reference.inventory,
                paceMultiplier: reference.paceMultiplier, restMultiplier: reference.restMultiplier,
                interruptionProbability: interruptions, equipmentAbsenceProbability: 0,
                floorUnavailableProbability: 0, lightModeProbability: 0,
                successfulSetProbability: success, preSessionStopProbability: 0,
                duringSessionStopProbability: 0, persistentRefusals: [], hiatusDays: hiatus,
                inventoryChangeDay: inventoryChangeDay, changedInventory: changedInventory)
    }
    return [
        profile("stagnation", "Stagnation synthétique", success: 0),
        profile("unknown_interruptions", "Interruptions de cause inconnue", interruptions: 0.45),
        profile("return_after_90_days", "Reprise après 90 jours sans séance", hiatus: 28..<118),
        profile("equipment_change", "Changement durable de matériel", inventoryChangeDay: 56,
                changedInventory: [V2InventoryItem(category: "bodyweight", units: 1),
                                   V2InventoryItem(category: "kettlebell", units: 1, perUnitWeightsKg: [8, 12])])
    ]
}

// Dedicated scenario cohort: no values below are fitted to either result branch.
func dosePersonas() -> [Persona] {
    let base = referencePersonas()[0]
    let names: [(String, String)] = [
        ("regular", "Régulier"), ("stagnation", "Répétitions stagnantes"),
        ("unknown_interruptions", "Interruptions sans cause déclarée"),
        ("target_attained_no_effort", "Cible atteinte, effort inconnu"),
        ("too_easy", "Difficulté trop faible déclarée"),
        ("equipment_ceiling", "Plafond de matériel déclaré"),
        ("variable_frequency", "Fréquence observée variable"),
        ("return_chosen", "Reprise explicitement choisie"),
        ("return_no_answer", "Retour sans réponse"),
        ("return_external_declared", "Entraînement ailleurs déclaré"),
        ("return_external_unknown", "Entraînement ailleurs inconnu"),
        ("missing_facts", "Séries historiques inconnues"),
        ("stale_reference", "Référence ancienne"),
        ("context_change", "Changement de matériel et contexte"),
        ("explicit_volume_excess", "Volume excessif déclaré"),
        ("initial_too_hard", "Difficulté excessive dès le départ"),
        ("discovery", "Découverte explicitement choisie"),
        ("historical_three_unanswered", "Trois séries historiques sans réponse"),
        ("historical_three_explicit", "Préférence historique explicitement choisie"),
        ("absent_response", "Question sans réponse"),
        ("explicit_stop", "Arrêt de sécurité explicite")
    ]
    return names.map { id, title in
        let returning = id.hasPrefix("return_")
        let inventory = id == "equipment_ceiling"
            ? [V2InventoryItem(category: "bodyweight", units: 1),
               V2InventoryItem(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4])]
            : base.inventory
        return Persona(id: id, title: title, opportunityWeekdays: [0, 2, 4],
            adherence: .stable(1), durations: [20, 30, 45], inventory: inventory,
            paceMultiplier: base.paceMultiplier, restMultiplier: base.restMultiplier,
            interruptionProbability: id == "unknown_interruptions" ? 0.45 : 0,
            equipmentAbsenceProbability: 0, floorUnavailableProbability: 0, lightModeProbability: 0,
            successfulSetProbability: id == "stagnation" || id == "initial_too_hard" ? 0 : (id == "regular" ? 0.76 : 1),
            preSessionStopProbability: 0, duringSessionStopProbability: id == "explicit_stop" ? 0.12 : 0, persistentRefusals: [],
            hiatusDays: returning ? 28..<118 : nil,
            inventoryChangeDay: id == "context_change" ? 56 : nil,
            changedInventory: id == "context_change" ? [V2InventoryItem(category: "bodyweight", units: 1),
                V2InventoryItem(category: "kettlebell", units: 1, perUnitWeightsKg: [8, 12])] : nil)
    }
}

func doseFeedback(persona: Persona, now: Date, day: Int,
                  configuration: V2EngineConfiguration) -> [V2DoseFeedback] {
    // This fixed context never follows a policy-dependent plan or completion.
    let context = "supported_one_arm_row__adjustable"
    let action: V2DoseAction?
    switch persona.id {
    case "too_easy", "equipment_ceiling": action = day % 14 == 0 ? .difficultyTooLow : nil
    case "explicit_volume_excess": action = day == 14 ? .volumeTooHigh : nil
    case "initial_too_hard": action = day == 0 ? .difficultyTooHigh : nil
    case "discovery": action = day == 0 ? .discover : nil
    case "historical_three_explicit": action = day == 2 ? .preferHistorical : nil
    case "return_external_declared": action = day == 119 ? .trainedElsewhere : nil
    case "return_chosen": action = day == 119 ? .noTrainingElsewhere : nil
    default: action = nil
    }
    guard let action else { return [] }
    return [V2DoseFeedback(progressionContext: context, action: action, at: now,
        source: .syntheticScenario, catalogVersion: configuration.catalogVersion,
        decisionPolicyVersion: configuration.decisionPolicyVersion,
        historicalSets: action == .preferHistorical ? 3 : nil)]
}

func doseInitialHistory(persona: Persona, now: Date,
                        configuration: V2EngineConfiguration) -> [V2HistoryEntry] {
    let historical = persona.id.hasPrefix("historical_three")
    guard historical || persona.id == "stale_reference" || persona.id == "equipment_ceiling" || persona.id == "initial_too_hard" else { return [] }
    let input = V2SessionDecisionInput(request: V2SessionRequest(durationMinutes: 30, mode: .normal),
        persistentInventory: persona.inventory, todayInventory: persona.inventory,
        todaySupports: ["wall_or_stable_plane", "stable_hand_support", "floor_allowed"], history: [])
    guard case let .sessionDecision(decision) = decide(.sessionDecision(input, now: now),
        policy: .autoTwo, configuration: configuration) else { return [] }
    let offsets = persona.id == "stale_reference" ? [-127, -123] : [-7, -3]
    return offsets.map { offset in
        let start = now.addingTimeInterval(Double(offset * 86_400))
        let references = decision.plan.map { item in
            V2Reference(exerciseId: item.exerciseId, loadKg: persona.id == "initial_too_hard" && item.load?.kg != nil ? 8 : item.load?.kg, loadOptionID: item.load?.optionID,
                targetReps: ["equipment_ceiling", "initial_too_hard"].contains(persona.id) ? configuration.catalog[item.exerciseId]!.repRange.max : item.targetReps,
                progressionContext: item.progressionContext)
        }
        let evidence = zip(decision.plan, references).map { item, reference in
            V2ConfirmedWorkEvidence(exerciseId: item.exerciseId, progressionContext: item.progressionContext,
                plannedSets: historical ? 3 : 2, targetUnit: item.resolvedTargetUnit,
                confirmedSets: (0..<(historical ? 3 : 2)).map { index in
                    V2ConfirmedSetEvidence(eventID: "synthetic:prior:\(persona.id):\(offset):\(item.exerciseId):\(index)",
                        repetitions: reference.targetReps, loadKg: reference.loadKg, loadOptionID: reference.loadOptionID,
                        completedAt: isoDate(start.addingTimeInterval(Double(60 + index * 120))))
                }, wasSkipped: false, interruptedBySafetySignal: false, source: .syntheticScenario)
        }
        return V2HistoryEntry(endedAt: isoDate(start.addingTimeInterval(600)),
            completedExerciseIds: decision.plan.map(\.exerciseId), references: references,
            confirmedWorkEvidence: evidence, catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion)
    }
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var index = 1
    while index < arguments.count {
        let argument = arguments[index]
        if argument == "--weeks", arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]), value > 0 {
            options.weeks = value
            index += 2
        } else if argument == "--seeds", arguments.indices.contains(index + 1),
                  let value = Int(arguments[index + 1]), value > 0 {
            options.seeds = value
            index += 2
        } else if argument == "--seed-start", arguments.indices.contains(index + 1),
                  let value = Int(arguments[index + 1]), (1...1_000_000).contains(value) {
            options.seedStart = value; index += 2
        } else if argument == "--output-json", arguments.indices.contains(index + 1) {
            options.outputJSON = arguments[index + 1]; index += 2
        } else if argument == "--trace-personas", arguments.indices.contains(index + 1) {
            options.tracePersonas = Set(arguments[index + 1].split(separator: ",").map(String.init)); index += 2
        } else if argument == "--trace-seeds", arguments.indices.contains(index + 1),
                  let value = Int(arguments[index + 1]), (1...10).contains(value) {
            options.traceSeeds = value; index += 2
        } else if argument == "--trace-limit", arguments.indices.contains(index + 1),
                  let value = Int(arguments[index + 1]), (1...10_000).contains(value) {
            options.traceLimit = value; index += 2
        } else if argument == "--dose-policy" {
            options.dosePolicy = true; options.automatic = true; index += 1
        } else if argument == "--automatic" {
            options.automatic = true; index += 1
        } else if argument == "--legacy-history-projection" {
            options.legacyHistoryProjection = true; index += 1
        } else if argument == "--contrasts" {
            options.contrasts = true; index += 1
        } else {
            fputs("Argument invalide : \(argument)\n", stderr)
            exit(2)
        }
    }
    guard options.weeks <= 104, options.seeds <= 1_000 else {
        fputs("Bornes de simulation : 104 semaines et 1 000 graines maximum.\n", stderr); exit(2)
    }
    if options.dosePolicy && !arguments.contains("--weeks") { options.weeks = 24 }
    let validIDs = Set((options.dosePolicy ? dosePersonas() : referencePersonas() + (options.contrasts ? contrastPersonas() : [])).map(\.id))
    guard options.tracePersonas.isSubset(of: validIDs) else {
        fputs("Profil de trace inconnu pour ce lot.\n", stderr); exit(2)
    }
    return options
}

func deterministicIndex(
    count: Int,
    seed: UInt64,
    persona: String,
    day: Int,
    channel: Int
) -> Int {
    guard count > 1 else { return 0 }
    return min(count - 1, Int(deterministicUnit(
        seed: seed,
        persona: persona,
        day: day,
        channel: channel
    ) * Double(count)))
}

func deterministicUnit(seed: UInt64, persona: String, day: Int, channel: Int) -> Double {
    var value = seed
        ^ stableHash(persona)
        ^ UInt64(truncatingIfNeeded: day &* 0x45D9F3B)
        ^ UInt64(truncatingIfNeeded: channel &* 0x119DE1F3)
    value &+= 0x9E3779B97F4A7C15
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    value ^= value >> 31
    return Double(value >> 11) / Double(UInt64(1) << 53)
}

func stableHash(_ value: String) -> UInt64 {
    value.utf8.reduce(0xcbf29ce484222325) { hash, byte in
        (hash ^ UInt64(byte)) &* 0x100000001b3
    }
}

func isoDate(_ date: Date) -> String {
    date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
}

func percentage(_ numerator: Int, _ denominator: Int) -> String {
    guard denominator > 0 else { return "0,0 %" }
    return String(format: "%.1f %%", 100 * Double(numerator) / Double(denominator))
}

func decimal(_ value: Double) -> String {
    String(format: "%.2f", value)
}

func printReport(
    options: Options,
    personas: [Persona],
    totals: [RhythmPolicy: Metrics],
    guidedByPersona: [String: Metrics],
    wallElapsed: Duration
) {
    let projectedYears = Double(options.weeks * options.seeds * personas.count * totals.count) / 52
    print("# Simulation accélérée La Bonne Séance V2")
    print("")
    print("Projection : \(personas.count) profils × \(options.seeds) graines × \(options.weeks) semaines × \(totals.count) politiques")
    print("Graines : \(options.seedStart)...\(options.seedStart + options.seeds - 1) ; contrastes : \(options.contrasts) ; automatique : \(options.automatic)")
    print("Temps virtuel cumulé : \(decimal(projectedYears)) années-personnes-politiques")
    print("Temps de calcul réel : \(wallElapsed)")
    print("")
    print("| Politique | Séances | Séries réalisées | Dépassement moyen | Départs pressés / 100 séances | Retraits moteur / 100 | Séries abandonnées par limite stricte / 100 | Stabilité | Violations |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for policy in RhythmPolicy.allCases where totals[policy] != nil {
        let metrics = totals[policy, default: Metrics()]
        let sessions = max(1, metrics.sessionsGenerated)
        let overtimeMinutes = Double(metrics.overtimeSeconds) / 60 / Double(sessions)
        let rushed = 100 * Double(metrics.rushedStarts) / Double(sessions)
        let removed = 100 * Double(metrics.engineRemovedSets) / Double(sessions)
        let strictAbandoned = 100 * Double(metrics.strictAbandonedSets) / Double(sessions)
        let stability = percentage(metrics.retainedMovements, metrics.previousMovementCount)
        let violations = metrics.invariantViolations.values.reduce(0, +)
        print("| \(policy.rawValue) | \(metrics.sessionsGenerated) | \(percentage(metrics.confirmedSets, metrics.plannedSets)) | \(decimal(overtimeMinutes)) min | \(decimal(rushed)) | \(decimal(removed)) | \(decimal(strictAbandoned)) | \(stability) | \(violations) |")
    }
    print("")
    if !options.automatic {
    print("## Politique guidée, par profil")
    print("")
    print("| Profil | Séances générées | Terminées | Interrompues | Séries réalisées | Dépassement moyen | Progressions répétitions / charge |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    for persona in personas {
        let metrics = guidedByPersona[persona.id, default: Metrics()]
        let sessions = max(1, metrics.sessionsGenerated)
        let overtime = Double(metrics.overtimeSeconds) / 60 / Double(sessions)
        print("| \(persona.title) | \(metrics.sessionsGenerated) | \(metrics.sessionsCompleted) | \(metrics.sessionsInterrupted) | \(percentage(metrics.confirmedSets, metrics.plannedSets)) | \(decimal(overtime)) min | \(metrics.repetitionProgressions) / \(metrics.loadProgressions) |")
    }
    print("")
    }
    let strict = totals[.strictTimer, default: Metrics()]
    let free = totals[.fullyFree, default: Metrics()]
    let guided = totals[.guidedUserControlled, default: Metrics()]
    if options.dosePolicy {
        print("Comparaison locale auto_two / dose_candidate : événements déclaratifs communs, aucune victoire physiologique déduite des métriques.")
    } else if options.automatic {
        print("Trois volumes automatiques expérimentaux : aucun volume retenu par défaut. La durée estimée est une observation, jamais un quota de retrait.")
    } else if guided.invariantViolations.isEmpty,
       guided.rushedStarts == 0,
       guided.overtimeSeconds < free.overtimeSeconds,
       guided.strictAbandonedSets < strict.strictAbandonedSets {
        print("Lecture structurale : le rythme guidé mais contrôlé par l’utilisateur évite les départs forcés, réduit les dépassements face au rythme libre et évite les abandons imposés par la limite stricte. Les retraits portent uniquement sur du travail non commencé.")
    } else {
        print("Lecture structurale : aucun verdict automatique ; examiner les métriques et les hypothèses avant de choisir la politique de rythme.")
    }
    if totals.values.allSatisfy({ $0.invariantViolations.isEmpty }) {
        print("Invariants moteur : PASS — aucune dette, charge, support, matériel ou progression inventée détectée.")
    } else {
        let violations = totals.values.flatMap(\.invariantViolations).reduce(into: [String: Int]()) {
            $0[$1.key, default: 0] += $1.value
        }
        print("Invariants moteur : FAIL — \(violations)")
    }
}
