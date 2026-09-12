import Foundation

public extension CadenceEngine {
    static func personalizationLoads(exerciseId: String, inventory: [V2InventoryItem], configuration: V2EngineConfiguration) -> [V2Load] {
        guard let exercise = configuration.catalog[exerciseId] else { return [] }
        return PersonalizedSession.loads(exercise, inventory)
    }

    /// Public engine API. No UI, storage migration or legacy dispatcher activation is implicit.
    static func decidePersonalizedSession(
        input: V2SessionDecisionInput, person: V2Personalization, now: Date,
        configuration: V2EngineConfiguration, evidenceSource: V2HistoryEvidenceSource = .nativeConfirmed
    ) -> V2PersonalizedSessionResult {
        PersonalizedSession.decide(input, person, now, configuration, evidenceSource)
    }
}

enum PersonalizedSession {
    static let version = "first-sessions-1"
    typealias Engine = CadenceEngineV2
    struct Fact {
        let work: V2ConfirmedWorkEvidence
        let at: Date
        let sessionAt: Date
        let reps: Int
        let load: V2Load?
        let complete: Bool
    }

    static func decide(_ input: V2SessionDecisionInput, _ person: V2Personalization, _ now: Date,
                       _ config: V2EngineConfiguration, _ source: V2HistoryEvidenceSource) -> V2PersonalizedSessionResult {
        let mode = input.request.mode ?? .normal
        var notes: [V2Reason] = []
        func note(_ code: String, _ message: String, source: String = "user") {
            notes.append(.init(code: code, scope: "session", source: source, message: message, decisionPolicyVersion: version))
        }
        func stop(_ decision: V2DecisionName, _ code: String) -> V2PersonalizedSessionResult {
            note(code, code, source: "input")
            return result([], decision: decision, input: input, person: person, config: config,
                          notes: notes, knowledge: person.knowledge)
        }
        // Same input/scope guards as the existing dispatcher, with no duration budget.
        guard Engine.inventoryIsCoherent(input.todayInventory), Engine.inventoryIsCoherent(input.persistentInventory),
              input.request.remainingSeconds.map({ $0 >= 0 }) ?? true,
              input.history.allSatisfy({ Engine.parseDate($0.endedAt).map { $0 <= now } ?? false }),
              !person.sessionId.isEmpty else { return stop(.requestValidInput, "invalid_input") }
        if input.declaredCurrentHealthSignal { return stop(.stopStandardSession, "safety_stop_session") }
        if input.declaredScope != nil { return stop(.blockStandardMode, "standard_mode_outside_v2_scope") }
        if let active = input.activeSession {
            guard active.catalogVersion == config.catalogVersion, active.decisionPolicyVersion == config.decisionPolicyVersion,
                  active.sessionId == person.sessionId,
                  Set(active.unstarted.map(\.exerciseId)).count == active.unstarted.count,
                  active.confirmed.allSatisfy({ $0.sets > 0 && config.catalog[$0.exerciseId]?.progressionContext == $0.progressionContext }),
                  Set(active.unstarted.compactMap { config.catalog[$0.exerciseId]?.anchor }).count == active.unstarted.count,
                  active.unstarted.allSatisfy({ work in
                      Engine.plannedWorkIsCoherent(work, configuration: config)
                          && config.catalog[work.exerciseId]?.resolvedSelectionRole == .anchor
                  }) else { return stop(.requestValidInput, "active_session_version_or_work_incompatible") }
        } else if person.inProgressExerciseId != nil {
            return stop(.requestValidInput, "running_set_requires_active_session")
        }
        // One direct decision per source movement per call avoids ambiguous command ordering.
        guard Set(person.choices.map(\.exerciseId)).count == person.choices.count,
              person.choices.allSatisfy({ $0.sessionId == person.sessionId && $0.at <= now
                  && config.catalog[$0.exerciseId] != nil && $0.exerciseId != person.inProgressExerciseId }) else {
            return stop(.requestValidInput, "invalid_or_running_set_choice")
        }
        var knowledge: [String: V2MovementKnowledge] = [:]
        for record in person.knowledge.sorted(by: { $0.at < $1.at }) {
            guard let exercise = config.catalog[record.exerciseId], record.catalogVersion == config.catalogVersion,
                  exercise.progressionContext == record.progressionContext, record.at <= now,
                  record.reportedUnableAt.map({ $0 <= now }) ?? true,
                  record.preferenceUpdatedAt.map({ $0 <= now }) ?? true,
                  record.repetitionReviewAt.map({ $0 <= now }) ?? true,
                  record.repetitionHoldReleasedAt.map({ $0 <= now }) ?? true,
                  record.preferredReps.map({ (exercise.repRange.min...exercise.repRange.max).contains($0) }) ?? true,
                  record.usualSets.map({ (exercise.sets.min...exercise.sets.max).contains($0) }) ?? true,
                  record.declaredReps.map({ $0 >= 0 }) ?? true else {
                note("knowledge_ignored", "Un ancien repère incompatible n'a pas été utilisé."); continue
            }
            if knowledge[record.exerciseId]?.at == record.at { return stop(.requestValidInput, "ambiguous_knowledge") }
            knowledge[record.exerciseId] = record
        }
        let facts = confirmedFacts(input.history, now: now, config: config, source: source)
        // A complete movement of at least two sets advances variety. Reopening does not.
        let completedSessions = Set(facts.values.flatMap { $0 }.filter {
            $0.complete && $0.work.confirmedSets.count >= 2
        }.map(\.sessionAt)).count
        let freshAfter = now.addingTimeInterval(-Double(config.policy.returnQuestionAfterDaysWithoutComparableExposure * 86400))
        let choices = Dictionary(uniqueKeysWithValues: person.choices.map { ($0.exerciseId, $0) })
        var blocked = Set(knowledge.values.filter(\.unavailable).map(\.exerciseId))
        var selectedOverrides: [String: String] = [:]
        for change in person.choices {
            switch change.choice {
            case let .variant(id):
                guard let target = config.catalog[id], let original = config.catalog[change.exerciseId],
                      target.anchor == original.anchor, target.resolvedSelectionRole == original.resolvedSelectionRole,
                      id != person.inProgressExerciseId else { return stop(.requestValidInput, "invalid_variant") }
                selectedOverrides[original.anchor] = id
            case .cannotPerform, .exclude: blocked.insert(change.exerciseId)
            default: break
            }
        }
        func available(_ id: String) -> Bool {
            guard let e = config.catalog[id] else { return false }
            return !blocked.contains(id) && !Engine.isRefused(id, exercise: e, refusals: input.refusals)
                && Engine.exerciseIsAvailable(e, inventory: input.todayInventory, supports: input.todaySupports, configuration: config)
        }
        func seed(_ id: String) -> (Int, V2Load?, String) {
            let e = config.catalog[id]!
            let k = knowledge[id]
            let fact = facts[id]?.first
            if let k, k.at >= freshAfter, k.at >= (fact?.at ?? .distantPast),
               !k.repetitionsAreMaximum, k.declaredReps != nil || k.declaredLoad != nil {
                return (k.declaredReps ?? e.repRange.entry, k.declaredLoad ?? Engine.entryLoad(e, inventory: input.todayInventory), "user_declared")
            }
            if let fact { return (fact.reps, fact.load, fact.at < freshAfter ? "reconfirmation_pending" : "observed") }
            return (e.repRange.entry, Engine.entryLoad(e, inventory: input.todayInventory), "new")
        }
        func requiresAnswer(_ id: String) -> Bool {
            let e = config.catalog[id]!
            if e.initialCapacityRequired != true, case let .load(value) = choices[id]?.choice,
               validLoad(value, e, input.todayInventory) { return false }
            if let k = knowledge[id], let unable = k.reportedUnableAt,
               unable >= (facts[id]?.first?.at ?? .distantPast),
               !(k.at > unable && k.declaredReps.map({ $0 >= e.repRange.min }) == true && !k.repetitionsAreMaximum) {
                return true
            }
            if let k = knowledge[id], k.at >= freshAfter, k.at >= (facts[id]?.first?.at ?? .distantPast),
               let reps = k.declaredReps,
               reps < e.repRange.min || k.repetitionsAreMaximum { return true }
            let start = seed(id)
            if start.0 < e.repRange.min { return true }
            guard e.initialCapacityRequired == true else { return false }
            if let f = facts[id]?.first, f.at >= freshAfter, f.reps >= e.repRange.min,
               f.at >= (knowledge[id]?.at ?? .distantPast) { return false }
            if let k = knowledge[id], k.at >= freshAfter, let reps = k.declaredReps,
               !k.repetitionsAreMaximum, reps >= e.repRange.min {
                // An assistance/load statement belongs to its exact option, not just its movement.
                return e.loadMode != .bodyweight && k.declaredLoad == nil
            }
            return true
        }
        // Two separate, complete exposures at the same load, with the actual displayed targets.
        // Holding a target is a programming convention; it does not infer fatigue or effort.
        func repetitionGap(_ id: String) -> (reps: Int, ask: Bool)? {
            guard config.catalog[id]?.resolvedTargetUnit == .repetitions,
                  let latest = facts[id]?.first, latest.at >= freshAfter else { return nil }
            let comparable = (facts[id] ?? []).prefix { $0.complete && $0.load == latest.load && $0.at >= freshAfter && $0.at > (knowledge[id]?.repetitionHoldReleasedAt ?? .distantPast) }
            let gaps = comparable.filter { fact in
                fact.work.confirmedSets.allSatisfy { set in
                    set.prescribedRepetitions.map { $0 > set.repetitions } == true
                }
            }
            guard gaps.count >= 2 else { return nil }
            let held = min(gaps[0].reps, gaps[1].reps)
            guard held >= config.catalog[id]!.repRange.min, latest.reps <= held else { return nil }
            return (held, latest.at == gaps[0].at && (knowledge[id]?.repetitionReviewAt ?? .distantPast) < gaps[0].at)
        }
        func familiar(_ id: String) -> Bool { knowledge[id]?.familiar == true || facts[id]?.isEmpty == false }
        func ordered(_ anchor: String) -> [String] {
            config.catalog.keys.filter { config.catalog[$0]!.anchor == anchor
                && config.catalog[$0]!.resolvedSelectionRole == .anchor && available($0) }.sorted { a, b in
                let aKnown = familiar(a) ? 0 : 1, bKnown = familiar(b) ? 0 : 1
                if aKnown != bKnown { return aKnown < bKnown }
                let aDate = facts[a]?.first?.at ?? .distantPast, bDate = facts[b]?.first?.at ?? .distantPast
                if aDate != bDate { return aDate > bDate }
                return (config.catalog[a]!.selectionRank, a) < (config.catalog[b]!.selectionRank, b)
            }
        }
        func option(_ id: String) -> V2MovementOption {
            .init(exerciseId: id, requiresCapacityAnswer: requiresAnswer(id),
                  availableLoads: loads(config.catalog[id]!, input.todayInventory))
        }
        var checks: [V2MovementCheck] = []
        var alternatives: [String: [V2MovementOption]] = [:]
        var selected: [String] = []
        var anchors = input.activeSession.map { active in
            Engine.stableUnique(active.unstarted.compactMap { config.catalog[$0.exerciseId]?.anchor })
        } ?? Engine.orderedAnchors(history: [], configuration: config)
        if input.activeSession == nil, !anchors.isEmpty {
            let offset = completedSessions % anchors.count
            anchors = Array(anchors.dropFirst(offset)) + Array(anchors.prefix(offset))
        }
        for anchor in anchors {
            var candidates = ordered(anchor)
            // Only rotate well-established, currently feasible variants; never discover a
            // harder movement merely to create novelty. Each retains its own evidence.
            let established = candidates.filter { id in
                !requiresAnswer(id) && (facts[id] ?? []).filter { $0.complete && $0.at >= freshAfter }.count >= 2
            }
            if input.activeSession == nil, completedSessions > 0, completedSessions % 3 == 0,
               established.count > 1,
               let leastRecent = established.min(by: { facts[$0]!.first!.at < facts[$1]!.first!.at }) {
                candidates.removeAll { $0 == leastRecent }; candidates.insert(leastRecent, at: 0)
            }
            let activeId = input.activeSession?.unstarted.first { config.catalog[$0.exerciseId]?.anchor == anchor }?.exerciseId
            let requested = selectedOverrides[anchor] ?? activeId
            if let requested, selectedOverrides[anchor] != nil, !available(requested) {
                return stop(.requestValidInput, "unavailable_variant")
            }
            let preferred = requested.flatMap { available($0) ? $0 : nil } ?? candidates.first
            guard let preferred else { continue }
            let activePreserved = activeId == preferred && input.activeSession != nil && !requiresAnswer(preferred)
            if requiresAnswer(preferred) && !activePreserved {
                if selectedOverrides[anchor] != nil || !candidates.contains(where: { !requiresAnswer($0) }) {
                    checks.append(.init(anchor: anchor, exerciseId: preferred, reason: "capacity_needed",
                                        requiredBeforeMovement: true, alternatives: candidates.prefix(3).map(option)))
                }
                // An explicit choice never silently turns into a different movement.
                if selectedOverrides[anchor] != nil { continue }
            }
            guard let id = activePreserved ? preferred : (requiresAnswer(preferred)
                ? candidates.first(where: { !requiresAnswer($0) }) : preferred) else { continue }
            selected.append(id)
            alternatives[id] = candidates.filter { $0 != id }.prefix(2).map(option)
        }
        if input.activeSession == nil && completedSessions == 0 {
            // Familiar movements first, retaining editorial order for ties.
            selected = selected.enumerated().sorted {
                if familiar($0.element) != familiar($1.element) { return familiar($0.element) }
                return $0.offset < $1.offset
            }.map(\.element)
        }
        // Choices must refer to a planned/available source, never an unrelated hidden exercise.
        for change in person.choices {
            let anchor = config.catalog[change.exerciseId]!.anchor
            guard anchors.contains(anchor), available(change.exerciseId) || blocked.contains(change.exerciseId) else {
                return stop(.requestValidInput, "choice_outside_session")
            }
        }
        var references: [V2Reference] = []
        for id in selected {
            let e = config.catalog[id]!, start = seed(id)
            if start.0 >= e.repRange.min {
                references.append(.init(exerciseId: id, loadKg: start.1?.kg, loadOptionID: start.1?.optionID,
                                        targetReps: min(start.0, e.repRange.max), progressionContext: e.progressionContext))
            }
        }
        let factualInput = V2SessionDecisionInput(request: .init(durationMinutes: 30),
            persistentInventory: input.persistentInventory, todayInventory: input.todayInventory,
            todaySupports: input.todaySupports,
            history: [.init(endedAt: ISO8601DateFormatter().string(from: now), references: references,
                           catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion)]
                + input.history.filter { $0.catalogVersion == config.catalogVersion && $0.decisionPolicyVersion == config.decisionPolicyVersion }
                    .map { .init(endedAt: $0.endedAt, restObservations: $0.restObservations,
                                 catalogVersion: $0.catalogVersion, decisionPolicyVersion: $0.decisionPolicyVersion) },
            refusals: input.refusals)
        // Reuse the existing assembler and costs. No time quota or optional time-filler.
        let base = Engine.buildSession(input: factualInput, mode: .normal, budget: nil, now: now,
            configuration: config, preferredExerciseIds: selected,
            forcedCandidates: selected.map { .init(exerciseId: $0, sourceExerciseId: nil, substitutionType: nil) },
            experimentalSizing: .catalogMinimum)
        var plan: [V2PlanItem] = []
        var consumedChoices = Set<String>()
        for built in base.plan {
            let id = built.exerciseId, e = config.catalog[id]!
            let prior = input.activeSession?.unstarted.first { config.catalog[$0.exerciseId]?.anchor == e.anchor }
            let unchangedActive = prior?.exerciseId == id
            let start = seed(id)
            var reps = unchangedActive ? prior!.targetReps : built.targetReps
            var load = unchangedActive ? prior!.load : built.load
            var status = unchangedActive ? prior!.referenceStatus : (built.referenceStatus == "recalibrating" ? "recalibrating" : start.2)
            var sets = prior?.sets ?? knowledge[id]?.usualSets
                ?? (person.practice == .regular && familiar(id) && !person.returning ? 3 : 2)
            sets = prior == nil ? min(e.sets.max, max(e.sets.min, sets)) : min(e.sets.max, sets)
            if prior != nil && !unchangedActive && !familiar(id) { sets = min(sets, 2) }
            let recentWork = input.activeSession == nil && e.primaryContributions.contains { muscle in
                Set(facts.filter { key, _ in
                    config.catalog[key]?.primaryContributions.contains(muscle) == true
                }.values.flatMap { $0 }.filter {
                    $0.complete && $0.work.confirmedSets.count >= 2 && $0.at >= now.addingTimeInterval(-48 * 3600)
                }.map(\.sessionAt)).count >= 2
            }
            let ordinarySets = sets
            if recentWork {
                sets = max(e.sets.min, sets - 1)
            }
            let change = choices[prior?.exerciseId ?? id]
            if input.activeSession == nil {
                if mode == .light || mode == .recalibration || person.returning { sets = max(e.sets.min, min(2, sets - (mode == .light ? 1 : 0))) }
                if mode == .recalibration {
                    let ref = references.first { $0.exerciseId == id }
                    load = Engine.recalibrationLoad(e, reference: ref, inventory: input.todayInventory)
                    reps = e.repRange.min; status = "recalibrating"
                }
            }
            if let change {
                consumedChoices.insert(change.exerciseId)
                switch change.choice {
                case let .load(value):
                    guard validLoad(value, e, input.todayInventory) else { return stop(.requestValidInput, "unavailable_load") }
                    load = value; status = "chosen_today"
                case let .sets(count):
                    guard (e.sets.min...e.sets.max).contains(count) else { return stop(.requestValidInput, "invalid_sets") }
                    let confirmedCount = input.activeSession?.confirmed.filter { $0.progressionContext == e.progressionContext }
                        .reduce(0) { $0 + $1.sets } ?? 0
                    guard count >= confirmedCount else { return stop(.requestValidInput, "sets_below_confirmed_work") }
                    sets = count - confirmedCount
                case let .holdRepetitions(count):
                    guard (e.repRange.min...e.repRange.max).contains(count) else { return stop(.requestValidInput, "invalid_repetitions") }
                    reps = count; status = "repetitions_chosen"
                case .deferRepetitionReview, .resumeRepetitionProgression: break
                case .difficultyTooHigh:
                    let lower = Engine.recalibrationLoad(e, reference: .init(exerciseId: id, loadKg: load?.kg,
                        loadOptionID: load?.optionID, targetReps: reps, progressionContext: e.progressionContext), inventory: input.todayInventory)
                    if lower != load { load = lower }
                    else if reps > e.repRange.min { reps = e.repRange.min }
                    else {
                        checks.append(.init(anchor: e.anchor, exerciseId: id, reason: "no_lower_difficulty",
                            requiredBeforeMovement: true, alternatives: alternatives[id] ?? []))
                        continue
                    }
                    status = "difficulty_adjusted_today"
                default: break
                }
            }
            let preferredReps = knowledge[id].flatMap { k in
                k.preferredRepsLoad == load ? k.preferredReps : nil
            }
            let gap = facts[id]?.first?.load == load ? repetitionGap(id) : nil
            if change == nil, let preferredReps, (e.repRange.min...e.repRange.max).contains(preferredReps) {
                reps = preferredReps; status = "repetitions_chosen"
            } else if change == nil, let gap {
                reps = gap.reps; status = "repetitions_held"
                if gap.ask {
                    checks.append(.init(anchor: e.anchor, exerciseId: id, reason: "repeated_repetitions_gap",
                        requiredBeforeMovement: false, alternatives: alternatives[id] ?? []))
                }
            }
            if input.activeSession == nil, !recentWork, change == nil, preferredReps == nil, gap == nil, mode == .normal, !person.returning,
               let latest = facts[id]?.first, latest.complete, latest.at >= freshAfter,
               latest.work.plannedSets == sets, latest.reps >= e.repRange.min,
               latest.at >= (knowledge[id].flatMap { ($0.declaredReps != nil || $0.declaredLoad != nil) ? $0.at : nil } ?? .distantPast) {
                let previous = V2Prescription(exerciseId: id, sets: sets, targetReps: min(latest.reps, e.repRange.max),
                    load: latest.load, progressionContext: e.progressionContext,
                    catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion)
                let exposures = (facts[id] ?? []).filter { $0.at >= freshAfter && $0.complete }.map { f in
                    V2Exposure(confirmedReps: f.work.confirmedSets.map(\.repetitions), loadKg: f.load?.kg,
                        loadOptionID: f.load?.optionID, allPrescribedSetsConfirmed: f.complete,
                        progressionContext: e.progressionContext, catalogVersion: config.catalogVersion,
                        decisionPolicyVersion: config.decisionPolicyVersion, interruptedBySafetySignal: false)
                }
                let progressed = Engine.progressPrescription(input: .init(todayInventory: input.todayInventory,
                    previousPrescription: previous, exposures: exposures, todaySupports: input.todaySupports), configuration: config)
                reps = progressed.nextPrescription.targetReps; load = progressed.nextPrescription.load
                if progressed.decision == .updatePrescription { status = "progression_proposed" }
            }
            guard load.map({ validLoad($0, e, input.todayInventory) }) ?? (e.loadMode == .bodyweight) else {
                checks.append(.init(anchor: e.anchor, exerciseId: id, reason: "load_reference_unavailable",
                    requiredBeforeMovement: true, alternatives: alternatives[id] ?? [])); continue
            }
            if recentWork, sets < ordinarySets {
                notes.append(.init(code: "recent_work_dose", scope: id, source: "programming_convention",
                    message: "Une série de moins après deux séances récentes avec travail confirmé sur les muscles principaux.", decisionPolicyVersion: version))
            }
            if sets == 0 { continue }
            plan.append(.init(exerciseId: id, sourceExerciseId: prior?.exerciseId == id ? nil : prior?.exerciseId,
                sets: sets, targetReps: reps, restSeconds: prior?.restSeconds ?? built.restSeconds,
                load: load, referenceStatus: status, progressionContext: e.progressionContext, targetUnit: e.targetUnit))
            note("dose_selected", "\(id) : \(sets) séries prévues.", source: change == nil ? "programming_convention" : "user")
        }
        for change in person.choices where change.choice == .cannotPerform {
            let e = config.catalog[change.exerciseId]!
            var record = knowledge[change.exerciseId] ?? .init(exerciseId: change.exerciseId,
                progressionContext: e.progressionContext, at: change.at, catalogVersion: config.catalogVersion)
            record.reportedUnableAt = change.at
            knowledge[change.exerciseId] = record
        }
        for change in person.choices {
            switch change.choice {
            case .load, .sets, .difficultyTooHigh, .holdRepetitions, .deferRepetitionReview, .resumeRepetitionProgression:
                guard consumedChoices.contains(change.exerciseId) else { return stop(.requestValidInput, "choice_not_applied") }
            default: break
            }
        }
        for change in person.choices where change.scope == .usual {
            let e = config.catalog[change.exerciseId]!
            var record = knowledge[change.exerciseId] ?? .init(exerciseId: change.exerciseId,
                progressionContext: e.progressionContext, at: change.at, catalogVersion: config.catalogVersion)
            record.preferenceUpdatedAt = change.at
            switch change.choice {
            case .exclude, .cannotPerform: record.unavailable = true
            case let .sets(count): record.usualSets = count
            case let .holdRepetitions(count):
                record.preferredReps = count
                record.preferredRepsLoad = plan.first { $0.exerciseId == change.exerciseId }?.load
                record.repetitionReviewAt = change.at
            case .resumeRepetitionProgression:
                record.preferredReps = nil; record.preferredRepsLoad = nil
                record.repetitionHoldReleasedAt = change.at; record.repetitionReviewAt = change.at
            // A direct load/variant choice does not certify capacity or become a permanent level.
            default: return stop(.requestValidInput, "usual_scope_requires_explicit_preference")
            }
            knowledge[change.exerciseId] = record
        }
        for change in person.choices {
            if change.choice == .deferRepetitionReview || change.choice == .difficultyTooHigh {
                let e = config.catalog[change.exerciseId]!
                var record = knowledge[change.exerciseId] ?? .init(exerciseId: change.exerciseId,
                    progressionContext: e.progressionContext, at: change.at, catalogVersion: config.catalogVersion)
                record.repetitionReviewAt = change.at
                knowledge[change.exerciseId] = record
            }
        }
        if !checks.isEmpty { note("local_check_needed", "Un mouvement nécessite encore un repère avant de commencer.") }
        return result(plan, decision: input.activeSession != nil ? .resumeOrAdaptActiveSession : (plan.isEmpty ? .noCleanSession : .generateSession),
            input: input, person: person, config: config, notes: notes,
            knowledge: knowledge.values.sorted { $0.exerciseId < $1.exerciseId }, checks: checks, options: alternatives)
    }

