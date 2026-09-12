import Foundation

public struct EngineCatalog: Sendable {
    public let exercises: [String: ExerciseDefinition]
    public let planProfiles: [String: [PlanRow]]

    public init(
        exercises: [String: ExerciseDefinition],
        planProfiles: [String: [PlanRow]]
    ) {
        self.exercises = exercises
        self.planProfiles = planProfiles
    }
}

public struct ExerciseDefinition: Codable, Equatable, Sendable {
    public let pattern: String
    public let variant: String
    public let calibrationBand: String?
    public let target: String
    public let restSeconds: Int
    public let equipment: [EquipmentRequirement]

    public init(
        pattern: String,
        variant: String,
        calibrationBand: String? = nil,
        target: String,
        restSeconds: Int,
        equipment: [EquipmentRequirement]
    ) {
        self.pattern = pattern
        self.variant = variant
        self.calibrationBand = calibrationBand
        self.target = target
        self.restSeconds = restSeconds
        self.equipment = equipment
    }
}

public struct EquipmentRequirement: Codable, Equatable, Sendable {
    public let category: String
    public let configuration: String

    public init(category: String, configuration: String) {
        self.category = category
        self.configuration = configuration
    }
}

public struct PlanRow: Codable, Equatable, Sendable {
    public let exerciseKey: String
    public let sets: Int

    public init(exerciseKey: String, sets: Int) {
        self.exerciseKey = exerciseKey
        self.sets = sets
    }
}

public struct PrescribedMovement: Codable, Equatable, Sendable {
    public let exerciseKey: String
    public let variant: String
    public let pattern: String
    public let sets: Int
    public let target: String
    public let restSeconds: Int
    public let equipment: [EquipmentRequirement]

    public init(
        exerciseKey: String,
        variant: String,
        pattern: String,
        sets: Int,
        target: String,
        restSeconds: Int,
        equipment: [EquipmentRequirement]
    ) {
        self.exerciseKey = exerciseKey
        self.variant = variant
        self.pattern = pattern
        self.sets = sets
        self.target = target
        self.restSeconds = restSeconds
        self.equipment = equipment
    }
}

public struct EquipmentItem: Codable, Equatable, Sendable {
    public let category: String
    public let units: Int
    public let weightKg: Double?
    public let perUnitWeightsKg: [Double]?
    public let optionIDs: [String]?
    public let supportedConfigurations: [String]

    public init(
        category: String,
        units: Int,
        weightKg: Double? = nil,
        perUnitWeightsKg: [Double]? = nil,
        optionIDs: [String]? = nil,
        supportedConfigurations: [String]
    ) {
        self.category = category
        self.units = units
        self.weightKg = weightKg
        self.perUnitWeightsKg = perUnitWeightsKg
        self.optionIDs = optionIDs
        self.supportedConfigurations = supportedConfigurations
    }

    public func supports(_ configuration: String) -> Bool {
        supportedConfigurations.contains(configuration)
            && !(configuration == "pair" && units < 2)
    }
}

public struct Calibrations: Codable, Equatable, Sendable {
    public let upper: String
    public let lower: String

    public init(upper: String, lower: String) {
        self.upper = upper
        self.lower = lower
    }
}

public struct Limitation: Codable, Equatable, Sendable {
    public let id: String
    public let excludedExerciseKeys: [String]

    public init(id: String, excludedExerciseKeys: [String]) {
        self.id = id
        self.excludedExerciseKeys = excludedExerciseKeys
    }
}

public struct SymptomTracking: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let todayScore: Int?

    public init(enabled: Bool, todayScore: Int?) {
        self.enabled = enabled
        self.todayScore = todayScore
    }
}

public struct ExerciseRecord: Codable, Equatable, Sendable {
    public let exerciseKey: String
    public let configuration: String?
    public let perUnitWeightKg: Double?
    public let topRangeReps: Int?
    public let completedReps: Int?
    public let lastSetRir: Int?

    public init(
        exerciseKey: String,
        configuration: String? = nil,
        perUnitWeightKg: Double? = nil,
        topRangeReps: Int? = nil,
        completedReps: Int? = nil,
        lastSetRir: Int? = nil
    ) {
        self.exerciseKey = exerciseKey
        self.configuration = configuration
        self.perUnitWeightKg = perUnitWeightKg
        self.topRangeReps = topRangeReps
        self.completedReps = completedReps
        self.lastSetRir = lastSetRir
    }
}

