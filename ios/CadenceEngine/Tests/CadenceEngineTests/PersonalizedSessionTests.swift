import Foundation
import Testing
@testable import CadenceEngine

struct PersonalizedSessionTests {
    let config = V2EngineConfiguration.productPreview
    let now = ISO8601DateFormatter().date(from: "2026-09-08T12:00:00Z")!
    let inventory: [V2InventoryItem] = [.init(category: "bodyweight", units: 1),
        .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10, 12])]
    let supports = ["floor_allowed", "stable_hand_support", "stable_incline_support", "seated_support", "overhead_clearance"]
    let row = "supported_one_arm_row__adjustable"
    let pull = "pull_up"

    func run(_ person: V2Personalization = .init(sessionId: "one"), history: [V2HistoryEntry] = [],
             inventory: [V2InventoryItem]? = nil, supports: [String]? = nil, active: V2ActiveSession? = nil,
             mode: V2SessionMode = .normal, duration: Int = 30, remaining: Int? = nil,
             health: Bool = false, scope: V2DeclaredScope? = nil, at: Date? = nil,
             configuration: V2EngineConfiguration? = nil) -> V2PersonalizedSessionResult {
        CadenceEngine.decidePersonalizedSession(input: .init(request: .init(durationMinutes: duration, mode: mode, remainingSeconds: remaining),
            persistentInventory: inventory ?? self.inventory, todayInventory: inventory ?? self.inventory,
            todaySupports: supports ?? self.supports, history: history, activeSession: active,
            declaredCurrentHealthSignal: health, declaredScope: scope), person: person, now: at ?? now,
            configuration: configuration ?? config, evidenceSource: .syntheticScenario)
    }
    func knowledge(_ id: String, familiar: Bool = true, sets: Int? = nil, reps: Int? = nil,
                   maximum: Bool = false, kg: Double? = nil, at: Date? = nil) -> V2MovementKnowledge {
        .init(exerciseId: id, progressionContext: config.catalog[id]!.progressionContext, familiar: familiar,
              usualSets: sets, declaredReps: reps, repetitionsAreMaximum: maximum,
              declaredLoad: kg.map { .init(mode: config.catalog[id]!.loadMode, kg: $0) },
              at: at ?? now, catalogVersion: config.catalogVersion)
    }
    func history(_ item: V2PlanItem, loads: [Double?]? = nil, reps: [Int]? = nil,
                 at: Date? = nil, skipped: Bool = false, safety: Bool = false, id: String = "event",
                 source: V2HistoryEvidenceSource = .syntheticScenario) -> V2HistoryEntry {
        let at = at ?? now.addingTimeInterval(600)
        let reps = reps ?? Array(repeating: item.targetReps, count: item.sets)
        let events = reps.enumerated().map { index, n in
            V2ConfirmedSetEvidence(eventID: "\(id)-\(index)", repetitions: n,
                loadKg: loads?[index] ?? item.load?.kg, loadOptionID: item.load?.optionID,
                completedAt: ISO8601DateFormatter().string(from: at.addingTimeInterval(Double(index))))
        }
        return .init(endedAt: ISO8601DateFormatter().string(from: at.addingTimeInterval(60)),
            // Deliberately prospective and wrong: personalization must consume facts instead.
            references: [.init(exerciseId: item.exerciseId, loadKg: 999, targetReps: 50, progressionContext: item.progressionContext)],
            confirmedWorkEvidence: [.init(exerciseId: item.exerciseId, progressionContext: item.progressionContext,
                plannedSets: item.sets, targetUnit: item.resolvedTargetUnit, confirmedSets: events,
                wasSkipped: skipped, interruptedBySafetySignal: safety, source: source)],
            catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion)
    }
    func item(_ result: V2PersonalizedSessionResult, _ id: String) throws -> V2PlanItem {
        try #require(result.decision.plan.first { $0.exerciseId == id })
    }
    func active(_ result: V2PersonalizedSessionResult, confirmed: [V2ConfirmedWork] = []) -> V2ActiveSession {
        .init(sessionId: "one", mode: .normal, catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion,
              confirmed: confirmed, unstarted: result.decision.plan.map {
            .init(exerciseId: $0.exerciseId, sets: $0.sets, targetReps: $0.targetReps, restSeconds: $0.restSeconds,
                  load: $0.load, referenceStatus: $0.referenceStatus, progressionContext: $0.progressionContext)
        })
    }

    @Test func doseUsesLocalFamiliarityAndHonorsDeclaredHabitsWithoutProbation() throws {
        let novice = run(.init(sessionId: "one", practice: .discovering))
        #expect(novice.decision.plan.count == 4)
        #expect(novice.decision.plan.allSatisfy { $0.sets == 2 })
        let familiar = knowledge(row)
        let regular = run(.init(sessionId: "one", practice: .regular, knowledge: [familiar]))
        #expect(try item(regular, row).sets == 3)
        #expect(regular.decision.plan.filter { $0.exerciseId != row }.allSatisfy { $0.sets == 2 })
        #expect(regular.decision.plan.first?.exerciseId == row)
        let habit = knowledge(row, sets: 3, reps: 10, kg: 8)
        let explicit = run(.init(sessionId: "one", practice: .occasional, knowledge: [habit]))
        #expect(try item(explicit, row).sets == 3)
        #expect(try item(explicit, row).load?.kg == 8)
        #expect(try item(explicit, row).targetReps == 10)
        let returning = run(.init(sessionId: "one", practice: .regular, returning: true, knowledge: [habit]))
        #expect(try item(returning, row).sets == 2)
        #expect(returning.knowledge.first?.usualSets == 3)
        #expect(try item(run(.init(sessionId: "two", practice: .regular, knowledge: returning.knowledge)), row).sets == 3)
    }

    @Test func unknownZeroSmallMaximumAndAssistanceCannotBecomeStrictCapacity() throws {
        let equipment: [V2InventoryItem] = [.init(category: "bodyweight", units: 1), .init(category: "pullup_bar", units: 1)]
        let support = ["floor_allowed", "pullup_clearance", "pullup_top_start_support"]
        for reps in [nil, 0, 1, 2] as [Int?] {
            let k = reps.map { [knowledge(pull, reps: $0)] } ?? []
            let result = run(.init(sessionId: "one", practice: .regular, knowledge: k), inventory: equipment, supports: support)
            #expect(!result.decision.plan.contains { $0.exerciseId == pull || $0.exerciseId == "eccentric_pull_up" })
            #expect(result.checks.contains { $0.anchor == "pull" && $0.requiredBeforeMovement })
        }
        let max = run(.init(sessionId: "one", knowledge: [knowledge(pull, reps: 8, maximum: true)]), inventory: equipment, supports: support)
        #expect(!max.decision.plan.contains { $0.exerciseId == pull })
        let usual = run(.init(sessionId: "one", knowledge: [knowledge(pull, reps: 5)]), inventory: equipment, supports: support)
        #expect(try item(usual, pull).targetReps == 5)
        let stale = run(.init(sessionId: "one", knowledge: [knowledge(pull, reps: 5, at: now.addingTimeInterval(-86400 * 60))]), inventory: equipment, supports: support)
        #expect(!stale.decision.plan.contains { $0.exerciseId == pull })
        let assisted = run(.init(sessionId: "one", knowledge: [knowledge("band_assisted_pull_up", reps: 8)]), inventory: equipment, supports: support)
        #expect(!assisted.decision.plan.contains { $0.exerciseId == pull })
    }

    @Test func firstSecondThirdSessionRetainsActualCorrectionWithoutRepeatingQuestions() throws {
        let start = run()
        let first = try item(start, row)
        let choice = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .load(.init(mode: .singleTotalKg, kg: 6)), at: now)
        let changed = run(.init(sessionId: "one", choices: [choice]))
        let selected = try item(changed, row)
        #expect(selected.load?.kg == 6 && selected.sets == first.sets)
        #expect(changed.knowledge.isEmpty) // A today's choice is not a durable level.
        let fact = history(selected)
        let second = run(.init(sessionId: "two", knowledge: changed.knowledge), history: [fact], at: now.addingTimeInterval(86400))
        let next = try item(second, row)
        #expect(next.load?.kg == 6)
        #expect(next.targetReps == selected.targetReps + 1)
        #expect(second.checks.isEmpty)
        let secondFact = history(next, at: now.addingTimeInterval(86400 + 600), id: "second")
        let third = run(.init(sessionId: "three", knowledge: second.knowledge), history: [fact, secondFact], at: now.addingTimeInterval(86400 * 2))
        #expect(try item(third, row).load?.kg == 6)
        #expect(third.checks.isEmpty)
        #expect(try item(third, row).sets == 1)
        #expect(third.decision.reasons.contains { $0.code == "recent_work_dose" })
    }

    @Test func actualBelowMinimumIsNeverClampedUp() throws {
        let equipped: [V2InventoryItem] = [.init(category: "bodyweight", units: 1), .init(category: "pullup_bar", units: 1)]
        let base = run(.init(sessionId: "one", knowledge: [knowledge(pull, reps: 5)]), inventory: equipped, supports: ["pullup_clearance"])
        let first = try item(base, pull)
        let fact = history(first, reps: [1, 1])
        let next = run(.init(sessionId: "two"), history: [fact], inventory: equipped, supports: ["pullup_clearance"], at: now.addingTimeInterval(86400))
        #expect(!next.decision.plan.contains { $0.exerciseId == pull })
        #expect(next.checks.contains { $0.exerciseId == pull })
        #expect(fact.confirmedWorkEvidence?.first?.confirmedSets.first?.repetitions == 1)
    }

    @Test func liveCorrectionPreservesConfirmedSetsAndCannotTouchRunningSet() throws {
        let start = run()
        let first = try item(start, row)
        let confirmed = V2ConfirmedWork(exerciseId: row, sets: 1, targetReps: first.targetReps,
                                       load: first.load, progressionContext: first.progressionContext)
        let remaining = V2ActiveSession(sessionId: "one", mode: .normal, catalogVersion: config.catalogVersion,
            decisionPolicyVersion: config.decisionPolicyVersion, confirmed: [confirmed], unstarted: [
                .init(exerciseId: row, sets: 1, targetReps: first.targetReps, restSeconds: first.restSeconds,
                      load: first.load, referenceStatus: "new", progressionContext: first.progressionContext)])
        let choice = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .load(.init(mode: .singleTotalKg, kg: 6)), at: now)
        let adapted = run(.init(sessionId: "one", choices: [choice]), active: remaining)
        #expect(adapted.decision.confirmed == [confirmed])
        #expect(try item(adapted, row).sets == 1)
        #expect(try item(adapted, row).load?.kg == 6)
        let busy = run(.init(sessionId: "one", choices: [choice], inProgressExerciseId: row), active: remaining)
        #expect(busy.decision.decision == .requestValidInput)
        #expect(busy.decision.confirmed == [confirmed])
        let replay = run(.init(sessionId: "two", choices: [choice]))
        #expect(replay.decision.decision == .requestValidInput)
        let resumed = run(active: active(adapted, confirmed: [confirmed]), remaining: 0)
        #expect(resumed.decision.plan == adapted.decision.plan)
    }

    @Test func quantityScopeDoesNotConfuseTodayWithUsual() throws {
        let habit = knowledge(row, sets: 3)
        let today = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(2), at: now)
        let reduced = run(.init(sessionId: "one", knowledge: [habit], choices: [today]))
        #expect(try item(reduced, row).sets == 2)
        #expect(try item(run(.init(sessionId: "two", knowledge: reduced.knowledge)), row).sets == 3)
        let usual = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(2), scope: .usual, at: now)
        let persisted = run(.init(sessionId: "one", knowledge: [habit], choices: [usual]))
        #expect(try item(run(.init(sessionId: "two", knowledge: persisted.knowledge)), row).sets == 2)
    }

    @Test func difficultyAndQuantityAreSeparateAndImpossibleLoadsAreRejected() throws {
        let habit = knowledge(row, sets: 3, reps: 10, kg: 8)
        let change = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .difficultyTooHigh, at: now)
        let eased = run(.init(sessionId: "one", knowledge: [habit], choices: [change]))
        #expect(try item(eased, row).load?.kg == 6)
        #expect(try item(eased, row).sets == 3)
        #expect(eased.knowledge.first?.declaredLoad?.kg == 8)
        let invalid = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .load(.init(mode: .singleTotalKg, kg: 5)), at: now)
        #expect(run(.init(sessionId: "one", choices: [invalid])).decision.decision == .requestValidInput)
        let wrongUnit = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .load(.init(mode: .pairEachKg, kg: 6)), at: now)
        #expect(run(.init(sessionId: "one", choices: [wrongUnit])).decision.decision == .requestValidInput)
    }

    @Test func durationCoverageAndSafetyAreIndependentOfDose() throws {
        let short = run(duration: 20, remaining: 0), long = run(duration: 45)
        #expect(short == long)
        #expect(short.coverage.missingPrimary.isEmpty)
        #expect(Set(short.coverage.primary).isSuperset(of: ["chest", "back", "quadriceps", "glutes", "hamstrings"]))
        let bridge = V2SessionChoice(sessionId: "one", exerciseId: "dumbbell_romanian_deadlift__adjustable", choice: .variant("glute_bridge"), at: now)
        let partial = run(.init(sessionId: "one", choices: [bridge]))
        #expect(partial.decision.coveredAnchors.count == 4)
        #expect(partial.coverage.missingPrimary.contains("hamstrings"))
        #expect(!partial.decision.createsDebt)
        #expect(run(health: true).decision.decision == .stopStandardSession)
        #expect(run(scope: .pregnancy).decision.decision == .blockStandardMode)
        #expect(run(scope: .postpartum).decision.decision == .blockStandardMode)
        #expect(run(remaining: -1).decision.decision == .requestValidInput)
        #expect(!run(configuration: .releaseV2).decision.plan.isEmpty)
    }

    @Test func staleProspectiveMixedAndDuplicatedHistoryCannotInventProgress() throws {
        let first = try item(run(), row)
        let old = history(first, at: now.addingTimeInterval(-86400 * 90))
        let returned = run(history: [old])
        #expect(try item(returned, row).load == first.load)
        #expect(try item(returned, row).targetReps == first.targetReps)
        #expect(try item(returned, row).referenceStatus == "reconfirmation_pending")
        let foreign = history(first, loads: [8, 8], source: .nativeConfirmed)
        let ignored = run(history: [foreign], at: now.addingTimeInterval(86400))
        #expect(try item(ignored, row).load == first.load)
        let mixed = history(first, loads: [8, 6])
        let corrected = run(history: [mixed], at: now.addingTimeInterval(86400))
        #expect(try item(corrected, row).load?.kg == 6)
        #expect(try item(corrected, row).targetReps == first.targetReps)
        let high = V2PlanItem(exerciseId: row, sets: 2, targetReps: config.catalog[row]!.repRange.max,
            restSeconds: first.restSeconds, load: first.load, referenceStatus: "observed", progressionContext: row)
        let ceiling = history(high)
        let duplicate = run(history: [ceiling, ceiling], at: now.addingTimeInterval(86400))
        #expect(try item(duplicate, row).load == first.load)
    }

    @Test func serializedKnowledgePreservesUnknownAndZeroAndSessionScope() throws {
        let value = V2Personalization(sessionId: "one", practice: .regular, returning: true,
            knowledge: [knowledge(pull, reps: 0)], choices: [.init(sessionId: "one", exerciseId: row, choice: .sets(2), at: now)])
        #expect(try JSONDecoder().decode(V2Personalization.self, from: JSONEncoder().encode(value)) == value)
    }

    @Test func volumePreferenceDoesNotRefreshOldCapacity() throws {
        let old = knowledge(pull, sets: 2, reps: 8, at: now.addingTimeInterval(-86400 * 60))
        // A fresh volume preference may be supplied without renewing the old performance statement.
        var k = old
        k.usualSets = 3
        k.preferenceUpdatedAt = now
        let equipment: [V2InventoryItem] = [.init(category: "bodyweight", units: 1), .init(category: "pullup_bar", units: 1)]
        let result = run(.init(sessionId: "one", practice: .regular, knowledge: [k]), inventory: equipment, supports: ["pullup_clearance"])
        #expect(!result.decision.plan.contains { $0.exerciseId == pull })
        let habit = knowledge(row, sets: 2, reps: 8, kg: 6, at: now.addingTimeInterval(-86400 * 60))
        let choice = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(3), scope: .usual, at: now)
        let updated = run(.init(sessionId: "one", knowledge: [habit], choices: [choice]))
        #expect(updated.knowledge.first?.at == habit.at)
        #expect(updated.knowledge.first?.preferenceUpdatedAt == now)
    }

    @Test func activeCoverageIncludesFinishedMovementAndSetsMeanTotal() throws {
        let base = run()
        let push = try item(base, "dumbbell_floor_press__adjustable")
        let finished = V2ConfirmedWork(exerciseId: push.exerciseId, sets: push.sets,
            targetReps: push.targetReps, load: push.load, progressionContext: push.progressionContext)
        let all = active(base)
        let remaining = V2ActiveSession(sessionId: "one", mode: .normal, catalogVersion: config.catalogVersion,
            decisionPolicyVersion: config.decisionPolicyVersion, confirmed: [finished],
            unstarted: all.unstarted.filter { $0.exerciseId != push.exerciseId })
        let resumed = run(active: remaining)
        #expect(resumed.coverage.primary.contains("chest"))
        #expect(!resumed.coverage.missingPrimary.contains("chest"))
        #expect(resumed.decision.confirmed == [finished])
        #expect(!resumed.decision.plan.contains { $0.exerciseId == push.exerciseId })
        let one = V2ConfirmedWork(exerciseId: row, sets: 1, progressionContext: row)
        let ongoing = V2ActiveSession(sessionId: "one", mode: .normal, catalogVersion: config.catalogVersion,
            decisionPolicyVersion: config.decisionPolicyVersion, confirmed: [one], unstarted: all.unstarted.filter { $0.exerciseId == row })
        let extra = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(3), at: now)
        #expect(try item(run(.init(sessionId: "one", choices: [extra]), active: ongoing), row).sets == 2)
        let enough = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(1), at: now)
        let ended = run(.init(sessionId: "one", choices: [enough]), active: ongoing)
        #expect(ended.decision.plan.isEmpty && ended.decision.confirmed == [one])
    }

    @Test func changingVariantNeverTransfersLoadOrCertifiesCapacity() throws {
        let change = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .variant("seated_band_row"), at: now)
        let equipment = inventory + [.init(category: "resistance_band", units: 1, optionIDs: ["red"])]
        let changed = run(.init(sessionId: "one", knowledge: [knowledge(row, sets: 3, reps: 12, kg: 10)], choices: [change]),
            inventory: equipment, supports: supports + ["band_around_feet_allowed"])
        if let band = changed.decision.plan.first(where: { $0.exerciseId == "seated_band_row" }) {
            #expect(band.load?.kg == nil && band.load?.optionID == "red")
            #expect(band.sets == 2)
            #expect(changed.knowledge.allSatisfy { $0.exerciseId != "seated_band_row" })
        } else { Issue.record("Compatible band variant should be selected") }
        let strict = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .variant(pull), at: now)
        let pending = run(.init(sessionId: "one", choices: [strict]), inventory: inventory + [.init(category: "pullup_bar", units: 1)],
            supports: supports + ["pullup_clearance"])
        #expect(!pending.decision.plan.contains { $0.exerciseId == pull })
        #expect(pending.checks.contains { $0.exerciseId == pull && $0.requiredBeforeMovement })
    }

    @Test func inabilityIsRememberedAsAReportAndCanBeRevised() throws {
        let cannot = V2SessionChoice(sessionId: "one", exerciseId: "incline_push_up", choice: .cannotPerform, at: now)
        let report = run(.init(sessionId: "one", choices: [cannot]), inventory: [.init(category: "bodyweight", units: 1)])
        let saved = try #require(report.knowledge.first { $0.exerciseId == "incline_push_up" })
        #expect(saved.reportedUnableAt == now && !saved.unavailable)
        let next = run(.init(sessionId: "two", knowledge: report.knowledge), inventory: [.init(category: "bodyweight", units: 1)], at: now.addingTimeInterval(86400))
        #expect(!next.decision.plan.contains { $0.exerciseId == "incline_push_up" })
        var revised = saved
        revised.declaredReps = 8
        revised.at = now.addingTimeInterval(86400)
        let retry = run(.init(sessionId: "two", knowledge: [revised]), inventory: [.init(category: "bodyweight", units: 1)], at: revised.at)
        #expect(retry.decision.plan.contains { $0.exerciseId == "incline_push_up" })
    }

    @Test func increasingDoseHoldsDifficultyAndPartialWorkDoesNotMeanFatigue() throws {
        let first = try item(run(), row)
        let confirmed = history(first, loads: [6, 6])
        let later = now.addingTimeInterval(86400)
        let regular = run(.init(sessionId: "two", practice: .regular), history: [confirmed], at: later)
        let target = try item(regular, row)
        #expect(target.sets == 3 && target.targetReps == first.targetReps && target.load?.kg == 6)
        let partial = history(first, reps: [first.targetReps], skipped: true)
        let kept = run(.init(sessionId: "two"), history: [partial], at: later)
        #expect(try item(kept, row).sets == 2)
        #expect(try item(kept, row).targetReps == first.targetReps)
    }
    @Test func repeatedGapsHoldRepetitionsWithoutInventingEffort() throws {
        let first = try item(run(), row)
        func fact(_ days: Int, target: Int? = 9, kg: Double = 4, skipped: Bool = false, id: String? = nil) -> V2HistoryEntry {
            let at = now.addingTimeInterval(Double(-days * 86400))
            return .init(endedAt: at.ISO8601Format(), confirmedWorkEvidence: [.init(exerciseId: row,
                progressionContext: first.progressionContext, plannedSets: 2, targetUnit: .repetitions,
                confirmedSets: (0..<2).map { .init(eventID: "\(id ?? String(days))-\($0)", repetitions: 8,
                    loadKg: kg, completedAt: at.ISO8601Format(), prescribedRepetitions: target) },
                wasSkipped: skipped, interruptedBySafetySignal: false, source: .syntheticScenario)],
                catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion)
        }
        let gaps = [fact(2), fact(1)]
        let held = run(history: gaps)
        #expect(try item(held, row).targetReps == 8)
        #expect(held.checks.contains { $0.exerciseId == row && !$0.requiredBeforeMovement })
        let next = run(history: gaps + [fact(0, target: 8)])
        #expect(try item(next, row).targetReps == 8)
        #expect(!next.checks.contains { $0.reason == "repeated_repetitions_gap" })
        for history in [[fact(2, target: nil), fact(1, target: nil)], [fact(2, kg: 6), fact(1)],
                        [fact(2, skipped: true), fact(1)], [fact(1), fact(1)]] {
            #expect(!run(history: history).checks.contains { $0.reason == "repeated_repetitions_gap" })
        }
        let keep = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .holdRepetitions(8), scope: .usual, at: now)
        let chosen = run(.init(sessionId: "one", choices: [keep]), history: gaps)
        #expect(chosen.knowledge.first?.preferredReps == 8)
        #expect(chosen.knowledge.first?.declaredReps == nil)
        #expect(try item(run(.init(sessionId: "two", knowledge: chosen.knowledge), history: gaps), row).targetReps == 8)
        let resume = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .resumeRepetitionProgression, scope: .usual, at: now)
        let released = run(.init(sessionId: "one", knowledge: chosen.knowledge, choices: [resume]), history: gaps)
        #expect(released.knowledge.first?.preferredReps == nil)
        #expect(try item(run(.init(sessionId: "two", knowledge: released.knowledge), history: gaps, at: now.addingTimeInterval(86400 * 3)), row).targetReps == 9)
        let heavier = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .load(.init(mode: .singleTotalKg, kg: 8)), at: now)
        let changed = run(.init(sessionId: "one", choices: [heavier]), history: [fact(2, kg: 6), fact(1, kg: 6)])
        let other = V2SessionChoice(sessionId: "one", exerciseId: "dumbbell_floor_press__adjustable", choice: .sets(3), at: now)
        let unrelated = run(.init(sessionId: "one", choices: [other]), history: [fact(2, kg: 6), fact(1, kg: 6)], active: active(changed))
        #expect(try item(unrelated, row).load?.kg == 8)
        #expect(!unrelated.checks.contains { $0.exerciseId == row })
        let later = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .deferRepetitionReview, at: now)
        let deferred = run(.init(sessionId: "one", choices: [later]), history: gaps)
        let after = run(.init(sessionId: "two", knowledge: deferred.knowledge), history: gaps)
        #expect(try item(after, row).targetReps == 8)
        #expect(!after.checks.contains { $0.reason == "repeated_repetitions_gap" })
    }

}