    static func loads(_ e: V2ExerciseDefinition, _ inventory: [V2InventoryItem]) -> [V2Load] {
        if e.loadMode == .bodyweight { return [] }
        if e.loadMode == .bandOption { return Engine.availableOptions(for: e, inventory: inventory).map(V2Load.init(optionID:)) }
        return Engine.availableWeights(for: e, inventory: inventory).map { .init(mode: e.loadMode, kg: $0) }
    }
    static func validLoad(_ load: V2Load, _ e: V2ExerciseDefinition, _ inventory: [V2InventoryItem]) -> Bool {
        loads(e, inventory).contains(load)
    }

    static func confirmedFacts(_ history: [V2HistoryEntry], now: Date, config: V2EngineConfiguration,
                               source: V2HistoryEvidenceSource) -> [String: [Fact]] {
        var result: [String: [Fact]] = [:], seen = Set<String>()
        for entry in history.sorted(by: { (Engine.parseDate($0.endedAt) ?? .distantPast) > (Engine.parseDate($1.endedAt) ?? .distantPast) }) {
            guard entry.catalogVersion == config.catalogVersion, entry.decisionPolicyVersion == config.decisionPolicyVersion,
                  let end = Engine.parseDate(entry.endedAt), end <= now else { continue }
            for work in entry.confirmedWorkEvidence ?? [] {
                guard let e = config.catalog[work.exerciseId], work.source == source,
                      work.progressionContext == e.progressionContext, work.targetUnit == e.resolvedTargetUnit,
                      !work.interruptedBySafetySignal, work.plannedSets > 0, !work.confirmedSets.isEmpty,
                      work.confirmedSets.allSatisfy({ $0.repetitions > 0 && $0.eventID?.isEmpty == false
                          && Engine.parseDate($0.completedAt).map { $0 <= end } == true }) else { continue }
                let ids = work.confirmedSets.compactMap(\.eventID)
                guard Set(ids).count == ids.count, seen.isDisjoint(with: ids) else { continue }
                seen.formUnion(ids)
                let sorted = work.confirmedSets.sorted { Engine.parseDate($0.completedAt)! < Engine.parseDate($1.completedAt)! }
                let last = sorted.last!
                // Keep the most recent actual load after an in-session correction; never invent a blended load.
                let tail = Array(sorted.reversed().prefix { $0.loadKg == last.loadKg && $0.loadOptionID == last.loadOptionID })
                let load = last.loadKg.map { V2Load(mode: e.loadMode, kg: $0) } ?? last.loadOptionID.map(V2Load.init(optionID:))
                guard (e.loadMode != .bodyweight || (last.loadKg == nil && last.loadOptionID == nil)),
                      !(last.loadKg != nil && last.loadOptionID != nil) else { continue }
                result[work.exerciseId, default: []].append(.init(work: work, at: Engine.parseDate(last.completedAt)!, sessionAt: end,
                    reps: tail.map(\.repetitions).min()!, load: load,
                    complete: !work.wasSkipped && tail.count == work.plannedSets && tail.count == work.confirmedSets.count))
            }
        }
        for key in result.keys { result[key]!.sort { $0.at > $1.at } }
        return result
    }

