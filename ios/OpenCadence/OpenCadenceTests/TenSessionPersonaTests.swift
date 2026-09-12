import CadenceEngine
import Foundation
import SwiftData
import Testing
@testable import OpenCadence

/// Scripted synthetic trajectories through the production native services, never a personal store.
/// These reuse the reference cohort's situations, not its old duration-based simulator dispatcher.
@MainActor
struct TenSessionPersonaTests {
    enum Persona: String, CaseIterable {
        case steady_beginner, irregular_short, motivation_wave, slow_deliberate, minimal_equipment
        case single_weight, equipment_shifts, explicit_stop, stagnation, unknown_interruptions
        case return_after_90_days, equipment_change, regular, pullup_beginner, pullup_regular
        case load_correction, pullup_answered, pullup_capacity_drop, consecutive_days
    }
    struct Trace: Codable {
        var persona: String
        var session: Int
        var day: Int
        var plan: [V2PlanItem]
        var checks: [String]
        var missingPrimary: [String]
        var confirmedSets: Int
        var interrupted: Bool
        var knowledgeCount: Int
        var execution: [String]
        var blocks: [[String]]
    }
    let config = V2EngineConfiguration.productPreview
    let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    let body = EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
    let dumbbells = EquipmentItem(category: "adjustable_dumbbell", units: 2,
        perUnitWeightsKg: [4, 6, 8, 10, 12], supportedConfigurations: ["single", "pair"])
    let supports = ["floor_allowed", "solid_wall", "wall_or_stable_plane", "stable_incline_support",
        "stable_hand_support", "seated_support", "overhead_clearance", "pullup_clearance", "pullup_top_start_support"]

