import CadenceEngine
import Foundation
import SwiftData

@Model
final class UserSetupRecord {
    var recordID: String
    var inventoryData: Data
    var equipmentDraftData: Data?
    var selectedDuration: Int
    var updatedAt: Date
    var upperCalibration: String?
    var lowerCalibration: String?
    var calibrationCompletedAt: Date?
    var supportProfileData: Data?
    var declaredScopeRaw: String?
    var persistentRefusalsData: Data?
    var strengthPracticeRaw: String?
    var movementKnowledgeData: Data?

    var strengthPractice: V2StrengthPractice? {
        get { strengthPracticeRaw.flatMap(V2StrengthPractice.init(rawValue:)) }
        set { strengthPracticeRaw = newValue?.rawValue }
    }

    func movementKnowledge() throws -> [V2MovementKnowledge] {
        guard let movementKnowledgeData else { return [] }
        return try JSONDecoder().decode([V2MovementKnowledge].self, from: movementKnowledgeData)
    }

    init(
        recordID: String = "primary",
        inventory: [EquipmentItem],
        selectedDuration: Int = 30,
        upperCalibration: String? = nil,
        lowerCalibration: String? = nil,
        calibrationCompletedAt: Date? = nil,
        supportProfile: UserSupportProfile? = nil,
        declaredScope: V2DeclaredScope? = nil,
        persistentRefusals: [String] = [],
        updatedAt: Date = .now
    ) throws {
        self.recordID = recordID
        inventoryData = try JSONEncoder().encode(inventory)
        self.selectedDuration = selectedDuration
        self.upperCalibration = upperCalibration
        self.lowerCalibration = lowerCalibration
        self.calibrationCompletedAt = calibrationCompletedAt
        supportProfileData = try supportProfile.map { try JSONEncoder().encode($0) }
        declaredScopeRaw = declaredScope?.rawValue
        persistentRefusalsData = try JSONEncoder().encode(persistentRefusals)
        self.updatedAt = updatedAt
    }

    var inventory: [EquipmentItem] {
        get { (try? JSONDecoder().decode([EquipmentItem].self, from: inventoryData)) ?? [] }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            inventoryData = encoded
            updatedAt = .now
        }
    }

    var calibrations: Calibrations {
        Calibrations(
            upper: upperCalibration ?? "foundation",
            lower: lowerCalibration ?? "foundation"
        )
    }

    var calibrationIsExplicit: Bool {
        guard calibrationCompletedAt != nil else { return false }
        let allowed = Set(["foundation", "established"])
        guard let upperCalibration, let lowerCalibration else { return false }
        return allowed.contains(upperCalibration) && allowed.contains(lowerCalibration)
    }

    var hasCalibrationRelevantEquipment: Bool {
        inventory.contains { $0.category == "adjustable_dumbbell" }
    }

    var usesExplicitCalibration: Bool {
        hasCalibrationRelevantEquipment && calibrationIsExplicit
    }

    var requiresCalibration: Bool {
        hasCalibrationRelevantEquipment && !calibrationIsExplicit
    }

    var supportProfile: UserSupportProfile? {
        get {
            guard let supportProfileData else { return nil }
            return try? JSONDecoder().decode(UserSupportProfile.self, from: supportProfileData)
        }
        set {
            supportProfileData = try? newValue.map { try JSONEncoder().encode($0) }
            updatedAt = .now
        }
    }

    var declaredScope: V2DeclaredScope? {
        get { declaredScopeRaw.flatMap(V2DeclaredScope.init(rawValue:)) }
        set {
            declaredScopeRaw = newValue?.rawValue
            updatedAt = .now
        }
    }

    var requiresSupportProfile: Bool { supportProfile == nil }

    var persistentRefusals: [String] {
        get {
            guard let persistentRefusalsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: persistentRefusalsData)) ?? []
        }
        set {
            persistentRefusalsData = try? JSONEncoder().encode(Array(Set(newValue)).sorted())
            updatedAt = .now
        }
    }
}

