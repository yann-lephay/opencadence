import Foundation
import Testing
@_spi(AutomaticPolicyExperiment) @testable import CadenceEngine

/// Synthetic, deterministic decision bench. Never reads application or personal storage.
/// CADENCE_PUBLIC_BASELINE lets the same public recorder run against the pre-change engine.
struct AutomaticPolicyBenchTests {
    let configuration = V2EngineConfiguration.productPreview
    let now = ISO8601DateFormatter().date(from: "2026-09-07T12:00:00Z")!

    struct Scenario {
        let id: String
        let label: String
        let inventory: [V2InventoryItem]
        let supports: [String]
        let history: [V2HistoryEntry]
    }

    func scenarios() -> [Scenario] {
        let full: [V2InventoryItem] = [.init(category: "bodyweight", units: 1), .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10, 12, 16])]
        let supports = ["floor_allowed", "stable_hand_support", "stable_incline_support", "seated_support", "wall_available", "overhead_clearance", "travel_space"]
        let ids = ["supported_one_arm_row__adjustable", "dumbbell_floor_press__adjustable", "goblet_squat__adjustable", "dumbbell_romanian_deadlift__adjustable"]
        let references = ids.map { V2Reference(exerciseId: $0, loadKg: 10, targetReps: 10, progressionContext: $0) }
        func history(_ dates: [String], longRest: Bool = false) -> [V2HistoryEntry] {
            dates.map { date in
                V2HistoryEntry(endedAt: date, completedExerciseIds: ids, references: references,
                    restObservations: longRest ? ids.map { V2RestObservation(progressionContext: $0, plannedSeconds: 90, actualSeconds: 150) } : nil,
                    catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
            }
        }
        let recent = ["2026-09-01T12:00:00Z", "2026-09-03T12:00:00Z", "2026-09-05T12:00:00Z"]
        return [
            Scenario(id: "beginner", label: "Sans historique, matériel complet déclaré", inventory: full, supports: supports, history: []),
            Scenario(id: "regular", label: "Trois historiques synthétiques avec références comparables récentes", inventory: full, supports: supports, history: history(recent)),
            Scenario(id: "return90", label: "Même référence, dernière exposition il y a 90 jours", inventory: full, supports: supports, history: history(["2026-06-09T12:00:00Z"])),
            Scenario(id: "limited", label: "Un haltère fixe de 6 kg, aucune paire", inventory: [.init(category: "bodyweight", units: 1), .init(category: "fixed_dumbbell", units: 1, perUnitWeightsKg: [6])], supports: ["floor_allowed", "stable_hand_support"], history: []),
            Scenario(id: "bodyweight", label: "Sans équipement sportif, sol et mur déclarés", inventory: [.init(category: "bodyweight", units: 1)], supports: ["floor_allowed", "wall_available"], history: []),
            Scenario(id: "longRest", label: "Références récentes et trois repos de 150 s par configuration", inventory: full, supports: supports, history: history(recent, longRest: true))
        ]
    }

    func input(_ scenario: Scenario, duration: Int = 30, mode: V2SessionMode = .normal, remaining: Int? = nil,
               active: V2ActiveSession? = nil, health: Bool = false, scope: V2DeclaredScope? = nil,
               refusals: [V2Refusal] = []) -> V2SessionDecisionInput {
        .init(request: .init(durationMinutes: duration, mode: mode, remainingSeconds: remaining),
              persistentInventory: scenario.inventory, todayInventory: scenario.inventory, todaySupports: scenario.supports,
              history: scenario.history, refusals: refusals, activeSession: active,
              declaredCurrentHealthSignal: health, declaredScope: scope)
    }

    func publicDecision(_ input: V2SessionDecisionInput) -> V2SessionDecision {
        guard case .sessionDecision(let result) = CadenceEngine.decideV2(request: .sessionDecision(input, now: now), configuration: configuration) else { fatalError("Wrong result kind") }
        return result
    }

    func json<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    func inputJSON(_ value: V2SessionDecisionInput) throws -> [String: Any] {
        ["now": "2026-09-07T12:00:00Z", "request": try json(value.request),
         "persistentInventory": try json(value.persistentInventory), "todayInventory": try json(value.todayInventory),
         "todaySupports": value.todaySupports, "history": try json(value.history), "refusals": try json(value.refusals),
         "activeSession": try value.activeSession.map(json) ?? NSNull(), "declaredCurrentHealthSignal": value.declaredCurrentHealthSignal,
         "declaredScope": value.declaredScope?.rawValue as Any? ?? NSNull()]
    }

    func decisionJSON(_ value: V2SessionDecision) throws -> [String: Any] {
        ["decision": value.decision.rawValue, "mode": value.mode.rawValue, "estimatedSeconds": value.estimatedSeconds,
         "totalSets": value.plan.reduce(0) { $0 + $1.sets }, "plan": try json(value.plan), "confirmed": try json(value.confirmed),
         "coveredAnchors": value.coveredAnchors, "omittedAnchors": value.omittedAnchors, "reasons": try json(value.reasons),
         "catalogVersion": value.catalogVersion, "decisionPolicyVersion": value.decisionPolicyVersion,
         "confirmedImmutable": value.confirmedImmutable, "automaticProgression": value.automaticProgression,
         "createsDebt": value.createsDebt, "persistentInventoryChanged": value.persistentInventoryChanged]
    }

    func transitionJSON(_ value: V2ActiveTransitionDecision) throws -> [String: Any] {
        ["decision": value.decision.rawValue, "estimatedSeconds": value.estimatedSeconds,
         "plan": try json(value.plan), "removed": try json(value.removed), "confirmed": try json(value.confirmed),
         "reasons": try json(value.reasons), "confirmedImmutable": value.confirmedImmutable, "createsDebt": value.createsDebt,
         "exposedActions": value.exposedActions]
    }

    func work(_ item: V2PlanItem, sets: Int? = nil) -> V2UnstartedWork {
        .init(exerciseId: item.exerciseId, sets: sets ?? item.sets, targetReps: item.targetReps, restSeconds: item.restSeconds,
              load: item.load, sourceExerciseId: item.sourceExerciseId, referenceStatus: item.referenceStatus, progressionContext: item.progressionContext)
    }

    func transition(_ unstarted: [V2UnstartedWork], confirmed: [V2ConfirmedWork], remaining: Int = 0,
                    action: V2ActiveAction = .finishOnTime, version: String? = nil) -> V2ActiveTransitionInput {
        .init(action: action, catalogVersion: version ?? configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion,
              remainingSeconds: remaining, activeExerciseId: unstarted.first?.exerciseId, confirmed: confirmed, unstarted: unstarted)
    }

    func write(_ object: Any, name: String) throws {
        let path = ProcessInfo.processInfo.environment["LBS_AUTOMATIC_BENCH_OUTPUT"] ?? "/tmp/lbs-automatic-bench"
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            .write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    @Test("Public 20/30/45 and active decisions can be compared byte-for-byte before/after")
    func publicBaseline() throws {
        var rows: [[String: Any]] = []
        for scenario in scenarios() {
            for duration in [20, 30, 45] {
                for mode in [V2SessionMode.normal, .light, .recalibration] {
                    let request = input(scenario, duration: duration, mode: mode)
                    rows.append(["scenario": scenario.id, "input": try inputJSON(request), "output": try decisionJSON(publicDecision(request))])
                }
            }
        }
        let base = publicDecision(input(scenarios()[0]))
        let first = try #require(base.plan.first)
        let confirmed = [V2ConfirmedWork(exerciseId: first.exerciseId, sets: 1, targetReps: first.targetReps, load: first.load, progressionContext: first.progressionContext)]
        let active = V2ActiveSession(sessionId: "public-baseline-active", mode: .normal, catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion, confirmed: confirmed, unstarted: base.plan.map { work($0) })
        for remaining in [0, 120, 1_800] {
            let resumeInput = input(scenarios()[0], remaining: remaining, active: active)
            rows.append(["resumeRemainingSeconds": remaining, "input": try inputJSON(resumeInput), "output": try decisionJSON(publicDecision(resumeInput))])
            let request = transition(base.plan.map { work($0) }, confirmed: confirmed, remaining: remaining)
            guard case .activeSessionTransition(let result) = CadenceEngine.decideV2(request: .activeSessionTransition(request), configuration: configuration) else { fatalError("Wrong result") }
            rows.append(["transitionRemainingSeconds": remaining, "output": try transitionJSON(result)])
        }
        try write(rows, name: "public-baseline.json")
    }

    #if !CADENCE_PUBLIC_BASELINE
    @Test("Execute contrasted automatic hypotheses with exact inputs and protection evidence")
    func automaticMatrix() throws {
        let variants: [V2AutomaticSizingExperiment] = [.catalogMaximum, .catalogMinimum, .capAtTwo]
        var rows: [[String: Any]] = []
        var checks: [[String: Any]] = []
        func check(_ id: String, _ condition: Bool, _ observed: Any) {
            checks.append(["id": id, "pass": condition, "observed": observed])
            #expect(condition, Comment(rawValue: id))
        }
        for scenario in scenarios() {
            for mode in [V2SessionMode.normal, .light, .recalibration] {
                for variant in variants {
                    let request = input(scenario, mode: mode)
                    let result = CadenceEngineV2.decideNextSession(input: request, now: now, configuration: configuration, experimentalSizing: variant)
                    let prefix = "\(scenario.id).\(mode.rawValue).\(variant.rawValue)"
                    check(prefix + ".anchorsOnly", result.plan.allSatisfy { configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .anchor }, result.coveredAnchors)
                    let oracle = result.plan.reduce(0) { total, item in
                        let timing = configuration.catalog[item.exerciseId]!.timingSeconds
                        return total + timing.setup + timing.transition + item.sets * (timing.execution + timing.secondSide) + max(0, item.sets - 1) * item.restSeconds
                    }
                    check(prefix + ".estimateMatchesCatalogCost", result.estimatedSeconds == oracle, result.estimatedSeconds)
                    check(prefix + ".doesNotMutateInventory", !result.persistentInventoryChanged, result.persistentInventoryChanged)
                    if scenario.id == "limited" {
                        check(prefix + ".noPairInferred", result.plan.allSatisfy { $0.load?.mode != .pairEachKg }, try json(result.plan))
                    }
                    if scenario.id == "bodyweight", result.decision == .generateSession {
                        check(prefix + ".pullOmittedNotInvented", result.omittedAnchors.contains("pull") && result.plan.allSatisfy { $0.load == nil }, result.omittedAnchors)
                    }
                    if scenario.id == "return90", mode == .normal {
                        check(prefix + ".oldReferencesFlagged", result.plan.allSatisfy { $0.referenceStatus == "reconfirmation_pending" }, result.plan.map(\.referenceStatus))
                    }
                    rows.append(["scenario": scenario.id, "label": scenario.label, "variant": variant.rawValue,
                                 "volumeRuleOrigin": "experimental product hypothesis; not physiological validation",
                                 "input": try inputJSON(request), "output": try decisionJSON(result)])
                }
            }
        }
        for variant in variants {
            let scenario = scenarios()[0]
            let automatic20 = CadenceEngineV2.decideNextSession(input: input(scenario, duration: 20), now: now, configuration: configuration, experimentalSizing: variant)
            let automatic45 = CadenceEngineV2.decideNextSession(input: input(scenario, duration: 45, remaining: 0), now: now, configuration: configuration, experimentalSizing: variant)
            check("duration.\(variant).doesNotChooseOrCutPlan", automatic20 == automatic45, try decisionJSON(automatic45))
        }
        let scenario = scenarios()[0]
        let base = CadenceEngineV2.decideNextSession(input: input(scenario), now: now, configuration: configuration, experimentalSizing: .catalogMaximum)
        let first = try #require(base.plan.first)
        let confirmed = [V2ConfirmedWork(exerciseId: first.exerciseId, sets: 2, targetReps: first.targetReps, load: first.load, progressionContext: first.progressionContext)]
        let remaining = [work(first, sets: 1)] + base.plan.dropFirst().map { work($0) }
        let active = V2ActiveSession(sessionId: "synthetic-active", mode: .normal, catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion, confirmed: confirmed, unstarted: remaining)
        let restored = try JSONDecoder().decode(V2ActiveSession.self, from: JSONEncoder().encode(active))
        for variant in variants {
            let resume = CadenceEngineV2.decideNextSession(input: input(scenario, remaining: 0, active: restored), now: now, configuration: configuration, experimentalSizing: variant)
            check("resume.\(variant).confirmedImmutable", resume.confirmed == confirmed && resume.confirmedImmutable, try decisionJSON(resume))
            check("resume.\(variant).exactRemainingWork", resume.plan.map { work($0) } == remaining, try json(resume.plan))
        }
        let deadlineInput = transition(remaining, confirmed: confirmed)
        let deadline = CadenceEngineV2.reduceActiveSession(input: deadlineInput, configuration: configuration, preserveUnstartedAfterEstimate: true)
        check("deadline.noCutAtZero", deadline.plan.map { work($0) } == remaining && deadline.removed.isEmpty && deadline.confirmed == confirmed, try transitionJSON(deadline))
        let legacy = CadenceEngineV2.reduceActiveSession(input: deadlineInput, configuration: configuration)
        check("deadline.legacyStillCuts", legacy.plan.isEmpty && !legacy.removed.isEmpty && legacy.confirmed == confirmed, try transitionJSON(legacy))
        let pain = CadenceEngineV2.reduceActiveSession(input: transition(remaining, confirmed: confirmed, action: .declareHealthSignal), configuration: configuration, preserveUnstartedAfterEstimate: true)
        check("pain.stopBeforeNoCut", pain.decision == .stopCurrentMovement && pain.plan.isEmpty && pain.confirmed == confirmed && pain.loadedAlternative == nil, try transitionJSON(pain))
        let afterPain = CadenceEngineV2.reduceActiveSession(input: transition([], confirmed: confirmed), configuration: configuration, preserveUnstartedAfterEstimate: true)
        check("pain.noResurrection", afterPain.plan.isEmpty, try transitionJSON(afterPain))
        let badVersion = CadenceEngineV2.reduceActiveSession(input: transition(remaining, confirmed: confirmed, version: "other"), configuration: configuration, preserveUnstartedAfterEstimate: true)
        check("version.noBypass", badVersion.decision == .requestValidInput && badVersion.confirmed == confirmed, try transitionJSON(badVersion))
        let invalidWork = V2UnstartedWork(exerciseId: "unknown", sets: 1, targetReps: 8, restSeconds: 90, referenceStatus: "new", progressionContext: "unknown")
        let invalid = CadenceEngineV2.reduceActiveSession(input: transition([invalidWork], confirmed: confirmed), configuration: configuration, preserveUnstartedAfterEstimate: true)
        check("configuration.unknownRejected", invalid.decision == .requestValidInput && invalid.plan.isEmpty, try transitionJSON(invalid))
        for variant in variants {
            for (id, request, expected) in [
                ("health", input(scenario, health: true), V2DecisionName.stopStandardSession),
                ("scope", input(scenario, scope: .pregnancy), .blockStandardMode),
                ("negativeRemaining", input(scenario, remaining: -1), .requestValidInput)
            ] {
                let result = CadenceEngineV2.decideNextSession(input: request, now: now, configuration: configuration, experimentalSizing: variant)
                check("\(id).\(variant).protected", result.decision == expected && result.plan.isEmpty, try decisionJSON(result))
            }
            let noInventory = Scenario(id: "empty", label: "Nothing declared", inventory: [], supports: [], history: [])
            let unavailable = CadenceEngineV2.decideNextSession(input: input(noInventory), now: now, configuration: configuration, experimentalSizing: variant)
            check("equipment.\(variant).noInvention", unavailable.decision == .noCleanSession && unavailable.plan.isEmpty, try decisionJSON(unavailable))
            let source = V2EngineConfiguration.referencePreview
            let unapproved = V2EngineConfiguration(catalogVersion: source.catalogVersion, decisionPolicyVersion: source.decisionPolicyVersion, catalog: source.catalog, substitutions: source.substitutions, policy: source.policy, requiresProductApproval: true)
            let denied = CadenceEngineV2.decideNextSession(input: input(scenario), now: now, configuration: unapproved, experimentalSizing: variant)
            check("release.\(variant).gateClosed", denied.decision == .noCleanSession && denied.plan.isEmpty, try decisionJSON(denied))
            let refuse = configuration.catalog.map { V2Refusal(scope: "configuration", temporalScope: "today", exerciseId: $0.key, progressionContext: $0.value.progressionContext) }
            let refused = CadenceEngineV2.decideNextSession(input: input(scenario, remaining: 0, active: active, refusals: refuse), now: now, configuration: configuration, experimentalSizing: variant)
            check("refusal.\(variant).noRestoredWork", refused.plan.isEmpty && refused.confirmed == confirmed, try decisionJSON(refused))
        }
        let definitions = try base.plan.map { item -> [String: Any] in
            ["exerciseId": item.exerciseId, "definition": try json(configuration.catalog[item.exerciseId]!)]
        }
        try write(["status": "executed_experiment_not_activated", "origin": "synthetic fixtures; no personal data", "rows": rows,
                   "checks": checks, "exampleCatalogDefinitions": definitions,
                   "catalog": try json(configuration.catalog), "historyLimitation": "V2HistoryEntry references contain no confirmed set count; no volume training response can be inferred"], name: "automatic-matrix.json")
    }
    #endif
}