extension PersonalizedSessionTests {
    @Test func rotationIsStableOnPrepareAndDeduplicatesActualSessions() throws {
        let first = run()
        let rowPlan = try item(first, row)
        let fact = history(rowPlan, at: now.addingTimeInterval(-86400), id: "rotation")
        let second = run(history: [fact])
        #expect(second.blocks != first.blocks)
        #expect(second == run(history: [fact]))
        #expect(second == run(history: [fact, fact]))
        let partial = history(rowPlan, reps: [8], at: now.addingTimeInterval(-86400))
        #expect(run(history: [partial]).blocks.first == first.blocks.first)
        for block in second.blocks where block.count == 2 {
            let a = try #require(config.catalog[block[0]])
            let b = try #require(config.catalog[block[1]])
            #expect(Set(a.primaryContributions).isDisjoint(with: b.primaryContributions))
        }
    }
    @Test func recentDoseIsLocalExplicitAndDoesNotCountExercisesAsSessions() throws {
        let base = run(.init(sessionId: "one", practice: .regular, knowledge: [knowledge(row, sets: 3)]))
        let rowPlan = try item(base, row)
        let yesterday = history(rowPlan, at: now.addingTimeInterval(-86400), id: "yesterday")
        let before = history(rowPlan, at: now.addingTimeInterval(-86400 * 2 + 600), id: "before")
        let person = V2Personalization(sessionId: "one", practice: .regular, knowledge: [knowledge(row, sets: 3)])
        #expect(try item(run(person, history: [yesterday, before]), row).sets == 2)
        #expect(try item(run(person, history: [yesterday, yesterday]), row).sets == 3)
        let sameSession = history(rowPlan, at: now.addingTimeInterval(-86400), id: "other-work-same-session")
        #expect(try item(run(person, history: [yesterday, sameSession]), row).sets == 3)
        let chosen = V2SessionChoice(sessionId: "one", exerciseId: row, choice: .sets(3), at: now)
        #expect(try item(run(.init(sessionId: "one", practice: .regular, choices: [chosen]), history: [yesterday, before]), row).sets == 3)
        #expect(try item(run(person, history: [yesterday, before], at: now.addingTimeInterval(86400 * 3)), row).sets == 3)
    }
}