struct UserSupportProfile: Codable, Equatable {
    // These fields stay Codable so existing saved profiles continue to decode.
    // Everyday conditions are now assumed by `engineSupportKeys`.
    var floorAllowed: Bool
    var stableSeatOrBench: Bool
    var solidWall: Bool
    var overheadClearance: Bool
    var travelSpace: Bool
    var bandFootSetupAllowed: Bool
    var pullupClearance: Bool
    var pullupTopStartSupport: Bool
    var bandOnPullupBarAllowed: Bool
    var dipBarsRowSafe: Bool
    var floorGripSafe: Bool
    var stepUpApprovedSupport: Bool
    var hipThrustBenchApproved: Bool

    var engineSupportKeys: [String] {
        // Everyday movement conditions are assumed instead of asked during onboarding.
        var values = [
            "floor_allowed",
            "seated_support",
            "stable_hand_support",
            "stable_incline_support",
            "wall_or_stable_plane",
            "overhead_clearance",
            "travel_space"
        ]
        if bandFootSetupAllowed {
            values += ["band_under_feet_allowed", "band_around_feet_allowed"]
        }
        if pullupClearance { values.append("pullup_clearance") }
        if pullupTopStartSupport { values.append("pullup_top_start_support") }
        if bandOnPullupBarAllowed {
            values += ["band_over_bar_allowed", "band_on_pullup_bar_allowed"]
        }
        if dipBarsRowSafe { values.append("dip_bars_row_safe") }
        if floorGripSafe { values.append("floor_grip_safe") }
        if stepUpApprovedSupport { values.append("step_up_approved_support") }
        if hipThrustBenchApproved { values.append("hip_thrust_bench_approved") }
        return Array(Set(values)).sorted()
    }

}

@Model
final class ActiveWorkoutRecord {
    var sessionID: String
    var snapshotData: Data
    var previousSnapshotData: Data?
    var startedAt: Date
    var updatedAt: Date

    init(snapshot: ActiveWorkoutSnapshot, now: Date = .now) throws {
        sessionID = snapshot.sessionID
        snapshotData = try JSONEncoder().encode(snapshot)
        previousSnapshotData = nil
        startedAt = snapshot.startedAt ?? now
        updatedAt = now
    }
}

@Model
final class CompletedWorkoutRecord {
    var sessionID: String
    var endedAt: Date
    var payloadData: Data
    var createdAt: Date
    var sharingEnrollmentID: String?
    var sharedAt: Date?
    var sessionReviewData: Data?

    var sessionReview: SessionReview? {
        guard let sessionReviewData else { return nil }
        return try? JSONDecoder().decode(SessionReview.self, from: sessionReviewData)
    }

    init(payload: CompletedWorkoutPayload, now: Date = .now) throws {
        sessionID = payload.historySession.sessionId
        endedAt = payload.endedAt
        payloadData = try JSONEncoder().encode(payload)
        createdAt = now
    }

    var payload: CompletedWorkoutPayload? {
        try? JSONDecoder().decode(CompletedWorkoutPayload.self, from: payloadData)
    }

    var historySession: HistorySession? {
        payload?.historySession
    }
}

struct CompletedSetRecord: Codable, Equatable, Identifiable {
    let eventID: String
    let exerciseKey: String
    let repetitions: Int
    let prescribedRepetitions: Int?
    let perUnitWeightKg: Double?
    let loadOptionID: String?
    let completedAt: Date
    let plannedRestSeconds: Int?
    var restEndedAt: Date?

    var id: String { eventID }

    var actualRestSeconds: Int? {
        guard plannedRestSeconds != nil, let restEndedAt else { return nil }
        return max(0, Int(restEndedAt.timeIntervalSince(completedAt).rounded()))
    }

    init(
        eventID: String,
        exerciseKey: String,
        repetitions: Int,
        perUnitWeightKg: Double?,
        loadOptionID: String? = nil,
        completedAt: Date,
        plannedRestSeconds: Int?,
        restEndedAt: Date?,
        prescribedRepetitions: Int? = nil
    ) {
        self.eventID = eventID
        self.exerciseKey = exerciseKey
        self.repetitions = repetitions
        self.prescribedRepetitions = prescribedRepetitions
        self.perUnitWeightKg = perUnitWeightKg
        self.loadOptionID = loadOptionID
        self.completedAt = completedAt
        self.plannedRestSeconds = plannedRestSeconds
        self.restEndedAt = restEndedAt
    }
}

