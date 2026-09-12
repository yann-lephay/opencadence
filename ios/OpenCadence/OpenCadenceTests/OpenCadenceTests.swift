import AVFoundation
import CadenceEngine
import Foundation
import StoreKit
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import OpenCadence

@MainActor
struct OpenCadenceTests {
    @Test("The app bridge uses the validated reference catalog")
    func bodyweightDecisionUsesReferenceCatalog() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]

        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)

        #expect(decision.decision == "generate_workout")
        #expect(decision.planProfileId == "bodyweight-8")
        #expect(decision.movements?.map(\.exerciseKey) == [
            "incline_pushup", "bodyweight_squat", "bodyweight_hinge"
        ])
    }

    @Test("The V2 preview is explicit and leaves the production path unchanged")
    func v2PreviewIsOptIn() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let production = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20
        )
        let preview = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: ["wall_or_stable_plane"]
        )

        #expect(production.planProfileId == "bodyweight-8")
        #expect(!production.reasonCodes.contains("engine.preview_v2"))
        #expect(preview.decision == "generate_workout")
        #expect(preview.planProfileId == "product-v2.1.0")
        #expect(preview.reasonCodes.contains("engine.preview_v2"))
        #expect(preview.plan?.map(\.exerciseKey) == ["squat", "wall_hip_hinge"])
        #expect(preview.plan?.map(\.sets) == [3, 3])
        #expect(preview.readiness == nil)
        #expect(preview.basePrimarySetBudget == nil)
        #expect(preview.finalPrimarySetBudget == nil)
    }

    @Test("The V2 preview keeps explicit supports and session refusals")
    func v2PreviewTranslatesCurrentContext() {
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 30,
            limitations: [
                Limitation(id: "today", excludedExerciseKeys: ["dumbbell_floor_press__adjustable"])
            ],
            engineVersion: .previewV2,
            todaySupports: ["wall_or_stable_plane", "floor_allowed", "stable_hand_support"]
        )

        #expect(decision.decision == "generate_workout")
        #expect(decision.movements?.contains { $0.exerciseKey == "dumbbell_floor_press__adjustable" } == false)
        #expect(decision.movements?.contains { $0.exerciseKey == "push_up" } == true)
        #expect(decision.reasonCodes.contains("refusal_today"))
        #expect(decision.recommendedLoads?.allSatisfy { recommendation in
            recommendation.perUnitWeightKg.map { [4.0, 6.0, 8.0, 10.0].contains($0) } ?? true
        } == true)
    }

    @Test("The V2 preview never invents pair compatibility")
    func v2PreviewKeepsDeclaredEquipmentConfigurations() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
            EquipmentItem(
                category: "adjustable_dumbbell",
                units: 2,
                perUnitWeightsKg: [4, 6],
                supportedConfigurations: ["single", "central", "unilateral"]
            )
        ]

        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 30,
            engineVersion: .previewV2,
            todaySupports: ["wall_or_stable_plane", "floor_allowed", "stable_hand_support"]
        )

        #expect(decision.movements?.contains { $0.exerciseKey == "supported_one_arm_row__adjustable" } == true)
        #expect(decision.movements?.contains { $0.exerciseKey == "goblet_squat__adjustable" } == true)
        #expect(decision.movements?.contains { $0.exerciseKey == "dumbbell_floor_press__adjustable" } == false)
        #expect(decision.movements?.contains { $0.exerciseKey == "dumbbell_romanian_deadlift__adjustable" } == false)
    }

    @Test("Debug runtime uses V2 internally and keeps an explicit V1 fallback")
    func internalRuntimeKeepsV1Fallback() {
#if DEBUG
        #expect(WorkoutEngineRuntime.selectedVersion(arguments: []) == .previewV2)
#endif
        #expect(WorkoutEngineRuntime.selectedVersion(arguments: ["-OpenCadenceForceV1"]) == .productionV1)
    }

    @Test("The release bridge prepares the approved V2 catalogue")
    func releaseBridgePreparesApprovedCatalogue() {
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 20,
            engineVersion: .releaseV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions
        )
        #expect(prepared.decision.errorCode == nil)
        #expect(prepared.v2Context?.plan.isEmpty == false)
    }

    @Test("A prepared V2 workout carries the exact generation context into the active session")
    func preparedV2WorkoutKeepsContext() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: now
        )
        let snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: prepared.v2Context,
            now: now
        )

        #expect(prepared.decision.decision == "generate_workout")
        #expect(prepared.v2Context?.plan.map(\.exerciseId) == prepared.decision.movements?.map(\.exerciseKey))
        #expect(snapshot.startedAt == now)
        #expect(snapshot.v2Context == prepared.v2Context)
    }

    @Test("Any declared pain stops the current V2 movement before clinical validation")
    func v2PainUsesConservativeStop() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: now
        )
        let snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: prepared.v2Context,
            now: now
        )
        let stopped = ActiveSessionCoordinator.reportPain(snapshot, score: 1, now: now)

        #expect(stopped.unresolvedSafetyEvent?.transition == "stop_current_exercise")
        #expect(stopped.unresolvedSafetyEvent?.mustNotDiagnose == true)
    }

    @Test("Finish on time keeps confirmed work and removes only work not started")
    func v2ActiveSessionFinishesOnTime() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let inventory = adjustableInventory()
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory,
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        var snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: prepared.v2Context,
            now: start
        )
        guard let first = snapshot.currentMovement,
              let item = prepared.v2Context?.plan.first else {
            Issue.record("La preview V2 aurait dû produire un premier mouvement")
            return
        }
        if let load = item.load?.kg {
            snapshot = ActiveSessionCoordinator.confirmLoad(
                snapshot,
                exerciseKey: first.exerciseKey,
                perUnitWeightKg: load,
                inventory: inventory
            )
        }
        snapshot = ActiveSessionCoordinator.recordSet(
            snapshot,
            repetitions: item.targetReps,
            now: start.addingTimeInterval(10)
        )
        snapshot = ActiveSessionCoordinator.completeRest(
            snapshot,
            now: start.addingTimeInterval(1_200)
        )

        #expect(snapshot.recordedSets.count == 1)
        #expect(snapshot.completedSetCount == 1)
        #expect(snapshot.totalSetCount == 1)
        #expect(snapshot.v2Context?.plan.first?.sets == 1)
        #expect(snapshot.decision.reasonCodes.contains("time_budget.removed_unstarted_work"))
        #expect(snapshot.isFinished)
    }

    @Test("A completed V2 workout advances the next comparable prescription")
    func completedV2WorkoutFeedsNextV2Prescription() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let inventory = adjustableInventory()
        let first = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory,
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        guard let firstContext = first.v2Context,
              let tracked = firstContext.plan.first else {
            Issue.record("La preview V2 aurait dû produire un plan traçable")
            return
        }
        var snapshot = ActiveSessionCoordinator.start(
            decision: first.decision,
            v2Context: firstContext,
            now: start
        )
        snapshot.setResults = firstContext.plan.flatMap { item in
            (0..<item.sets).map { index in
                CompletedSetRecord(
                    eventID: "\(item.exerciseId)-\(index)",
                    exerciseKey: item.exerciseId,
                    repetitions: item.targetReps,
                    perUnitWeightKg: item.load?.kg,
                    completedAt: start.addingTimeInterval(Double(index + 1)),
                    plannedRestSeconds: nil,
                    restEndedAt: nil
                )
            }
        }
        snapshot.completedSetCount = snapshot.recordedSets.count
        snapshot.isFinished = true
        snapshot.endedAt = start.addingTimeInterval(900)
        let record = try CompletedWorkoutRecord(
            payload: WorkoutHistoryBuilder.payload(from: snapshot)
        )

        let next = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory,
            durationMinutes: 20,
            completedWorkouts: [record],
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start.addingTimeInterval(86_400)
        )
        let nextTracked = next.v2Context?.plan.first {
            $0.progressionContext == tracked.progressionContext
        }

        #expect(nextTracked?.exerciseId == tracked.exerciseId)
        #expect(nextTracked?.targetReps == tracked.targetReps + 1)
        #expect(nextTracked?.referenceStatus == "kept")
    }

    @Test("Snapshots saved before the V2 slice remain decodable")
    func legacySnapshotRemainsDecodableWithoutV2Context() throws {
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: [
                EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
            ],
            durationMinutes: 20
        )
        let current = ActiveSessionCoordinator.start(decision: decision)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
        )
        object.removeValue(forKey: "startedAt")
        object.removeValue(forKey: "v2Context")
        let decoded = try JSONDecoder().decode(
            ActiveWorkoutSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(decoded.startedAt == nil)
        #expect(decoded.v2Context == nil)
        #expect(decoded.decision == decision)
    }

    @Test("An interrupted V2 workout restores the same plan and start time")
    func v2SnapshotRestoresWithoutRegeneration() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 30,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        let snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: prepared.v2Context,
            now: start
        )
        let record = try ActiveWorkoutRecord(snapshot: snapshot, now: start)

        let restored = try ActiveSessionCoordinator.load(record)

        #expect(!restored.restoredPreviousSnapshot)
        #expect(restored.snapshot.startedAt == start)
        #expect(restored.snapshot.v2Context == prepared.v2Context)
        #expect(restored.snapshot.decision == prepared.decision)
    }

    @Test("A partial movement stays factual after skip and later time adjustment")
    func partialSkippedMovementSurvivesV2TimeAdjustment() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let inventory = adjustableInventory()
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: inventory,
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        var snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: prepared.v2Context,
            now: start
        )
        guard let firstItem = prepared.v2Context?.plan.first,
              let firstMovement = snapshot.currentMovement else {
            Issue.record("La preview V2 aurait dû produire un premier mouvement")
            return
        }
        if let load = firstItem.load?.kg {
            snapshot = ActiveSessionCoordinator.confirmLoad(
                snapshot,
                exerciseKey: firstMovement.exerciseKey,
                perUnitWeightKg: load,
                inventory: inventory
            )
        }
        snapshot = ActiveSessionCoordinator.recordSet(
            snapshot,
            repetitions: firstItem.targetReps,
            now: start.addingTimeInterval(10)
        )
        snapshot = ActiveSessionCoordinator.skipCurrentMovement(
            snapshot,
            now: start.addingTimeInterval(20)
        )

        guard let secondMovement = snapshot.currentMovement,
              let secondItem = prepared.v2Context?.plan.first(where: {
                  $0.exerciseId == secondMovement.exerciseKey
              }) else {
            Issue.record("La preview V2 aurait dû conserver un mouvement suivant")
            return
        }
        if let load = secondItem.load?.kg {
            snapshot = ActiveSessionCoordinator.confirmLoad(
                snapshot,
                exerciseKey: secondMovement.exerciseKey,
                perUnitWeightKg: load,
                inventory: inventory
            )
        }
        snapshot = ActiveSessionCoordinator.recordSet(
            snapshot,
            repetitions: secondItem.targetReps,
            now: start.addingTimeInterval(30)
        )
        snapshot = ActiveSessionCoordinator.completeRest(
            snapshot,
            now: start.addingTimeInterval(1_200)
        )
        let history = WorkoutHistoryBuilder.payload(from: snapshot)

        #expect(snapshot.v2Context?.plan.first(where: {
            $0.exerciseId == firstItem.exerciseId
        })?.sets == 1)
        #expect(snapshot.decision.movements?.contains(where: {
            $0.exerciseKey == firstItem.exerciseId && $0.sets == 1
        }) == true)
        #expect(history.historySession.exerciseRecords?.contains(where: {
            $0.exerciseKey == firstItem.exerciseId
        }) == true)
        #expect(history.historySession.completedExerciseKeys?.contains(firstItem.exerciseId) == false)
        let migrated = WorkoutEngineBridge.migratedV2History(from: [history]).first
        #expect(migrated?.completedExerciseIds?.contains(firstItem.exerciseId) != true)
        #expect(migrated?.references?.first(where: {
            $0.progressionContext == firstItem.progressionContext
        }) == nil)
        #expect(migrated?.confirmedWorkEvidence?.first(where: { $0.exerciseId == firstItem.exerciseId })?.confirmedSets.count == 1)
    }

    @Test("Mixed factual loads hold the V2 prescription")
    func mixedLoadsCannotProgressV2Prescription() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        guard let context = prepared.v2Context,
              let weighted = context.plan.first(where: { $0.load != nil }),
              let prescribedLoad = weighted.load?.kg else {
            Issue.record("La preview V2 aurait dû produire un mouvement pondéré")
            return
        }
        var snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: context,
            now: start
        )
        snapshot.setResults = (0..<weighted.sets).map { index in
            CompletedSetRecord(
                eventID: "mixed-\(index)",
                exerciseKey: weighted.exerciseId,
                repetitions: weighted.targetReps,
                perUnitWeightKg: index == weighted.sets - 1 ? prescribedLoad : prescribedLoad + 2,
                completedAt: start.addingTimeInterval(Double(index + 1)),
                plannedRestSeconds: nil,
                restEndedAt: nil
            )
        }
        let payload = WorkoutHistoryBuilder.payload(from: snapshot, endedAt: start.addingTimeInterval(900))
        let reference = WorkoutEngineBridge.migratedV2History(from: [payload])
            .first?.references?.first(where: { $0.progressionContext == weighted.progressionContext })

        #expect(reference == nil)
        let evidence = WorkoutEngineBridge.migratedV2History(from: [payload]).first?.confirmedWorkEvidence?
            .first(where: { $0.exerciseId == weighted.exerciseId })
        #expect(evidence?.confirmedSets.map(\.loadKg) == snapshot.recordedSets.map(\.perUnitWeightKg))
    }

    @Test("An incompatible V2 snapshot is exposed before any new mutation")
    func incompatibleV2SnapshotIsBlockedOnLoad() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 20,
            engineVersion: .previewV2,
            todaySupports: WorkoutSupportProfile.internalV1Assumptions,
            now: start
        )
        guard let current = prepared.v2Context else {
            Issue.record("La preview V2 aurait dû produire un contexte")
            return
        }
        let oldContext = ActiveWorkoutV2Context(
            catalogVersion: "fixture-v1.9.0",
            decisionPolicyVersion: "1.9.0",
            mode: current.mode,
            durationMinutes: current.durationMinutes,
            estimatedSeconds: current.estimatedSeconds,
            plan: current.plan,
            inventory: current.inventory,
            supports: current.supports
        )
        let snapshot = ActiveSessionCoordinator.start(
            decision: prepared.decision,
            v2Context: oldContext,
            now: start
        )
        let loaded = try ActiveSessionCoordinator.load(
            ActiveWorkoutRecord(snapshot: snapshot, now: start)
        )

        #expect(!loaded.v2ContextIsCompatible)
        #expect(loaded.snapshot.recordedSets.isEmpty)
    }

    @Test("A partial V1 movement is not migrated as completed V2 history")
    func v2PreviewMigratesOnlyCompletedV1Movements() throws {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let endedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let v1 = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: endedAt
        )
        var snapshot = ActiveSessionCoordinator.start(decision: v1)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: endedAt)
        let completed = try CompletedWorkoutRecord(
            payload: WorkoutHistoryBuilder.payload(from: snapshot, endedAt: endedAt)
        )

        let preview = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            completedWorkouts: [completed],
            engineVersion: .previewV2,
            todaySupports: ["wall_or_stable_plane"],
            now: endedAt.addingTimeInterval(86_400)
        )

        #expect(!preview.reasonCodes.contains("history.v1_completion_migrated_without_reference"))
    }

    @Test("An explicit equal calibration changes both body regions")
    func explicitCalibrationReachesEngine() {
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: adjustableInventory(),
            durationMinutes: 30,
            calibrations: Calibrations(upper: "foundation", lower: "foundation"),
            calibrationIsExplicit: true
        )

        #expect(decision.planProfileId == "foundation-foundation-12")
        #expect(decision.movements?.map(\.exerciseKey) == [
            "foundation_one_arm_row",
            "goblet_squat",
            "foundation_floor_press",
            "romanian_deadlift"
        ])
        #expect(decision.reasonCodes.contains("calibration.user_selected_variants"))
    }

    @Test("Adjustable equipment requests two explicit local markers")
    func setupRequiresRelevantCalibration() throws {
        let setup = try UserSetupRecord(inventory: adjustableInventory())

        #expect(setup.requiresCalibration)
        #expect(!setup.calibrationIsExplicit)

        setup.upperCalibration = "established"
        setup.lowerCalibration = "foundation"
        setup.calibrationCompletedAt = .now

        #expect(!setup.requiresCalibration)
        #expect(setup.calibrationIsExplicit)
        #expect(setup.calibrations.upper == "established")
        #expect(setup.calibrations.lower == "foundation")
    }

    @Test("A first calibration never presents a technical default as chosen")
    func firstCalibrationStartsWithoutSelections() throws {
        let setup = try UserSetupRecord(inventory: adjustableInventory())

        #expect(CalibrationView.initialChoice(
            rawValue: setup.upperCalibration,
            isEditing: setup.calibrationIsExplicit
        ) == nil)
        #expect(CalibrationView.initialChoice(
            rawValue: setup.lowerCalibration,
            isEditing: setup.calibrationIsExplicit
        ) == nil)

        setup.upperCalibration = "foundation"
        setup.lowerCalibration = "established"
        setup.calibrationCompletedAt = .now

        #expect(CalibrationView.initialChoice(
            rawValue: setup.upperCalibration,
            isEditing: setup.calibrationIsExplicit
        ) == .foundation)
        #expect(CalibrationView.initialChoice(
            rawValue: setup.lowerCalibration,
            isEditing: setup.calibrationIsExplicit
        ) == .established)
    }

    @Test("Removing adjustable equipment makes persisted markers neutral")
    func removedAdjustableEquipmentDisablesCalibration() throws {
        let setup = try UserSetupRecord(
            inventory: adjustableInventory(),
            upperCalibration: "established",
            lowerCalibration: "foundation",
            calibrationCompletedAt: .now
        )

        #expect(setup.usesExplicitCalibration)

        setup.inventory = [
            EquipmentItem(
                category: "bodyweight",
                units: 1,
                supportedConfigurations: ["bodyweight"]
            )
        ]
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: setup.inventory,
            durationMinutes: 20,
            calibrations: setup.usesExplicitCalibration ? setup.calibrations : nil,
            calibrationIsExplicit: setup.usesExplicitCalibration
        )

        #expect(setup.calibrationIsExplicit)
        #expect(!setup.usesExplicitCalibration)
        #expect(!setup.requiresCalibration)
        #expect(!decision.reasonCodes.contains("calibration.user_selected_variants"))
        #expect(decision.planProfileId == "bodyweight-8")
    }

    @Test("A movement exclusion changes the plan and remains in its snapshot")
    func sessionMovementExclusionRemainsTruthful() {
        let inventory = [
            EquipmentItem(
                category: "bodyweight",
                units: 1,
                supportedConfigurations: ["bodyweight"]
            )
        ] + adjustableInventory()
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 30,
            limitations: [
                Limitation(
                    id: "session_movement_exclusion",
                    excludedExerciseKeys: ["romanian_deadlift"]
                )
            ]
        )
        let snapshot = ActiveSessionCoordinator.start(decision: decision)

        #expect(decision.decision == "generate_workout")
        #expect(decision.excludedExerciseKeys == ["romanian_deadlift"])
        #expect(decision.movements?.contains {
            $0.variant == "dumbbell_romanian_deadlift"
        } == false)
        #expect(decision.movements?.contains {
            $0.exerciseKey == "bodyweight_hinge"
        } == true)
        #expect(decision.reasonCodes.contains("limitation.user_excluded_movement"))
        #expect(snapshot.decision.excludedExerciseKeys == ["romanian_deadlift"])
    }

    @Test("An impossible movement selection preserves the chosen recovery state")
    func impossibleMovementExclusionPreservesInput() {
        let inventory = [
            EquipmentItem(
                category: "bodyweight",
                units: 1,
                supportedConfigurations: ["bodyweight"]
            )
        ]
        let excluded = ["bodyweight_hinge", "bodyweight_squat", "incline_pushup"]
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            limitations: [
                Limitation(
                    id: "session_movement_exclusion",
                    excludedExerciseKeys: excluded
                )
            ]
        )

        #expect(decision.decision == "request_valid_input")
        #expect(decision.preserveInput == true)
        #expect(decision.excludedExerciseKeys == excluded)
        #expect(decision.reasonCodes.contains("limitation.no_compatible_plan"))
    }

    @Test("A set and its rest state remain deterministic")
    func activeSessionTransitions() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: start)
        #expect(snapshot.completedSetCount == 1)
        #expect(snapshot.restDeadline == start.addingTimeInterval(90))
        #expect(snapshot.recordedSets.last?.plannedRestSeconds == 90)
        #expect(snapshot.recordedSets.last?.actualRestSeconds == nil)

        snapshot = ActiveSessionCoordinator.pauseRest(snapshot, now: start.addingTimeInterval(30))
        #expect(snapshot.pausedRemainingSeconds == 60)
        #expect(snapshot.restDeadline == nil)

        snapshot = ActiveSessionCoordinator.resumeRest(snapshot, now: start.addingTimeInterval(35))
        #expect(snapshot.restDeadline == start.addingTimeInterval(95))
        #expect(snapshot.pausedRemainingSeconds == nil)

        snapshot = ActiveSessionCoordinator.completeRest(snapshot, now: start.addingTimeInterval(96))
        #expect(snapshot.currentMovementIndex == 0)
        #expect(snapshot.restDeadline == nil)
        #expect(snapshot.recordedSets.last?.restEndedAt == start.addingTimeInterval(96))
        #expect(snapshot.recordedSets.last?.actualRestSeconds == 96)
    }

    @Test("An early rest remains a factual observation without changing the prescription")
    func shortenedRestIsRecorded() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: start)
        snapshot = ActiveSessionCoordinator.completeRest(
            snapshot,
            now: start.addingTimeInterval(30)
        )

        #expect(snapshot.recordedSets.last?.plannedRestSeconds == 90)
        #expect(snapshot.recordedSets.last?.actualRestSeconds == 30)
        #expect(snapshot.decision == decision)
        #expect(snapshot.completedSetCount == 1)
    }

    @Test("A saved set from before rest observations remains decodable")
    func legacyCompletedSetRemainsDecodable() throws {
        struct LegacyCompletedSet: Encodable {
            let eventID: String
            let exerciseKey: String
            let repetitions: Int
            let perUnitWeightKg: Double?
            let completedAt: Date
        }

        let legacy = LegacyCompletedSet(
            eventID: "legacy-set",
            exerciseKey: "incline_pushup",
            repetitions: 8,
            perUnitWeightKg: nil,
            completedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let decoded = try JSONDecoder().decode(
            CompletedSetRecord.self,
            from: JSONEncoder().encode(legacy)
        )

        #expect(decoded.eventID == legacy.eventID)
        #expect(decoded.plannedRestSeconds == nil)
        #expect(decoded.restEndedAt == nil)
        #expect(decoded.actualRestSeconds == nil)
    }

    @Test("Pain at three stops the set and remains a factual maximum")
    func painStopsCurrentSet() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: now
        )
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.reportPain(snapshot, score: 3, now: now)

        #expect(snapshot.completedSetCount == 0)
        #expect(snapshot.unresolvedSafetyEvent?.transition == "stop_current_set")
        #expect(snapshot.feedback?.discomfort == 3)

        snapshot = ActiveSessionCoordinator.resolveSafetyEvent(
            snapshot,
            action: .reduceRange,
            now: now.addingTimeInterval(1)
        )
        snapshot = ActiveSessionCoordinator.updateFeedback(snapshot, value: 1, field: .discomfort)
        let payload = WorkoutHistoryBuilder.payload(from: snapshot, endedAt: now)

        #expect(snapshot.unresolvedSafetyEvent == nil)
        #expect(snapshot.recordedSafetyEvents.last?.chosenAction == "reduce_range")
        #expect(!snapshot.isFinished)
        #expect(payload.historySession.painScore == 3)
    }

    @Test("Pain at five stops the movement and cannot resume it")
    func painStopsCurrentExercise() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: now
        )
        let initial = ActiveSessionCoordinator.start(decision: decision)
        let stopped = ActiveSessionCoordinator.reportPain(initial, score: 5, now: now)
        let invalidResume = ActiveSessionCoordinator.resolveSafetyEvent(
            stopped,
            action: .reduceRange,
            now: now.addingTimeInterval(1)
        )
        let nextMovement = ActiveSessionCoordinator.resolveSafetyEvent(
            stopped,
            action: .stopExercise,
            now: now.addingTimeInterval(1)
        )

        #expect(stopped.unresolvedSafetyEvent?.transition == "stop_current_exercise")
        #expect(invalidResume == stopped)
        #expect(nextMovement.currentMovementIndex == 1)
        #expect(nextMovement.skippedExerciseKeys.contains("incline_pushup"))
        #expect(nextMovement.recordedSafetyEvents.last?.chosenAction == "stop_exercise")
    }

    @Test("An urgent alert ends the session without diagnosing")
    func urgentAlertStopsAndOrients() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: now
        )
        let initial = ActiveSessionCoordinator.start(decision: decision)
        var stopped = ActiveSessionCoordinator.reportUrgentAlert(initial, now: now)

        #expect(stopped.isFinished)
        #expect(stopped.endedEarly)
        #expect(stopped.endedAt == now)
        #expect(stopped.unresolvedSafetyEvent?.transition == "stop_session_and_orient")
        #expect(stopped.unresolvedSafetyEvent?.mustNotDiagnose == true)

        stopped = ActiveSessionCoordinator.resolveSafetyEvent(
            stopped,
            action: .acknowledgeOrientation,
            now: now.addingTimeInterval(1)
        )

        #expect(stopped.unresolvedSafetyEvent == nil)
        #expect(stopped.isFinished)
        #expect(stopped.recordedSafetyEvents.last?.chosenAction == "acknowledge_orientation")
    }

    @Test("A corrupted current snapshot falls back to the previous valid snapshot")
    func previousSnapshotRecovery() throws {
        let schema = Schema([UserSetupRecord.self, ActiveWorkoutRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        let initial = ActiveSessionCoordinator.start(decision: decision)
        let record = try ActiveWorkoutRecord(snapshot: initial)
        context.insert(record)
        try context.save()

        let updated = ActiveSessionCoordinator.recordSet(initial, repetitions: 8)
        try ActiveSessionCoordinator.persist(updated, in: record, context: context)
        record.snapshotData = Data("invalid".utf8)

        let loaded = try ActiveSessionCoordinator.load(record)
        #expect(loaded.restoredPreviousSnapshot)
        #expect(loaded.snapshot == initial)

        try ActiveSessionCoordinator.repair(loaded.snapshot, in: record, context: context)
        record.snapshotData = Data("invalid-again".utf8)

        let loadedAfterRepair = try ActiveSessionCoordinator.load(record)
        #expect(loadedAfterRepair.restoredPreviousSnapshot)
        #expect(loadedAfterRepair.snapshot == initial)
    }

    @Test("A weighted set accepts only a declared load")
    func loadConfirmationUsesInventory() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
            EquipmentItem(
                category: "fixed_dumbbell",
                units: 2,
                weightKg: 8,
                supportedConfigurations: ["pair", "single", "central", "unilateral"]
            ),
            EquipmentItem(category: "pullup_bar", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 30)
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot.currentMovementIndex = decision.movements?.firstIndex {
            $0.exerciseKey == "fixed_goblet_squat"
        } ?? 0

        let invalid = ActiveSessionCoordinator.confirmLoad(
            snapshot,
            exerciseKey: "fixed_goblet_squat",
            perUnitWeightKg: 12,
            inventory: inventory
        )
        #expect(invalid.confirmedLoads["fixed_goblet_squat"] == nil)

        let valid = ActiveSessionCoordinator.confirmLoad(
            snapshot,
            exerciseKey: "fixed_goblet_squat",
            perUnitWeightKg: 8,
            inventory: inventory
        )
        #expect(valid.confirmedLoads["fixed_goblet_squat"] == 8)
    }

    @Test("The last set can be corrected without changing earlier facts")
    func correctLastSet() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: start)
        snapshot = ActiveSessionCoordinator.endEarly(
            snapshot,
            now: start.addingTimeInterval(30)
        )
        let eventID = snapshot.recordedSets.last?.eventID
        let endedAt = snapshot.endedAt

        let corrected = ActiveSessionCoordinator.correctLastSet(
            snapshot,
            repetitions: 10,
            perUnitWeightKg: nil,
            inventory: inventory
        )

        #expect(corrected.completedSetCount == 1)
        #expect(corrected.recordedSets.map(\.repetitions) == [10])
        #expect(corrected.recordedSets.last?.eventID == eventID)
        #expect(corrected.currentMovementIndex == 0)
        #expect(corrected.completedSetsInMovement == 1)
        #expect(corrected.isFinished)
        #expect(corrected.endedEarly)
        #expect(corrected.endedAt == endedAt)
    }

    @Test("A factual summary keeps optional feedback absent")
    func factualHistoryKeepsMissingFeedbackNil() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8)

        let payload = WorkoutHistoryBuilder.payload(from: snapshot)

        #expect(payload.historySession.effort == nil)
        #expect(payload.historySession.painScore == nil)
        #expect(payload.historySession.exerciseRecords?.first?.completedReps == 8)
        #expect(payload.historySession.exerciseRecords?.first?.lastSetRir == nil)
    }

    @Test("Feedback edits never move the factual session end time")
    func feedbackKeepsFrozenEndTime() {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let endedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: endedAt
        )
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: endedAt)
        snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: endedAt.addingTimeInterval(30))
        snapshot = ActiveSessionCoordinator.updateFeedback(snapshot, value: 7, field: .effort)

        let payload = WorkoutHistoryBuilder.payload(from: snapshot)

        #expect(payload.endedAt == endedAt.addingTimeInterval(30))
        #expect(payload.snapshot.endedAt == endedAt.addingTimeInterval(30))
    }

    @Test("A completed weighted session feeds the next engine decision")
    func historyFeedsReadinessRollingStateAndProgression() throws {
        let inventory = adjustableInventory()
        let endedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 45,
            now: endedAt
        )
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.confirmLoad(
            snapshot,
            exerciseKey: "one_arm_row",
            perUnitWeightKg: 8,
            inventory: inventory
        )
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 10, now: endedAt)
        snapshot = ActiveSessionCoordinator.updateFeedback(snapshot, value: 7, field: .effort)
        snapshot = ActiveSessionCoordinator.updateFeedback(snapshot, value: 0, field: .discomfort)
        snapshot = ActiveSessionCoordinator.updateFeedback(
            snapshot,
            value: 2,
            field: .repetitionsInReserve
        )
        let completed = try CompletedWorkoutRecord(
            payload: WorkoutHistoryBuilder.payload(from: snapshot, endedAt: endedAt)
        )

        let next = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 45,
            completedWorkouts: [completed],
            now: endedAt.addingTimeInterval(3 * 86_400)
        )

        #expect(next.progression?.exerciseKey == "one_arm_row")
        #expect(next.progression?.action == "increase_reps")
        #expect(next.rollingPriorityFirst != nil)
        #expect(next.reasonCodes.contains { $0.hasPrefix("rolling.") })
    }

    @Test("Saving the same completed session twice never duplicates history")
    func completionIsIdempotent() throws {
        let schema = Schema([
            UserSetupRecord.self,
            ActiveWorkoutRecord.self,
            CompletedWorkoutRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let decision = WorkoutEngineBridge.nextWorkout(inventory: inventory, durationMinutes: 20)
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8)

        let firstActive = try ActiveWorkoutRecord(snapshot: snapshot)
        context.insert(firstActive)
        try context.save()
        try WorkoutCompletionCoordinator.save(
            snapshot: snapshot,
            activeRecord: firstActive,
            context: context
        )

        let duplicateActive = try ActiveWorkoutRecord(snapshot: snapshot)
        context.insert(duplicateActive)
        try context.save()
        try WorkoutCompletionCoordinator.save(
            snapshot: snapshot,
            activeRecord: duplicateActive,
            context: context
        )

        #expect(try context.fetchCount(FetchDescriptor<CompletedWorkoutRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ActiveWorkoutRecord>()) == 0)
    }

    @Test("An optional makeup never blocks a normal workout")
    func optionalMakeupCanBeDeclined() throws {
        let inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]
        let endedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let decision = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            now: endedAt
        )
        var snapshot = ActiveSessionCoordinator.start(decision: decision)
        snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8, now: endedAt)
        snapshot = ActiveSessionCoordinator.endEarly(snapshot, now: endedAt)
        let noFeedback = try CompletedWorkoutRecord(
            payload: WorkoutHistoryBuilder.payload(from: snapshot, endedAt: endedAt)
        )

        let withoutAnswer = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            completedWorkouts: [noFeedback],
            now: endedAt.addingTimeInterval(3_600)
        )

        snapshot = ActiveSessionCoordinator.updateFeedback(snapshot, value: 0, field: .discomfort)
        let completed = try CompletedWorkoutRecord(
            payload: WorkoutHistoryBuilder.payload(from: snapshot)
        )

        let makeup = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            completedWorkouts: [completed],
            now: endedAt.addingTimeInterval(3_600)
        )
        let normal = WorkoutEngineBridge.nextWorkout(
            inventory: inventory,
            durationMinutes: 20,
            completedWorkouts: [completed],
            allowOptionalMakeup: false,
            now: endedAt.addingTimeInterval(3_600)
        )

        #expect(withoutAnswer.decision == "generate_workout")
        #expect(makeup.decision == "generate_makeup")
        #expect(makeup.makeup?.createsDebt == false)
        #expect(normal.decision == "generate_workout")
        #expect(normal.movements?.isEmpty == false)
        #expect(completed.historySession?.endedEarly == true)
    }

    @Test("The first workout is free and the next requires an entitlement")
    func subscriptionAccessStartsAfterTheFirstWorkout() {
        #expect(SubscriptionAccessPolicy.canPrepareWorkout(
            completedWorkoutCount: 0,
            hasActiveSubscription: false
        ))
        #expect(!SubscriptionAccessPolicy.canPrepareWorkout(
            completedWorkoutCount: 1,
            hasActiveSubscription: false
        ))
        #expect(SubscriptionAccessPolicy.canPrepareWorkout(
            completedWorkoutCount: 1,
            hasActiveSubscription: true
        ))
    }

    @Test("The first paywall waits for entitlement verification")
    func firstPaywallWaitsForEntitlements() {
        #expect(!SubscriptionAccessPolicy.shouldPresentFirstPaywall(
            isPending: true,
            completedWorkoutCount: 1,
            entitlementsLoaded: false,
            hasActiveSubscription: false
        ))
        #expect(SubscriptionAccessPolicy.shouldPresentFirstPaywall(
            isPending: true,
            completedWorkoutCount: 1,
            entitlementsLoaded: true,
            hasActiveSubscription: false
        ))
        #expect(!SubscriptionAccessPolicy.shouldPresentFirstPaywall(
            isPending: true,
            completedWorkoutCount: 1,
            entitlementsLoaded: true,
            hasActiveSubscription: true
        ))
    }

    @Test("A pending Apple purchase blocks duplicate purchase controls")
    func pendingPurchaseBlocksDuplicateActions() {
        #expect(SubscriptionStore.PurchaseState.pending.blocksFurtherPurchases)
        #expect(SubscriptionStore.PurchaseState.purchasing("annual").blocksFurtherPurchases)
        #expect(!SubscriptionStore.PurchaseState.idle.blocksFurtherPurchases)
        #expect(!SubscriptionStore.PurchaseState.failed("retry").blocksFurtherPurchases)
    }

    @Test("Only the lifetime non-consumable unlocks paid access")
    func lifetimeProductRequiresCorrectType() {
        #expect(SubscriptionAccessPolicy.isLifetimeProduct(productID: SubscriptionStore.lifetimeProductID, type: .nonConsumable))
        #expect(!SubscriptionAccessPolicy.isLifetimeProduct(productID: SubscriptionStore.lifetimeProductID, type: .autoRenewable))
        #expect(!SubscriptionAccessPolicy.isLifetimeProduct(productID: SubscriptionStore.lifetimeProductID, type: .consumable))
        #expect(!SubscriptionAccessPolicy.isLifetimeProduct(productID: "unknown", type: .nonConsumable))
    }

    @Test("A persistent refusal remains configuration-scoped and explicit")
    func persistentRefusalIsAppliedByTheBridge() {
        let decision = WorkoutEngineBridge.nextWorkoutV2Preview(
            persistentInventory: adjustableInventory(),
            durationMinutes: 30,
            persistentRefusals: ["dumbbell_floor_press__adjustable"],
            todaySupports: ["wall_or_stable_plane", "floor_allowed", "stable_hand_support"]
        )

        #expect(decision.plan.contains { $0.exerciseId == "dumbbell_floor_press__adjustable" } == false)
        #expect(decision.reasons.contains { $0.code == "refusal_persistent" })
    }

    @Test("The standard engine blocks only an explicitly declared excluded scope")
    func declaredScopeBlocksStandardEngine() {
        let decision = WorkoutEngineBridge.nextWorkoutV2Preview(
            persistentInventory: adjustableInventory(),
            durationMinutes: 20,
            todaySupports: ["wall_or_stable_plane"],
            declaredScope: .pregnancy
        )
        #expect(decision.decision == .blockStandardMode)
        #expect(decision.plan.isEmpty)
    }

    @Test("A current health signal stops preparation without a diagnosis branch")
    func currentHealthSignalStopsPreparation() {
        let decision = WorkoutEngineBridge.nextWorkoutV2Preview(
            persistentInventory: adjustableInventory(),
            durationMinutes: 20,
            todaySupports: ["wall_or_stable_plane"],
            declaredCurrentHealthSignal: true
        )
        #expect(decision.decision == .stopStandardSession)
        #expect(decision.reasons.map(\.code) == ["safety_stop_session"])
    }

    @Test("The approved media manifest covers the release catalogue")
    func mediaManifestIsReadyForFinalAssets() {
        #expect(MovementMediaManifest.all.count == 42)
        #expect(Set(MovementMediaManifest.all.map(\.id)).count == 42)
        #expect(MovementMediaManifest.all.allSatisfy { $0.status == .ready })
        #expect(MovementMediaManifest.releaseIsComplete)
    }

    @Test("All 42 reviewed videos and still alternatives actually load from the app bundle")
    func reviewedMediaResourcesLoad() async throws {
        for media in MovementMediaManifest.all {
            let url = try #require(MovementMediaManifest.resourceURL(media.videoFilename))
            let video = AVURLAsset(url: url)
            let tracks = try await video.loadTracks(withMediaType: .video)
            #expect(tracks.count == 1)
            #expect(abs(try await video.load(.duration).seconds - 4) < 0.05)
            for filename in [media.posterFilename, media.fallbackFilename] {
                let still = try #require(MovementMediaManifest.resourceURL(filename))
                #expect(UIImage(contentsOfFile: still.path) != nil)
            }
            #expect(!media.accessibilitySummary.isEmpty)
        }
        #expect(MovementMediaManifest.asset(for: "dumbbell_floor_press__adjustable")?.id == "dumbbell_floor_press")
    }

    @Test("Holds, eccentric demonstration and power/accessibility settings never loop")
    func mediaPlaybackPolicy() {
        #expect(MovementMediaManifest.asset(for: "front_plank")?.playback == .hold)
        #expect(MovementMediaManifest.asset(for: "side_plank")?.playback == .hold)
        #expect(MovementMediaManifest.asset(for: "elevated_front_plank")?.playback == .hold)
        #expect(MovementMediaManifest.asset(for: "eccentric_pull_up")?.playback == .singlePass)
        for kind in [MovementMediaPlayback.loop, .singlePass, .hold] {
            #expect(!MovementMediaPresentation.shouldLoop(kind: kind, reduceMotion: true, lowPower: false))
            #expect(!MovementMediaPresentation.shouldLoop(kind: kind, reduceMotion: false, lowPower: true))
        }
        #expect(MovementMediaPresentation.shouldLoop(kind: .loop, reduceMotion: false, lowPower: false))
        #expect(!MovementMediaPresentation.shouldLoop(kind: .singlePass, reduceMotion: false, lowPower: false))
        #expect(MovementMediaPresentation.select(status: .reviewedPreview, reduceMotion: true, playbackRequested: false, videoAvailable: true, fallbackAvailable: false, posterAvailable: true) == .poster)
        #expect(MovementMediaPresentation.select(status: .reviewedPreview, reduceMotion: true, playbackRequested: false, videoAvailable: true, fallbackAvailable: false, posterAvailable: false) == .placeholder)
    }

    @Test("Pause and background resume preserve intent without restarting media")
    func mediaPlaybackLifecycle() throws {
        let media = try #require(MovementMediaManifest.asset(for: "goblet_squat"))
        let url = try #require(MovementMediaManifest.resourceURL(media.videoFilename))
        let playback = MovementVideoPlayback()
        playback.prepare(url: url, loops: true, autoplay: false)
        #expect(!playback.isPlaying)
        playback.toggle()
        #expect(playback.isPlaying)
        playback.suspend()
        playback.suspend()
        #expect(!playback.isPlaying)
        playback.resumeAfterBackground()
        #expect(playback.isPlaying)
        playback.toggle()
        playback.suspend()
        playback.resumeAfterBackground()
        #expect(!playback.isPlaying)
        playback.prepare(url: url, loops: false, autoplay: true)
        #expect(!playback.isPlaying)
        playback.prepare(url: url, loops: true, autoplay: true)
        #expect(!playback.isPlaying)
        playback.toggle()
        #expect(playback.isPlaying)
        playback.stop()
        #expect(playback.player.items().isEmpty)
    }

    @Test("A single-pass demonstration ends and can be explicitly replayed")
    func singlePassMediaCanReplay() async throws {
        let media = try #require(MovementMediaManifest.asset(for: "eccentric_pull_up"))
        let url = try #require(MovementMediaManifest.resourceURL(media.videoFilename))
        let playback = MovementVideoPlayback()
        playback.prepare(url: url, loops: false, autoplay: true)
        defer { playback.stop() }
        try await Task.sleep(for: .seconds(5))
        #expect(playback.finished)
        #expect(!playback.isPlaying)
        #expect(!playback.hasStarted)
        playback.toggle()
        try await Task.sleep(for: .milliseconds(350))
        #expect(playback.isPlaying)
        #expect(!playback.finished)
    }

    @Test("An unreadable video fails into the still-image path")
    func unreadableMediaDoesNotRemainPlaying() async throws {
        let playback = MovementVideoPlayback()
        playback.prepare(url: URL(fileURLWithPath: "/missing-lbs-media/\(UUID()).mp4"), loops: false, autoplay: true)
        defer { playback.stop() }
        try await Task.sleep(for: .seconds(2))
        #expect(playback.failed)
        #expect(!playback.isPlaying)
        #expect(MovementMediaPresentation.select(status: .reviewedPreview, reduceMotion: false, playbackRequested: true, videoAvailable: false, fallbackAvailable: true, posterAvailable: true) == .fallback)
    }

    @Test("The approved brand assets and Archivo faces are bundled")
    func approvedBrandAssetsAreBundled() {
        BrandFontRegistry.register()

        #expect(BrandFontRegistry.isAvailable)
        #expect(UIImage(named: "BrandPoster") != nil)
        #expect(UIImage(named: "RibbonMark") != nil)
    }

    @Test("The approved logo renders at every required control size")
    func approvedLogoRendersAtRequiredSizes() {
        for size in [48.0, 32.0, 24.0, 16.0] {
            let renderer = ImageRenderer(
                content: LBSMark(style: size < 24 ? .twoColor : .color)
                    .frame(width: size, height: size)
            )
            renderer.scale = 3
            #expect(renderer.uiImage != nil)
        }
    }

    @Test("Reduce Motion uses the three-phase fallback before explicit playback")
    func reducedMotionSelectsStaticFallback() {
        #expect(MovementMediaPresentation.select(
            status: .ready,
            reduceMotion: true,
            playbackRequested: false,
            videoAvailable: true,
            fallbackAvailable: true,
            posterAvailable: true
        ) == .fallback)
        #expect(MovementMediaPresentation.select(
            status: .ready,
            reduceMotion: true,
            playbackRequested: true,
            videoAvailable: true,
            fallbackAvailable: true,
            posterAvailable: true
        ) == .video)
        #expect(MovementMediaPresentation.select(
            status: .ready,
            reduceMotion: false,
            playbackRequested: false,
            videoAvailable: false,
            fallbackAvailable: true,
            posterAvailable: true
        ) == .fallback)
    }

    @Test("An older setup adopts the simplified everyday support assumptions")
    func legacySetupRequiresSupportProfile() throws {
        let setup = try UserSetupRecord(
            inventory: [
                EquipmentItem(
                    category: "bodyweight",
                    units: 1,
                    supportedConfigurations: ["bodyweight"]
                )
            ]
        )
        #expect(setup.requiresSupportProfile)
        setup.supportProfile = UserSupportProfile(
            floorAllowed: false,
            stableSeatOrBench: false,
            solidWall: false,
            overheadClearance: false,
            travelSpace: false,
            bandFootSetupAllowed: false,
            pullupClearance: false,
            pullupTopStartSupport: false,
            bandOnPullupBarAllowed: false,
            dipBarsRowSafe: false,
            floorGripSafe: false,
            stepUpApprovedSupport: false,
            hipThrustBenchApproved: false
        )
        #expect(!setup.requiresSupportProfile)
        let supportKeys = Set(setup.supportProfile?.engineSupportKeys ?? [])
        #expect(supportKeys.isSuperset(of: [
            "floor_allowed", "seated_support", "stable_hand_support", "stable_incline_support",
            "wall_or_stable_plane", "overhead_clearance", "travel_space"
        ]))
    }

    private func adjustableInventory() -> [EquipmentItem] {
        [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"]),
            EquipmentItem(
                category: "adjustable_dumbbell",
                units: 2,
                perUnitWeightsKg: [4, 6, 8, 10],
                supportedConfigurations: ["pair", "single", "central", "unilateral"]
            )
        ]
    }
}