public struct HistorySession: Codable, Equatable, Sendable {
    public let sessionId: String
    public let endedAt: String
    public let effort: Int?
    public let painScore: Int?
    public let exerciseRecords: [ExerciseRecord]?
    public let hardRowerFinisher: Bool?
    public let completedExerciseKeys: [String]?
    public let skippedExerciseKeys: [String]?
    public let conditioningCompleted: Bool?
    public let endedEarly: Bool?

    public init(
        sessionId: String,
        endedAt: String,
        effort: Int? = nil,
        painScore: Int? = nil,
        exerciseRecords: [ExerciseRecord]? = nil,
        hardRowerFinisher: Bool? = nil,
        completedExerciseKeys: [String]? = nil,
        skippedExerciseKeys: [String]? = nil,
        conditioningCompleted: Bool? = nil,
        endedEarly: Bool? = nil
    ) {
        self.sessionId = sessionId
        self.endedAt = endedAt
        self.effort = effort
        self.painScore = painScore
        self.exerciseRecords = exerciseRecords
        self.hardRowerFinisher = hardRowerFinisher
        self.completedExerciseKeys = completedExerciseKeys
        self.skippedExerciseKeys = skippedExerciseKeys
        self.conditioningCompleted = conditioningCompleted
        self.endedEarly = endedEarly
    }
}

public struct PatternValues: Codable, Equatable, Sendable {
    public let pull: Double
    public let push: Double
    public let knee: Double
    public let hinge: Double

    public init(pull: Double, push: Double, knee: Double, hinge: Double) {
        self.pull = pull
        self.push = push
        self.knee = knee
        self.hinge = hinge
    }

    public subscript(pattern: String) -> Double {
        switch pattern {
        case "pull": pull
        case "push": push
        case "knee": knee
        default: hinge
        }
    }
}

public struct RollingState: Codable, Equatable, Sendable {
    public let credits7: PatternValues
    public let credits21: PatternValues
    public let targets7: PatternValues
    public let targets21: PatternValues
    public let profilePriorities: PatternValues
    public let daysSinceExposure: PatternValues

    public init(
        credits7: PatternValues,
        credits21: PatternValues,
        targets7: PatternValues,
        targets21: PatternValues,
        profilePriorities: PatternValues,
        daysSinceExposure: PatternValues
    ) {
        self.credits7 = credits7
        self.credits21 = credits21
        self.targets7 = targets7
        self.targets21 = targets21
        self.profilePriorities = profilePriorities
        self.daysSinceExposure = daysSinceExposure
    }
}

public struct ActiveSessionSnapshot: Codable, Equatable, Sendable {
    public let sessionId: String?
    public let version: Int?
    public let checksumValid: Bool?
    public let startedAt: String?
    public let currentExerciseKey: String?
    public let currentSetIndex: Int?
    public let completedSetCount: Int?
    public let restDeadline: String?
    public let pausedRemainingSeconds: Int?
    public let originalRestSeconds: Int?
    public let processedEventIds: [String]?

    public init(
        sessionId: String? = nil,
        version: Int? = nil,
        checksumValid: Bool? = nil,
        startedAt: String? = nil,
        currentExerciseKey: String? = nil,
        currentSetIndex: Int? = nil,
        completedSetCount: Int? = nil,
        restDeadline: String? = nil,
        pausedRemainingSeconds: Int? = nil,
        originalRestSeconds: Int? = nil,
        processedEventIds: [String]? = nil
    ) {
        self.sessionId = sessionId
        self.version = version
        self.checksumValid = checksumValid
        self.startedAt = startedAt
        self.currentExerciseKey = currentExerciseKey
        self.currentSetIndex = currentSetIndex
        self.completedSetCount = completedSetCount
        self.restDeadline = restDeadline
        self.pausedRemainingSeconds = pausedRemainingSeconds
        self.originalRestSeconds = originalRestSeconds
        self.processedEventIds = processedEventIds
    }
}

public struct SessionEvent: Codable, Equatable, Sendable {
    public let eventId: String
    public let type: String
    public let painScore: Int?
    public let redFlags: [String]?
    public let completedReps: Int?
    public let failedVersion: Int?

    public init(
        eventId: String,
        type: String,
        painScore: Int? = nil,
        redFlags: [String]? = nil,
        completedReps: Int? = nil,
        failedVersion: Int? = nil
    ) {
        self.eventId = eventId
        self.type = type
        self.painScore = painScore
        self.redFlags = redFlags
        self.completedReps = completedReps
        self.failedVersion = failedVersion
    }
}