struct SafetyEventRecord: Codable, Equatable, Identifiable {
    let eventID: String
    let exerciseKey: String?
    let kind: String
    let painScore: Int?
    let alertCodes: [String]
    let reportedAt: Date
    let transition: String
    let mustNotDiagnose: Bool
    var chosenAction: String?

    var id: String { eventID }
}

struct WorkoutFeedback: Codable, Equatable {
    var effort: Int?
    var discomfort: Int?
    var repetitionsInReserve: Int?

    static let empty = WorkoutFeedback(
        effort: nil,
        discomfort: nil,
        repetitionsInReserve: nil
    )
}

struct CompletedWorkoutPayload: Codable, Equatable {
    let endedAt: Date
    let snapshot: ActiveWorkoutSnapshot
    let feedback: WorkoutFeedback
    let historySession: HistorySession
}

struct PreparedWorkout: Equatable {
    let decision: EngineDecision
    let v2Context: ActiveWorkoutV2Context?
    var personalizationResult: V2PersonalizedSessionResult? = nil
}

struct ActiveWorkoutV2Context: Codable, Equatable {
    let catalogVersion: String
    let decisionPolicyVersion: String
    let mode: V2SessionMode
    let durationMinutes: Int
    var estimatedSeconds: Int
    var plan: [V2PlanItem]
    let inventory: [V2InventoryItem]
    let supports: [String]
    // Explicit experiment only; missing/false retains the historical time budget.
    var automaticDurationExperiment: Bool? = nil
    var personalization: NativePersonalizationContext? = nil
}

struct ActiveWorkoutSnapshot: Codable, Equatable {
    var sessionID: String
    var decision: EngineDecision
    var currentMovementIndex: Int
    var completedSetsInMovement: Int
    var completedSetCount: Int
    var processedEventIDs: [String]
    var lastCompletedReps: Int?
    var restDeadline: Date?
    var pausedRemainingSeconds: Int?
    var originalRestSeconds: Int?
    var skippedExerciseKeys: [String]
    var isFinished: Bool
    var endedEarly: Bool
    var endedAt: Date?
    var setResults: [CompletedSetRecord]?
    var confirmedLoadsKg: [String: Double]?
    var confirmedLoadOptions: [String: String]?
    var feedback: WorkoutFeedback?
    var safetyEventRecords: [SafetyEventRecord]?
    var unresolvedSafetyEventID: String?
    var setStartedAt: Date? = nil
    var startedPrescriptionReps: Int? = nil
    var startedAt: Date? = nil
    var v2Context: ActiveWorkoutV2Context? = nil

    var currentMovement: PrescribedMovement? {
        guard let movements = decision.movements,
              movements.indices.contains(currentMovementIndex) else { return nil }
        return movements[currentMovementIndex]
    }

    var totalSetCount: Int {
        decision.movements?.reduce(0, { $0 + $1.sets }) ?? 0
    }

    var recordedSets: [CompletedSetRecord] {
        setResults ?? []
    }

    var confirmedLoads: [String: Double] {
        confirmedLoadsKg ?? [:]
    }

    var confirmedOptions: [String: String] {
        confirmedLoadOptions ?? [:]
    }

    var recordedSafetyEvents: [SafetyEventRecord] {
        safetyEventRecords ?? []
    }

    var unresolvedSafetyEvent: SafetyEventRecord? {
        guard let unresolvedSafetyEventID else { return nil }
        return recordedSafetyEvents.first { $0.eventID == unresolvedSafetyEventID }
    }

    var maximumReportedPain: Int? {
        recordedSafetyEvents.compactMap(\.painScore).max()
    }
}

struct LoadedActiveWorkout {
    let snapshot: ActiveWorkoutSnapshot
    let restoredPreviousSnapshot: Bool
    let v2ContextIsCompatible: Bool
}
