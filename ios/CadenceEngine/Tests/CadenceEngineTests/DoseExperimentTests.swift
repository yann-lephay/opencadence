import Foundation
import Testing
@_spi(AutomaticPolicyExperiment) @testable import CadenceEngine

/// Product-policy experiments on synthetic facts, not physiological validation.
struct DoseExperimentTests {
    let bench = AutomaticPolicyBenchTests()
    var configuration: V2EngineConfiguration { bench.configuration }
    var now: Date { bench.now }
    var empty: AutomaticPolicyBenchTests.Scenario { bench.scenarios()[0] }

    func run(_ scenario: AutomaticPolicyBenchTests.Scenario? = nil, memory: [V2DoseMemory] = [],
             feedback: [V2DoseFeedback] = [], mode: V2SessionMode = .normal, duration: Int = 30) -> V2DoseExperimentResult {
        CadenceEngine.decideDoseExperiment(input: bench.input(scenario ?? empty, duration: duration, mode: mode),
            now: now, configuration: configuration, memory: memory, feedback: feedback)
    }
    func response(_ item: V2PlanItem, _ action: V2DoseAction, at: Date? = nil, version: String? = nil) -> V2DoseFeedback {
        .init(progressionContext: item.progressionContext, action: action, at: at ?? now, source: .syntheticScenario,
              catalogVersion: version ?? configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion,
              historicalSets: action == .preferHistorical ? 3 : nil)
    }
    func stored(_ item: V2PlanItem, ordinary: Int, version: String? = nil) -> V2DoseMemory {
        .init(ordinarySets: ordinary, lastPlan: item, at: now.addingTimeInterval(-86400), preferenceSource: .syntheticScenario,
              catalogVersion: version ?? configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
    }
    func history(_ item: V2PlanItem, sets: Int, days: [Int] = [6, 3], complete: Bool = true,
                 version: String? = nil, differentLoad: Bool = false, differentReps: Bool = false,
                 evidenceSource: V2HistoryEvidenceSource = .syntheticScenario, staleSets: Bool = false, duplicateIDs: Bool = false) -> AutomaticPolicyBenchTests.Scenario {
        let entries = days.enumerated().map { index, day in
            let date = ISO8601DateFormatter().string(from: now.addingTimeInterval(Double(-day * 86400)))
            let evidence = V2ConfirmedWorkEvidence(exerciseId: item.exerciseId, progressionContext: item.progressionContext,
                plannedSets: sets, targetUnit: item.resolvedTargetUnit,
                confirmedSets: (0..<(complete ? sets : max(0, sets - 1))).map { n in
                    .init(eventID: "synthetic-\(duplicateIDs ? 0 : index)-\(n)", repetitions: item.targetReps + (differentReps && index == 1 ? 1 : 0),
                          loadKg: differentLoad && index == 1 ? 999 : item.load?.kg,
                          loadOptionID: item.load?.optionID, completedAt: staleSets ? "2026-06-01T12:00:00Z" : date)
                }, wasSkipped: false, interruptedBySafetySignal: false, source: evidenceSource)
            return V2HistoryEntry(endedAt: date, completedExerciseIds: complete ? [item.exerciseId] : [],
                references: [.init(exerciseId: item.exerciseId, loadKg: item.load?.kg, targetReps: item.targetReps,
                                  progressionContext: item.progressionContext)], confirmedWorkEvidence: [evidence],
                catalogVersion: version ?? configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
        }
        return .init(id: "dose-facts", label: "Synthetic completed volume", inventory: empty.inventory, supports: empty.supports, history: entries)
    }
    func selected(_ result: V2DoseExperimentResult, _ item: V2PlanItem) throws -> V2PlanItem {
        try #require(result.decision.plan.first { $0.progressionContext == item.progressionContext })
    }

    @Test func factsDoNotSilentlyBecomePreferences() throws {
        let base = run()
        #expect(!base.decision.plan.isEmpty)
        #expect(base.decision.plan.allSatisfy { $0.sets == 2 })
        let item = try #require(base.decision.plan.first)
        for sets in [1, 3] {
            let result = run(history(item, sets: sets))
            #expect(try selected(result, item).sets == 2)
        }
        let unproven = V2DoseMemory(ordinarySets: 3, lastPlan: item, at: now.addingTimeInterval(-86400),
            preferenceSource: nil, catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
        #expect(try selected(run(memory: [unproven]), item).sets == 2)
        for (sets, load) in [(0, item.load), (3, Optional(V2Load(mode: item.load?.mode ?? .singleTotalKg, kg: 999)))] {
            let invalid = V2PlanItem(exerciseId: item.exerciseId, sets: sets, targetReps: item.targetReps,
                restSeconds: item.restSeconds, load: load, referenceStatus: item.referenceStatus,
                progressionContext: item.progressionContext, targetUnit: item.targetUnit)
            #expect(try selected(run(memory: [stored(invalid, ordinary: 3)]), item).sets == 2)
        }
    }

    @Test func historicalAdoptionNeedsCurrentChoiceAndTwoComparableCompleteExposures() throws {
        let item = try #require(run().decision.plan.first)
        let previous = stored(item, ordinary: 2)
        let choice = response(item, .preferHistorical)
        let accepted = run(history(item, sets: 3), memory: [previous], feedback: [choice])
        let plan = try selected(accepted, item)
        #expect(plan.sets == 3)
        #expect(plan.targetReps == item.targetReps && plan.load == item.load && plan.exerciseId == item.exerciseId)
        #expect(accepted.memory.first { $0.lastPlan.progressionContext == item.progressionContext }?.ordinarySets == 3)
        for invalid in [history(item, sets: 3, days: [3]), history(item, sets: 3, days: [40, 35]),
                        history(item, sets: 3, complete: false), history(item, sets: 3, version: "old"),
                        history(item, sets: 3, differentLoad: true), history(item, sets: 3, differentReps: true),
                        history(item, sets: 3, evidenceSource: .nativeConfirmed), history(item, sets: 3, staleSets: true), history(item, sets: 3, duplicateIDs: true)] {
            #expect(try selected(run(invalid, memory: [previous], feedback: [choice]), item).sets == 2)
        }
        for bad in [response(item, .preferHistorical, at: now.addingTimeInterval(-1)),
                    response(item, .preferHistorical, at: now.addingTimeInterval(1)),
                    response(item, .preferHistorical, version: "old")] {
            #expect(try selected(run(history(item, sets: 3), memory: [previous], feedback: [bad]), item).sets == 2)
        }
        let deferred = run(history(item, sets: 3), feedback: [choice])
        #expect(try selected(deferred, item).sets == 2)
    }

    @Test func discoveryIsTemporaryAndReturningWithoutChoiceIsNotDiscovery() throws {
        let base = run()
        let item = try #require(base.decision.plan.first)
        let discovery = run(memory: base.memory, feedback: [response(item, .discover)])
        #expect(try selected(discovery, item).sets == 1)
        #expect(discovery.memory.first { $0.lastPlan.progressionContext == item.progressionContext }?.ordinarySets == 2)
        let next = run(memory: discovery.memory)
        let resumed = try selected(next, item)
        #expect(resumed.sets == 2)
        #expect(resumed.targetReps == item.targetReps && resumed.load == item.load)
        let old = history(item, sets: 3, days: [90])
        #expect(try selected(run(old), item).sets == 2)
        #expect(try selected(run(old, mode: .recalibration), item).sets == 1)
    }

    @Test func volumeAndInitialDifficultyHaveDifferentConsequences() throws {
        let base = run(bench.scenarios()[1])
        let item = try #require(base.decision.plan.first)
        let reduced = run(bench.scenarios()[1], memory: base.memory, feedback: [response(item, .volumeTooHigh)])
        #expect(try selected(reduced, item).sets == max(1, item.sets - 1))
        #expect(try selected(run(bench.scenarios()[1], memory: reduced.memory), item).sets == 1)
        for other in base.decision.plan where other.progressionContext != item.progressionContext {
            #expect(try selected(reduced, other).sets == other.sets)
        }
        let difficult = run(bench.scenarios()[1], memory: base.memory, feedback: [response(item, .difficultyTooHigh)])
        let eased = try selected(difficult, item)
        #expect(eased.sets == item.sets)
        #expect(eased.targetReps < item.targetReps || (eased.load?.kg ?? 0) < (item.load?.kg ?? 0))
        let easy = run(bench.scenarios()[1], memory: base.memory, feedback: [response(item, .difficultyTooLow)])
        #expect(try selected(easy, item).sets == item.sets)
    }

    @Test func explicitOrdinaryIncreasePreservesDifficultyOrDefers() throws {
        let item = try #require(run().decision.plan.first)
        let one = V2PlanItem(exerciseId: item.exerciseId, sourceExerciseId: item.sourceExerciseId, sets: 1,
            targetReps: item.targetReps, restSeconds: item.restSeconds, load: item.load,
            referenceStatus: item.referenceStatus, progressionContext: item.progressionContext, targetUnit: item.targetUnit)
        let increased = run(memory: [stored(one, ordinary: 1)], feedback: [response(item, .preferOrdinary)])
        let result = try selected(increased, item)
        #expect(result.sets == 2 && result.targetReps == one.targetReps && result.load == one.load)
        let invalid = run(memory: [stored(one, ordinary: 1, version: "old")], feedback: [response(item, .preferHistorical)])
        #expect(try selected(invalid, item).sets == 2)
    }

    @Test func staleReturnDoesNotActivateAnUnperformedNextLoad() throws {
        let id = "supported_one_arm_row__adjustable"
        let date = "2026-06-09T12:00:00Z"
        func scenario(confirmedKg: Double?) -> AutomaticPolicyBenchTests.Scenario {
            let evidence = confirmedKg.map { kg in
                V2ConfirmedWorkEvidence(exerciseId: id, progressionContext: id, plannedSets: 2, targetUnit: .repetitions,
                    confirmedSets: (0..<2).map { .init(eventID: "old-return-\($0)", repetitions: kg == 6 ? 12 : 8,
                                                    loadKg: kg, completedAt: date) },
                    wasSkipped: false, interruptedBySafetySignal: false, source: .syntheticScenario)
            }
            return .init(id: "stale-unperformed-load", label: "Synthetic old work and prospective reference", inventory: empty.inventory,
                supports: empty.supports, history: [.init(endedAt: date, completedExerciseIds: [id],
                    references: [.init(exerciseId: id, loadKg: 8, targetReps: 8, progressionContext: id)],
                    confirmedWorkEvidence: evidence.map { [$0] }, catalogVersion: configuration.catalogVersion,
                    decisionPolicyVersion: configuration.decisionPolicyVersion)])
        }
        // Lexicographic 12:00+02 sorts after 11:00Z, but is one hour older.
        let offsetHistory = [("2026-06-09T12:00:00+02:00", 6.0), ("2026-06-09T11:00:00Z", 8.0)].map { date, kg in
            V2HistoryEntry(endedAt: date, completedExerciseIds: [id],
                references: [.init(exerciseId: id, loadKg: 10, targetReps: 8, progressionContext: id)],
                confirmedWorkEvidence: [.init(exerciseId: id, progressionContext: id, plannedSets: 2, targetUnit: .repetitions,
                    confirmedSets: (0..<2).map { .init(eventID: "offset-\(kg)-\($0)", repetitions: 12, loadKg: kg, completedAt: date) },
                    wasSkipped: false, interruptedBySafetySignal: false, source: .syntheticScenario)],
                catalogVersion: configuration.catalogVersion, decisionPolicyVersion: configuration.decisionPolicyVersion)
        }
        let offsets = AutomaticPolicyBenchTests.Scenario(id: "offset-order", label: "Chronological order across offsets",
            inventory: empty.inventory, supports: empty.supports, history: offsetHistory)
        let offsetInput = bench.input(offsets)
        let offsetDecisions = [run(offsets).decision,
            CadenceEngineV2.decideNextSession(input: offsetInput, now: now, configuration: configuration, experimentalSizing: .capAtTwo)]
        for decision in offsetDecisions {
            let plan = try #require(decision.plan.first { $0.progressionContext == id })
            #expect(plan.load?.kg == 8 && plan.targetReps == 12)
            #expect(plan.referenceStatus == "reconfirmation_pending")
        }
        for (confirmedKg, expectedKg, expectedReps) in [(Optional(6.0), 6.0, 12), (Optional(8.0), 8.0, 8), (nil, 8.0, 8)] {
            let input = bench.input(scenario(confirmedKg: confirmedKg))
            let candidate = CadenceEngine.decideDoseExperiment(input: input, now: now, configuration: configuration).decision
            let baseline = CadenceEngineV2.decideNextSession(input: input, now: now, configuration: configuration, experimentalSizing: .capAtTwo)
            for result in [candidate, baseline] {
                let plan = try #require(result.plan.first { $0.progressionContext == id })
                #expect(plan.load?.kg == expectedKg && plan.targetReps == expectedReps)
                #expect(plan.referenceStatus == "reconfirmation_pending")
                #expect(plan.sets == 2)
            }
            let legacy = try #require(bench.publicDecision(input).plan.first { $0.progressionContext == id })
            #expect(legacy.load?.kg == 8 && legacy.targetReps == 8)
        }
    }

    @Test func durationDeterminismAndSafetyRemainIndependentOfDoseChoices() throws {
        let base = run()
        let item = try #require(base.decision.plan.first)
        let feedback = [response(item, .volumeTooHigh)]
        let a = run(memory: base.memory, feedback: feedback, duration: 20)
        let b = run(memory: base.memory, feedback: feedback, duration: 45)
        #expect(a.decision == b.decision && a.memory == b.memory)
        #expect(a.decision == run(memory: base.memory, feedback: feedback, duration: 20).decision)
        for request in [bench.input(empty, health: true), bench.input(empty, scope: .pregnancy), bench.input(empty, remaining: -1)] {
            let experimental = CadenceEngine.decideDoseExperiment(input: request, now: now, configuration: configuration,
                memory: base.memory, feedback: feedback)
            #expect(experimental.decision.decision == bench.publicDecision(request).decision)
            #expect(experimental.decision.plan.isEmpty)
        }
        let confirmed = [V2ConfirmedWork(exerciseId: item.exerciseId, sets: 1, targetReps: item.targetReps,
                                        load: item.load, progressionContext: item.progressionContext)]
        let work = base.decision.plan.map { bench.work($0) }
        let active = V2ActiveSession(sessionId: "synthetic-dose-active", mode: .normal, catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion, confirmed: confirmed, unstarted: work)
        let resumed = CadenceEngine.decideDoseExperiment(input: bench.input(empty, remaining: 0, active: active),
            now: now, configuration: configuration, memory: base.memory, feedback: feedback)
        #expect(resumed.decision.confirmed == confirmed)
        #expect(resumed.decision.plan.map { bench.work($0) } == work)
    }
}