public struct EngineInput: Codable, Equatable, Sendable {
    public let durationMinutes: Int
    public let physiologicalContext: String
    public let symptomTracking: SymptomTracking
    public let inventory: [EquipmentItem]
    public let history: [HistorySession]
    public var calibrations: Calibrations?
    public let calibrationIsExplicit: Bool?
    public var limitations: [Limitation]?
    public let rollingState: RollingState?
    public let activeSession: ActiveSessionSnapshot?
    public let previousValidSnapshot: ActiveSessionSnapshot?
    public let sessionEvent: SessionEvent?
    public let allowOptionalMakeup: Bool?

    public init(
        durationMinutes: Int,
        physiologicalContext: String = "not_specified",
        symptomTracking: SymptomTracking = .init(enabled: false, todayScore: nil),
        inventory: [EquipmentItem],
        history: [HistorySession] = [],
        calibrations: Calibrations? = .init(upper: "foundation", lower: "foundation"),
        calibrationIsExplicit: Bool = false,
        limitations: [Limitation]? = [],
        rollingState: RollingState? = nil,
        activeSession: ActiveSessionSnapshot? = nil,
        previousValidSnapshot: ActiveSessionSnapshot? = nil,
        sessionEvent: SessionEvent? = nil,
        allowOptionalMakeup: Bool = true
    ) {
        self.durationMinutes = durationMinutes
        self.physiologicalContext = physiologicalContext
        self.symptomTracking = symptomTracking
        self.inventory = inventory
        self.history = history
        self.calibrations = calibrations
        self.calibrationIsExplicit = calibrationIsExplicit
        self.limitations = limitations
        self.rollingState = rollingState
        self.activeSession = activeSession
        self.previousValidSnapshot = previousValidSnapshot
        self.sessionEvent = sessionEvent
        self.allowOptionalMakeup = allowOptionalMakeup
    }

    public mutating func applyDefaults(
        calibrations defaultCalibrations: Calibrations,
        limitations defaultLimitations: [Limitation]
    ) {
        calibrations = calibrations ?? defaultCalibrations
        limitations = limitations ?? defaultLimitations
    }
}

public struct Readiness: Codable, Equatable, Sendable {
    public let label: String
    public let factor: Double
    public let rirTarget: String
}

public struct Progression: Codable, Equatable, Sendable {
    public let exerciseKey: String
    public let action: String
    public let perUnitWeightKg: Double
    public let repsDelta: Int
    public let variablesChanged: [String]
}

public struct LoadRecommendation: Codable, Equatable, Sendable {
    public let category: String
    public let configuration: String
    public let perUnitWeightKg: Double?

    public init(
        category: String,
        configuration: String,
        perUnitWeightKg: Double?
    ) {
        self.category = category
        self.configuration = configuration
        self.perUnitWeightKg = perUnitWeightKg
    }
}

public struct MakeupDecision: Codable, Equatable, Sendable {
    public let includedExerciseKeys: [String]
    public let excludedExerciseKeys: [String]
    public let includeConditioning: Bool
    public let createsDebt: Bool
}

public struct RestTimerDecision: Codable, Equatable, Sendable {
    public let deadline: String
    public let remainingSeconds: Int
}

public struct EngineDecision: Codable, Equatable, Sendable {
    public let decision: String
    public var readiness: Readiness?
    public var basePrimarySetBudget: Int?
    public var finalPrimarySetBudget: Int?
    public var planProfileId: String?
    public var plan: [PlanRow]?
    public var movements: [PrescribedMovement]?
    public var recommendedLoads: [LoadRecommendation]?
    public var allowHardRower: Bool?
    public var progression: Progression?
    public var rollingPriorityFirst: String?
    public var excludedExerciseKeys: [String]?
    public var reasonCodes: [String]
    public var blockReason: String?
    public var errorCode: String?
    public var preserveInput: Bool?
    public var recovery: String?
    public var restoredVersion: Int?
    public var makeup: MakeupDecision?
    public var restTimer: RestTimerDecision?
    public var transition: String?
    public var completedSetCount: Int?
    public var offeredActions: [String]?
    public var mustNotDiagnose: Bool?
    public var pausedRemainingSeconds: Int?
    public var restDeadline: String?
    public var inMemoryStatePreserved: Bool?
    public var canRetry: Bool?
    public var canExportRecovery: Bool?

    public init(decision: String, reasonCodes: [String]) {
        self.decision = decision
        self.reasonCodes = reasonCodes
    }
}