    static func makeBlocks(_ plan: [V2PlanItem], config: V2EngineConfiguration) -> [[String]] {
        var remaining = plan
        var blocks: [[String]] = []
        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            guard let a = config.catalog[first.exerciseId] else { continue }
            let upper = ["pull", "push"].contains(a.anchor)
            let match = remaining.firstIndex { row in
                guard let b = config.catalog[row.exerciseId], upper != ["pull", "push"].contains(b.anchor),
                      Set(a.primaryContributions).isDisjoint(with: b.primaryContributions) else { return false }
                // Conservative: loaded partners must use exactly the same load configuration.
                return first.load == nil || row.load == nil || first.load == row.load
            }
            if let match { blocks.append([first.exerciseId, remaining.remove(at: match).exerciseId]) }
            else { blocks.append([first.exerciseId]) }
        }
        return blocks
    }

    static func result(_ plan: [V2PlanItem], decision: V2DecisionName, input: V2SessionDecisionInput,
                       person: V2Personalization, config: V2EngineConfiguration, notes: [V2Reason],
                       knowledge: [V2MovementKnowledge], checks: [V2MovementCheck] = [],
                       options: [String: [V2MovementOption]] = [:]) -> V2PersonalizedSessionResult {
        // A resumed plan describes remaining work; session coverage includes confirmed work too.
        let ids = plan.map(\.exerciseId) + (input.activeSession?.confirmed.map(\.exerciseId) ?? [])
        let primary = Set(ids.flatMap { config.catalog[$0]?.primaryContributions ?? [] })
        let secondary = Set(ids.flatMap { config.catalog[$0]?.secondaryContributions ?? [] })
        let covered = Engine.stableUnique(ids.compactMap { config.catalog[$0]?.anchor })
        let missing = Set(["chest", "back", "quadriceps", "glutes", "hamstrings"]).subtracting(primary).sorted()
        var reasons = notes
        if !missing.isEmpty && !plan.isEmpty {
            reasons.append(.init(code: "muscle_coverage_partial", scope: "session", source: "catalogue",
                message: "Contributions principales non couvertes : \(missing.joined(separator: ", ")).",
                decisionPolicyVersion: version))
        }
        let blocks = makeBlocks(plan, config: config)
        let arranged = blocks.flatMap { $0 }.compactMap { id in plan.first { $0.exerciseId == id } }
        // Keep every prescribed rest, including transitions between movements.
        let finalItem = (blocks.last ?? []).compactMap { id in plan.first { $0.exerciseId == id } }
            .enumerated().max { ($0.element.sets, $0.offset) < ($1.element.sets, $1.offset) }?.element
        let restTotal = plan.reduce(0) { $0 + $1.sets * $1.restSeconds } - (finalItem?.restSeconds ?? 0)
        let execution = plan.reduce(0) { total, row in
            guard let e = config.catalog[row.exerciseId] else { return total }
            return total + e.timingSeconds.setup + row.sets * (e.timingSeconds.execution + e.timingSeconds.secondSide + e.timingSeconds.transition)
        }
        return .init(decision: .init(catalogVersion: config.catalogVersion, decisionPolicyVersion: config.decisionPolicyVersion,
            decision: decision, sessionId: person.sessionId, mode: input.activeSession?.mode ?? input.request.mode ?? .normal,
            estimatedSeconds: execution + max(0, restTotal), plan: arranged,
            confirmed: input.activeSession?.confirmed ?? [], coveredAnchors: covered,
            omittedAnchors: config.policy.anchorTieOrder.filter { !covered.contains($0) }, reasons: reasons,
            confirmedImmutable: true), knowledge: knowledge, checks: checks, optionsByExercise: options,
            coverage: .init(primary: primary.sorted(), secondary: secondary.sorted(), missingPrimary: missing), policyVersion: version, blocks: blocks)
    }
}