    @Test("Nineteen synthetic users complete ten connected native session opportunities", arguments: Persona.allCases)
    func tenSessions(_ persona: Persona) throws {
        let container = try ModelContainer(for: UserSetupRecord.self, ActiveWorkoutRecord.self, CompletedWorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let setup = try UserSetupRecord(inventory: [body, dumbbells])
        container.mainContext.insert(setup)
        setup.strengthPractice = [.regular, .pullup_regular, .pullup_capacity_drop, .pullup_answered, .return_after_90_days].contains(persona) ? .regular : .discovering
        var traces: [Trace] = []
        var priorPayloads: [Data] = []
        var previousPlan: [V2PlanItem] = []
        for index in 0..<10 {
            let day = index * (persona == .consecutive_days ? 1 : (persona == .irregular_short ? 7 : 3))
                + (index >= 5 && [.return_after_90_days, .motivation_wave].contains(persona) ? 90 : 0)
            let date = epoch.addingTimeInterval(Double(day * 86400))
            var clock = date
            var equipment = [body, dumbbells]
            if [.minimal_equipment, .pullup_beginner, .pullup_regular, .pullup_answered, .pullup_capacity_drop].contains(persona)
                || (persona == .equipment_shifts && [2, 3, 7].contains(index)) { equipment = [body] }
            if persona == .single_weight {
                equipment = [body, .init(category: "adjustable_dumbbell", units: 1,
                    perUnitWeightsKg: [6], supportedConfigurations: ["single"])]
            }
            if [.pullup_beginner, .pullup_regular, .pullup_answered, .pullup_capacity_drop].contains(persona) {
                equipment.append(.init(category: "pullup_bar", units: 1, supportedConfigurations: ["bodyweight"]))
            }
            if persona == .equipment_change && index >= 5 {
                equipment = [body, .init(category: "kettlebell", units: 1,
                    perUnitWeightsKg: [8, 12], supportedConfigurations: ["single"])]
            }
            setup.inventory = persona == .equipment_shifts ? [body, dumbbells] : equipment
            let history = try container.mainContext.fetch(FetchDescriptor<CompletedWorkoutRecord>()).sorted { $0.endedAt < $1.endedAt }
            #expect(history.map(\.payloadData) == priorPayloads)
            var knowledge = try setup.movementKnowledge()
            if index == 0 && [.pullup_regular, .pullup_capacity_drop].contains(persona) {
                let exercise = try #require(config.catalog["pull_up"])
                knowledge = [.init(exerciseId: "pull_up", progressionContext: exercise.progressionContext,
                    familiar: true, usualSets: 3, declaredReps: 5, at: date, catalogVersion: config.catalogVersion)]
                setup.movementKnowledgeData = try JSONEncoder().encode(knowledge)
            }
            let prepared = WorkoutEngineBridge.prepareWorkout(inventory: setup.inventory, todayInventory: equipment, durationMinutes: index % 2 == 0 ? 20 : 45,
                completedWorkouts: history, persistentRefusals: persona == .single_weight ? ["dumbbell_floor_press__adjustable"] : [],
                engineVersion: .previewV2, todaySupports: supports, person: .init(sessionId: "synthetic-\(persona.rawValue)-\(index)",
                    practice: setup.strengthPractice, returning: persona == .return_after_90_days && index == 5,
                    knowledge: knowledge), now: date)
            let context = try #require(prepared.v2Context)
            let personal = try #require(context.personalization)
            #expect(!context.plan.isEmpty)
            #expect(personal.policyVersion == "first-sessions-1")
            #expect(history.count == index)
            #expect(!prepared.personalizationResult!.decision.createsDebt)
            for row in context.plan {
                let exercise = try #require(config.catalog[row.exerciseId])
                #expect(exercise.supports.allSatisfy(supports.contains))
                #expect(exercise.equipment.allSatisfy { requirement in
                    context.inventory.contains { $0.category == requirement.category && $0.units >= requirement.units }
                })
                if let load = row.load {
                    #expect(CadenceEngine.personalizationLoads(exerciseId: row.exerciseId, inventory: context.inventory,
                        configuration: config).contains(load))
                }
                #expect(row.sets >= 1 && row.sets <= 3)
            }
            if persona == .pullup_beginner {
                #expect(!context.plan.contains { ["pull_up", "eccentric_pull_up"].contains($0.exerciseId) })
                #expect(personal.coverage.missingPrimary.contains("back"))
            }
            if persona == .pullup_regular {
                #expect(context.plan.contains { $0.exerciseId == "pull_up" && $0.sets == 3 })
                #expect(!personal.checks.contains { $0.exerciseId == "pull_up" && $0.requiredBeforeMovement })
            }
            if persona == .return_after_90_days && index == 5 {
                #expect(context.plan.allSatisfy { $0.sets <= 2 })
            }
            if [.irregular_short, .unknown_interruptions].contains(persona), index > 0, (index - 1) % 3 == 1 {
                for row in context.plan {
                    #expect(row.sets == previousPlan.first { $0.exerciseId == row.exerciseId }?.sets)
                }
            }
            if persona == .equipment_change && index == 5 {
                #expect(context.plan.allSatisfy { !previousPlan.map(\.exerciseId).contains($0.exerciseId) })
                #expect(context.plan.allSatisfy { $0.referenceStatus == "new" })
            }
            if persona == .load_correction && index > 0 {
                let row = try #require(context.plan.first { $0.exerciseId == "supported_one_arm_row__adjustable" })
                #expect(row.load?.kg == 6)
                #expect(row.targetReps <= 10)
            }
            if persona == .pullup_answered && index > 0 {
                #expect(context.plan.contains { $0.exerciseId == "pull_up" })
                #expect(!personal.checks.contains { $0.exerciseId == "pull_up" && $0.requiredBeforeMovement })
            }
            if persona == .pullup_capacity_drop && index >= 4 {
                #expect(!context.plan.contains { $0.exerciseId == "pull_up" })
                #expect(personal.checks.contains { $0.exerciseId == "pull_up" })
            }
            if persona == .stagnation && index >= 3 {
                #expect(context.plan.first { $0.exerciseId == "supported_one_arm_row__adjustable" }?.targetReps == 8)
                if index >= 4 { #expect(!personal.checks.contains { $0.reason == "repeated_repetitions_gap" }) }
            }
            var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: context, now: clock)
            #expect(snapshot.setStartedAt == nil && snapshot.restDeadline == nil)
            // Explicit usual volume at S1, persisted through the same helper as the adjustment sheet.
            if [.regular, .return_after_90_days].contains(persona) && index == 0 {
                for row in context.plan {
                    snapshot = try NativePersonalization.adjust(snapshot, exerciseID: row.exerciseId,
                        choice: .sets(3), scope: .usual, declaration: nil, history: [], now: clock)
                    knowledge = NativePersonalization.durableKnowledge(knowledge, exerciseID: row.exerciseId,
                        choice: .sets(3), declaration: nil, result: snapshot.v2Context!.personalization!.person.knowledge)
                }
                setup.movementKnowledgeData = try JSONEncoder().encode(knowledge)
            }
            if persona == .regular || (persona == .return_after_90_days && index != 5) {
                #expect(snapshot.v2Context!.plan.allSatisfy { $0.sets == 3 })
            }
            if persona == .return_after_90_days && index == 5 {
                #expect(knowledge.allSatisfy { $0.usualSets == 3 })
            }
            if persona == .equipment_shifts { #expect(setup.inventory == [body, dumbbells]) }
            if persona == .pullup_answered && index == 0 {
                #expect(personal.checks.contains { $0.exerciseId == "pull_up" })
                let exercise = try #require(config.catalog["pull_up"])
                // Independent declaration: this person already does comfortable sets of five.
                let declaration = V2MovementKnowledge(exerciseId: "pull_up", progressionContext: exercise.progressionContext,
                    familiar: true, declaredReps: 5, at: clock, catalogVersion: config.catalogVersion)
                snapshot = try NativePersonalization.adjust(snapshot, exerciseID: "pull_up", choice: nil,
                    scope: .usual, declaration: declaration, history: [], now: clock)
                knowledge = NativePersonalization.durableKnowledge(knowledge, exerciseID: "pull_up", choice: nil,
                    declaration: declaration, result: snapshot.v2Context!.personalization!.person.knowledge)
                setup.movementKnowledgeData = try JSONEncoder().encode(knowledge)
                #expect(snapshot.v2Context!.plan.contains { $0.exerciseId == "pull_up" })
                #expect(!snapshot.v2Context!.personalization!.checks.contains { $0.exerciseId == "pull_up" })
            }
            if persona == .load_correction && index == 0 {
                snapshot = try NativePersonalization.adjust(snapshot, exerciseID: "supported_one_arm_row__adjustable",
                    choice: .load(.init(mode: .singleTotalKg, kg: 6)), scope: .today, declaration: nil, history: [], now: clock)
                #expect(try setup.movementKnowledge().isEmpty)
            }
            if persona == .load_correction && index == 2 {
                snapshot = try NativePersonalization.adjust(snapshot, exerciseID: "supported_one_arm_row__adjustable",
                    choice: .load(.init(mode: .singleTotalKg, kg: 8)), scope: .today, declaration: nil,
                    history: WorkoutEngineBridge.migratedV2History(from: history.compactMap(\.payload)), now: clock)
            }
            let active = try ActiveWorkoutRecord(snapshot: snapshot, now: clock)
            container.mainContext.insert(active)
            let planned = snapshot.v2Context!.plan
            previousPlan = planned
            var steps = 0
            while !snapshot.isFinished && steps < 40 {
                steps += 1
                if snapshot.restDeadline != nil {
                    let before = snapshot.v2Context!.plan
                    clock = snapshot.restDeadline!.addingTimeInterval(persona == .slow_deliberate ? 180 : 0)
                    snapshot = ActiveSessionCoordinator.completeRest(snapshot, now: clock)
                    #expect(snapshot.v2Context!.plan == before)
                    #expect(snapshot.setStartedAt == nil)
                }
                if snapshot.isFinished { break }
                let movement = try #require(snapshot.currentMovement)
                let row = try #require(snapshot.v2Context!.plan.first { $0.exerciseId == movement.exerciseKey })
                if let kg = row.load?.kg {
                    snapshot = ActiveSessionCoordinator.confirmLoad(snapshot, exerciseKey: row.exerciseId,
                        perUnitWeightKg: kg, inventory: equipment)
                }
                if let option = row.load?.optionID {
                    snapshot = ActiveSessionCoordinator.confirmLoadOption(snapshot, exerciseKey: row.exerciseId,
                        optionID: option, inventory: equipment)
                }
                snapshot = ActiveSessionCoordinator.startSet(snapshot, now: clock)
                clock = clock.addingTimeInterval(persona == .slow_deliberate ? 100 : 35)
                let before = snapshot.recordedSets
                if persona == .explicit_stop && [2, 6].contains(index) && before.count == 1 {
                    snapshot = ActiveSessionCoordinator.reportPain(snapshot, score: 3, now: clock)
                    #expect(snapshot.unresolvedSafetyEventID != nil && snapshot.setStartedAt == nil)
                    #expect(snapshot.recordedSets == before)
                    #expect(throws: NativePersonalization.AdjustmentError.self) {
                        try NativePersonalization.adjust(snapshot, exerciseID: row.exerciseId, choice: .sets(3),
                            scope: .today, declaration: nil, history: [], now: clock)
                    }
                    snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: clock)
                    break
                }
                var repetitions = persona == .stagnation ? 8 : row.targetReps
                // Fixed scripted capabilities; never infer their success from the prescription.
                if persona == .load_correction && row.exerciseId == "supported_one_arm_row__adjustable" { repetitions = row.load?.kg == 8 ? 4 : 8 }
                if [.pullup_regular, .pullup_answered, .pullup_capacity_drop].contains(persona) && row.exerciseId == "pull_up" {
                    repetitions = persona == .pullup_capacity_drop && index >= 3 ? 2 : 5
                }
                snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: repetitions, now: clock)
                #expect(snapshot.recordedSets.count == before.count + 1)
                #expect(Array(snapshot.recordedSets.dropLast()) == before)
                if persona == .load_correction && row.exerciseId == "supported_one_arm_row__adjustable" && row.load?.kg == 8 {
                    let facts = snapshot.recordedSets, deadline = snapshot.restDeadline
                    snapshot = try NativePersonalization.adjust(snapshot, exerciseID: row.exerciseId,
                        choice: .load(.init(mode: .singleTotalKg, kg: 6)), scope: .today, declaration: nil,
                        history: WorkoutEngineBridge.migratedV2History(from: history.compactMap(\.payload)), now: clock)
                    #expect(snapshot.recordedSets == facts && snapshot.restDeadline == deadline)
                    #expect(snapshot.v2Context!.plan.first { $0.exerciseId == row.exerciseId }?.load?.kg == 6)
                    #expect(try setup.movementKnowledge().isEmpty)
                }
                if [.irregular_short, .unknown_interruptions, .motivation_wave].contains(persona)
                    && index % 3 == 1 && snapshot.recordedSets.count == 2 {
                    snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: clock)
                } else if ([.irregular_short, .unknown_interruptions, .motivation_wave].contains(persona)
                    && index % 3 == 1 && snapshot.recordedSets.count == 2) {
                    snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: clock)
                }
                try ActiveSessionCoordinator.persist(snapshot, in: active, context: container.mainContext)
                let restored = try ActiveSessionCoordinator.load(active)
                #expect(restored.snapshot == snapshot)
                snapshot = restored.snapshot
            }
            #expect(snapshot.isFinished)
            #expect(steps < 40)
            let payload = WorkoutHistoryBuilder.payload(from: snapshot)
            let record = try CompletedWorkoutRecord(payload: payload, now: clock)
            container.mainContext.insert(record)
            container.mainContext.delete(active)
            try container.mainContext.save()
            priorPayloads.append(record.payloadData)
            let evidence = WorkoutEngineBridge.migratedV2History(from: [payload]).flatMap { $0.confirmedWorkEvidence ?? [] }
            #expect(evidence.reduce(0) { $0 + $1.confirmedSets.count } == snapshot.recordedSets.count)
            traces.append(.init(persona: persona.rawValue, session: index + 1, day: day, plan: planned,
                checks: snapshot.v2Context!.personalization!.checks.map(\.exerciseId), missingPrimary: snapshot.v2Context!.personalization!.coverage.missingPrimary,
                confirmedSets: snapshot.recordedSets.count, interrupted: snapshot.endedEarly, knowledgeCount: knowledge.count, execution: snapshot.recordedSets.map(\.exerciseKey), blocks: snapshot.v2Context!.personalization!.blocks ?? []))
        }
        #expect(traces.count == 10)
        if persona == .consecutive_days {
            #expect(traces[2].plan.reduce(0) { $0 + $1.sets } < traces[0].plan.reduce(0) { $0 + $1.sets })
            #expect(Set(traces.compactMap { $0.execution.first }).count > 1)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        print("TEN_SESSION_TRACE " + String(decoding: try encoder.encode(traces), as: UTF8.self))
    }
    @Test("A global setting preserves a direct load choice before first effort")
    func globalSettingAfterLocalCorrection() throws {
        func prepare() -> PreparedWorkout {
            WorkoutEngineBridge.prepareWorkout(inventory: [body, dumbbells], durationMinutes: 30,
                engineVersion: .previewV2, todaySupports: supports,
                person: .init(sessionId: "synthetic-global-setting", practice: .regular), now: epoch)
        }
        let first = prepare()
        var snapshot = ActiveSessionCoordinator.start(decision: first.decision, v2Context: first.v2Context, now: epoch)
        let id = "supported_one_arm_row__adjustable"
        // The charge control uses confirmLoad; the general settings sheet then prepares afresh.
        snapshot = ActiveSessionCoordinator.confirmLoad(snapshot, exerciseKey: id, perUnitWeightKg: 6, inventory: [body, dumbbells])
        #expect(snapshot.confirmedLoads[id] == 6)
        let replaced = try NativePersonalization.replaceBeforeFirstSet(snapshot, with: prepare(), now: epoch)
        #expect((replaced.confirmedLoads[id] ?? replaced.v2Context?.plan.first { $0.exerciseId == id }?.load?.kg) == 6)
    }

}
