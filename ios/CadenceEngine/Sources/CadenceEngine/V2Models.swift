import Foundation

public enum V2SessionMode: String, Codable, Equatable, Sendable {
    case normal
    case light
    case recalibration
}

public enum V2DecisionName: String, Codable, Equatable, Sendable {
    case requestValidInput = "request_valid_input"
    case blockStandardMode = "block_standard_mode"
    case stopStandardSession = "stop_standard_session"
    case resumeOrAdaptActiveSession = "resume_or_adapt_active_session"
    case generateSession = "generate_session"
    case noCleanSession = "no_clean_session"
    case updatePrescription = "update_prescription"
    case holdPrescription = "hold_prescription"
    case activeSessionTransition = "active_session_transition"
    case stopCurrentMovement = "stop_current_movement"
}

public enum V2LoadMode: String, Codable, Equatable, Sendable {
    case bodyweight
    case singleTotalKg = "single_total_kg"
    case centralTotalKg = "central_total_kg"
    case pairEachKg = "pair_each_kg"
    case bandOption = "band_option"
}

public enum V2TargetUnit: String, Codable, Equatable, Sendable {
    case repetitions
    case seconds
    case intervals
}

public enum V2SelectionRole: String, Codable, Equatable, Sendable {
    case anchor
    case optional
    case conditioning
}

public struct V2EquipmentRequirement: Codable, Equatable, Sendable {
    public let category: String
    public let configuration: String
    public let units: Int

    public init(category: String, configuration: String, units: Int) {
        self.category = category
        self.configuration = configuration
        self.units = units
    }
}

public struct V2InventoryItem: Codable, Equatable, Sendable {
    public let category: String
    public let units: Int
    public let perUnitWeightsKg: [Double]
    public let optionIDs: [String]?
    /// Only an explicitly declared ordering within this item supports load progression.
    public let optionProgressionIsDeclared: Bool?

    public init(category: String, units: Int, perUnitWeightsKg: [Double] = [], optionIDs: [String] = [], optionProgressionIsDeclared: Bool = false) {
        self.category = category
        self.units = units
        self.perUnitWeightsKg = perUnitWeightsKg
        self.optionIDs = optionIDs
        self.optionProgressionIsDeclared = optionProgressionIsDeclared
    }

    public var resolvedOptionIDs: [String] { optionIDs ?? [] }
}

public struct V2RepRange: Codable, Equatable, Sendable {
    public let min: Int
    public let max: Int
    public let entry: Int

    public init(min: Int, max: Int, entry: Int) {
        self.min = min
        self.max = max
        self.entry = entry
    }
}

public struct V2SetRange: Codable, Equatable, Sendable {
    public let min: Int
    public let max: Int

    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }
}

public struct V2Timing: Codable, Equatable, Sendable {
    public let setup: Int
    public let execution: Int
    public let secondSide: Int
    public let rest: Int
    public let transition: Int

    public init(setup: Int, execution: Int, secondSide: Int, rest: Int, transition: Int) {
        self.setup = setup
        self.execution = execution
        self.secondSide = secondSide
        self.rest = rest
        self.transition = transition
    }

    public func cost(forSets sets: Int) -> Int {
        guard sets > 0 else { return 0 }
        return setup + transition
            + sets * (execution + secondSide)
            + max(0, sets - 1) * rest
    }
}

public struct V2ExerciseDefinition: Codable, Equatable, Sendable {
    public let movementId: String?
    public let anchor: String
    public let catalogStatus: String
    public let productPublicationStatus: String
    public let loadMode: V2LoadMode
    public let equipment: [V2EquipmentRequirement]
    public let equipmentAlternatives: [[V2EquipmentRequirement]]?
    public let supports: [String]
    public let repRange: V2RepRange
    public let sets: V2SetRange
    public let timingSeconds: V2Timing
    public let difficultyRank: Int
    public let selectionRank: Int
    public let primaryContributions: [String]
    public let secondaryContributions: [String]
    public let progressionContext: String
    public let targetUnit: V2TargetUnit?
    public let selectionRole: V2SelectionRole?
    /// A material setup alone is not enough to prescribe this configuration initially.
    public let initialCapacityRequired: Bool?

    public init(
        movementId: String? = nil,
        anchor: String,
        catalogStatus: String = "published_in_fixture_catalog",
        productPublicationStatus: String = "candidate_validation_required",
        loadMode: V2LoadMode,
        equipment: [V2EquipmentRequirement] = [],
        equipmentAlternatives: [[V2EquipmentRequirement]]? = nil,
        supports: [String] = [],
        repRange: V2RepRange,
        sets: V2SetRange,
        timingSeconds: V2Timing,
        difficultyRank: Int,
        selectionRank: Int,
        primaryContributions: [String],
        secondaryContributions: [String] = [],
        progressionContext: String,
        targetUnit: V2TargetUnit? = nil,
        selectionRole: V2SelectionRole? = nil,
        initialCapacityRequired: Bool? = nil
    ) {
        self.movementId = movementId
        self.anchor = anchor
        self.catalogStatus = catalogStatus
        self.productPublicationStatus = productPublicationStatus
        self.loadMode = loadMode
        self.equipment = equipment
        self.equipmentAlternatives = equipmentAlternatives
        self.supports = supports
        self.repRange = repRange
        self.sets = sets
        self.timingSeconds = timingSeconds
        self.difficultyRank = difficultyRank
        self.selectionRank = selectionRank
        self.primaryContributions = primaryContributions
        self.secondaryContributions = secondaryContributions
        self.progressionContext = progressionContext
        self.targetUnit = targetUnit
        self.selectionRole = selectionRole
        self.initialCapacityRequired = initialCapacityRequired
    }

    public var resolvedTargetUnit: V2TargetUnit { targetUnit ?? .repetitions }
    public var resolvedSelectionRole: V2SelectionRole { selectionRole ?? .anchor }
    public var resolvedMovementId: String { movementId ?? progressionContext.components(separatedBy: "|").first ?? progressionContext }
    public var resolvedEquipmentAlternatives: [[V2EquipmentRequirement]] {
        equipmentAlternatives ?? [equipment]
    }
}

public struct V2Substitution: Codable, Equatable, Sendable {
    public let from: String
    public let to: String
    public let type: String
    public let rank: Int

    public init(from: String, to: String, type: String, rank: Int) {
        self.from = from
        self.to = to
        self.type = type
        self.rank = rank
    }
}

public struct V2DecisionPolicy: Codable, Equatable, Sendable {
    public let durationBudgetsSeconds: [String: Int]
    public let historyDepthCompletedSessions: Int
    public let returnQuestionAfterDaysWithoutComparableExposure: Int
    public let anchorTieOrder: [String]
    public let rangeCeilingConfirmations: Int

    public init(
        durationBudgetsSeconds: [String: Int],
        historyDepthCompletedSessions: Int,
        returnQuestionAfterDaysWithoutComparableExposure: Int,
        anchorTieOrder: [String],
        rangeCeilingConfirmations: Int
    ) {
        self.durationBudgetsSeconds = durationBudgetsSeconds
        self.historyDepthCompletedSessions = historyDepthCompletedSessions
        self.returnQuestionAfterDaysWithoutComparableExposure = returnQuestionAfterDaysWithoutComparableExposure
        self.anchorTieOrder = anchorTieOrder
        self.rangeCeilingConfirmations = rangeCeilingConfirmations
    }

    private enum CodingKeys: String, CodingKey {
        case durationBudgetsSeconds
        case historyDepthCompletedSessions
        case returnQuestionAfterDaysWithoutComparableExposure
        case anchorTieOrder
        case rangeCeilingConfirmations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durationBudgetsSeconds = try container.decode([String: Int].self, forKey: .durationBudgetsSeconds)
        historyDepthCompletedSessions = try container.decode(Int.self, forKey: .historyDepthCompletedSessions)
        returnQuestionAfterDaysWithoutComparableExposure = try container.decode(
            Int.self,
            forKey: .returnQuestionAfterDaysWithoutComparableExposure
        )
        anchorTieOrder = try container.decode([String].self, forKey: .anchorTieOrder)
        rangeCeilingConfirmations = try container.decode(Int.self, forKey: .rangeCeilingConfirmations)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(durationBudgetsSeconds, forKey: .durationBudgetsSeconds)
        try container.encode(historyDepthCompletedSessions, forKey: .historyDepthCompletedSessions)
        try container.encode(returnQuestionAfterDaysWithoutComparableExposure, forKey: .returnQuestionAfterDaysWithoutComparableExposure)
        try container.encode(anchorTieOrder, forKey: .anchorTieOrder)
        try container.encode(rangeCeilingConfirmations, forKey: .rangeCeilingConfirmations)
    }
}

public struct V2EngineConfiguration: Equatable, Sendable {
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let catalog: [String: V2ExerciseDefinition]
    public let substitutions: [V2Substitution]
    public let policy: V2DecisionPolicy
    public let requiresProductApproval: Bool

    public init(
        catalogVersion: String,
        decisionPolicyVersion: String,
        catalog: [String: V2ExerciseDefinition],
        substitutions: [V2Substitution],
        policy: V2DecisionPolicy,
        requiresProductApproval: Bool = false
    ) {
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.catalog = catalog
        self.substitutions = substitutions
        self.policy = policy
        self.requiresProductApproval = requiresProductApproval
    }
}

public struct V2SessionRequest: Codable, Equatable, Sendable {
    public let durationMinutes: Int
    public let mode: V2SessionMode?
    public let remainingSeconds: Int?

    public init(
        durationMinutes: Int,
        mode: V2SessionMode? = nil,
        remainingSeconds: Int? = nil
    ) {
        self.durationMinutes = durationMinutes
        self.mode = mode
        self.remainingSeconds = remainingSeconds
    }
}

public struct V2Reference: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let loadKg: Double?
    public let loadOptionID: String?
    public let targetReps: Int
    public let progressionContext: String

    public init(
        exerciseId: String,
        loadKg: Double? = nil,
        loadOptionID: String? = nil,
        targetReps: Int,
        progressionContext: String
    ) {
        self.exerciseId = exerciseId
        self.loadKg = loadKg
        self.loadOptionID = loadOptionID
        self.targetReps = targetReps
        self.progressionContext = progressionContext
    }
}

public enum V2HistoryEvidenceSource: String, Codable, Equatable, Sendable {
    case nativeConfirmed
    case syntheticScenario
}

public struct V2ConfirmedSetEvidence: Codable, Equatable, Sendable {
    public let eventID: String?
    public let repetitions: Int
    public let prescribedRepetitions: Int?
    public let loadKg: Double?
    public let loadOptionID: String?
    public let completedAt: String

    public init(eventID: String?, repetitions: Int, loadKg: Double? = nil, loadOptionID: String? = nil, completedAt: String, prescribedRepetitions: Int? = nil) {
        self.eventID = eventID
        self.repetitions = repetitions
        self.prescribedRepetitions = prescribedRepetitions
        self.loadKg = loadKg
        self.loadOptionID = loadOptionID
        self.completedAt = completedAt
    }
}

/// Recorded facts only. This is not a capacity, tolerance or fatigue estimate.
public struct V2ConfirmedWorkEvidence: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let progressionContext: String
    /// Final prescription retained by the snapshot, after any removal of unstarted work.
    public let plannedSets: Int
    public let targetUnit: V2TargetUnit
    public let confirmedSets: [V2ConfirmedSetEvidence]
    public let wasSkipped: Bool
    public let interruptedBySafetySignal: Bool
    public let source: V2HistoryEvidenceSource

    public init(exerciseId: String, progressionContext: String, plannedSets: Int, targetUnit: V2TargetUnit,
                confirmedSets: [V2ConfirmedSetEvidence], wasSkipped: Bool, interruptedBySafetySignal: Bool,
                source: V2HistoryEvidenceSource) {
        self.exerciseId = exerciseId
        self.progressionContext = progressionContext
        self.plannedSets = plannedSets
        self.targetUnit = targetUnit
        self.confirmedSets = confirmedSets
        self.wasSkipped = wasSkipped
        self.interruptedBySafetySignal = interruptedBySafetySignal
        self.source = source
    }
}

public struct V2HistoryEntry: Codable, Equatable, Sendable {
    public let endedAt: String
    public let completedExerciseIds: [String]?
    public let references: [V2Reference]?
    public let restObservations: [V2RestObservation]?
    public let confirmedWorkEvidence: [V2ConfirmedWorkEvidence]?
    public let catalogVersion: String
    public let decisionPolicyVersion: String

    public init(
        endedAt: String,
        completedExerciseIds: [String]? = nil,
        references: [V2Reference]? = nil,
        restObservations: [V2RestObservation]? = nil,
        confirmedWorkEvidence: [V2ConfirmedWorkEvidence]? = nil,
        catalogVersion: String,
        decisionPolicyVersion: String
    ) {
        self.endedAt = endedAt
        self.completedExerciseIds = completedExerciseIds
        self.references = references
        self.restObservations = restObservations
        self.confirmedWorkEvidence = confirmedWorkEvidence
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
    }
}

public struct V2RestObservation: Codable, Equatable, Sendable {
    public let progressionContext: String
    public let plannedSeconds: Int
    public let actualSeconds: Int

    public init(progressionContext: String, plannedSeconds: Int, actualSeconds: Int) {
        self.progressionContext = progressionContext
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
    }
}

public struct V2Refusal: Codable, Equatable, Sendable {
    public let scope: String
    public let temporalScope: String
    public let exerciseId: String
    public let progressionContext: String?

    public init(scope: String, temporalScope: String, exerciseId: String, progressionContext: String? = nil) {
        self.scope = scope
        self.temporalScope = temporalScope
        self.exerciseId = exerciseId
        self.progressionContext = progressionContext
    }
}

public struct V2Load: Codable, Equatable, Sendable {
    public let mode: V2LoadMode
    public let kg: Double?
    public let optionID: String?

    public init(mode: V2LoadMode, kg: Double) {
        self.mode = mode
        self.kg = kg
        optionID = nil
    }

    public init(optionID: String) {
        mode = .bandOption
        kg = nil
        self.optionID = optionID
    }
}

public struct V2ConfirmedWork: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetReps: Int?
    public let load: V2Load?
    public let progressionContext: String

    public init(
        exerciseId: String,
        sets: Int,
        targetReps: Int? = nil,
        load: V2Load? = nil,
        progressionContext: String
    ) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.targetReps = targetReps
        self.load = load
        self.progressionContext = progressionContext
    }
}

public struct V2UnstartedWork: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetReps: Int
    public let restSeconds: Int
    public let load: V2Load?
    public let sourceExerciseId: String?
    public let referenceStatus: String
    public let progressionContext: String

    public init(
        exerciseId: String,
        sets: Int,
        targetReps: Int,
        restSeconds: Int,
        load: V2Load? = nil,
        sourceExerciseId: String? = nil,
        referenceStatus: String,
        progressionContext: String
    ) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.targetReps = targetReps
        self.restSeconds = restSeconds
        self.load = load
        self.sourceExerciseId = sourceExerciseId
        self.referenceStatus = referenceStatus
        self.progressionContext = progressionContext
    }
}

public struct V2ActiveSession: Codable, Equatable, Sendable {
    public let sessionId: String
    public let mode: V2SessionMode
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let confirmed: [V2ConfirmedWork]
    public let unstarted: [V2UnstartedWork]

    public init(
        sessionId: String,
        mode: V2SessionMode,
        catalogVersion: String,
        decisionPolicyVersion: String,
        confirmed: [V2ConfirmedWork],
        unstarted: [V2UnstartedWork]
    ) {
        self.sessionId = sessionId
        self.mode = mode
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.confirmed = confirmed
        self.unstarted = unstarted
    }
}

public enum V2DeclaredScope: String, Codable, Equatable, Sendable {
    case pregnancy
    case postpartum
}

public struct V2SessionDecisionInput: Equatable, Sendable {
    public let request: V2SessionRequest
    public let persistentInventory: [V2InventoryItem]
    public let todayInventory: [V2InventoryItem]
    public let todaySupports: [String]
    public let history: [V2HistoryEntry]
    public let refusals: [V2Refusal]
    public let activeSession: V2ActiveSession?
    public let declaredCurrentHealthSignal: Bool
    public let declaredScope: V2DeclaredScope?

    public init(
        request: V2SessionRequest,
        persistentInventory: [V2InventoryItem] = [],
        todayInventory: [V2InventoryItem] = [],
        todaySupports: [String] = [],
        history: [V2HistoryEntry] = [],
        refusals: [V2Refusal] = [],
        activeSession: V2ActiveSession? = nil,
        declaredCurrentHealthSignal: Bool = false,
        declaredScope: V2DeclaredScope? = nil
    ) {
        self.request = request
        self.persistentInventory = persistentInventory
        self.todayInventory = todayInventory
        self.todaySupports = todaySupports
        self.history = history
        self.refusals = refusals
        self.activeSession = activeSession
        self.declaredCurrentHealthSignal = declaredCurrentHealthSignal
        self.declaredScope = declaredScope
    }
}

public struct V2PlanItem: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let sourceExerciseId: String?
    public let sets: Int
    public let targetReps: Int
    public let restSeconds: Int
    public let load: V2Load?
    public let referenceStatus: String
    public let progressionContext: String
    public let targetUnit: V2TargetUnit?

    public init(
        exerciseId: String,
        sourceExerciseId: String? = nil,
        sets: Int,
        targetReps: Int,
        restSeconds: Int,
        load: V2Load? = nil,
        referenceStatus: String,
        progressionContext: String,
        targetUnit: V2TargetUnit? = nil
    ) {
        self.exerciseId = exerciseId
        self.sourceExerciseId = sourceExerciseId
        self.sets = sets
        self.targetReps = targetReps
        self.restSeconds = restSeconds
        self.load = load
        self.referenceStatus = referenceStatus
        self.progressionContext = progressionContext
        self.targetUnit = targetUnit
    }

    public var resolvedTargetUnit: V2TargetUnit { targetUnit ?? .repetitions }
}

public struct V2Reason: Codable, Equatable, Sendable {
    public let code: String
    public let scope: String
    public let source: String
    public let message: String
    public let decisionPolicyVersion: String

    public init(code: String, scope: String, source: String, message: String, decisionPolicyVersion: String) {
        self.code = code
        self.scope = scope
        self.source = source
        self.message = message
        self.decisionPolicyVersion = decisionPolicyVersion
    }
}

public struct V2SessionDecision: Equatable, Sendable {
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let decision: V2DecisionName
    public let sessionId: String?
    public let mode: V2SessionMode
    public let estimatedSeconds: Int
    public let plan: [V2PlanItem]
    public let confirmed: [V2ConfirmedWork]
    public let coveredAnchors: [String]
    public let omittedAnchors: [String]
    public let reasons: [V2Reason]
    public let automaticProgression: Bool
    public let confirmedImmutable: Bool
    public let createsDebt: Bool
    public let persistentInventoryChanged: Bool
    public let differentiatedClinicalOrientation: Bool

    public init(
        catalogVersion: String,
        decisionPolicyVersion: String,
        decision: V2DecisionName,
        sessionId: String? = nil,
        mode: V2SessionMode,
        estimatedSeconds: Int = 0,
        plan: [V2PlanItem] = [],
        confirmed: [V2ConfirmedWork] = [],
        coveredAnchors: [String] = [],
        omittedAnchors: [String] = [],
        reasons: [V2Reason] = [],
        automaticProgression: Bool = false,
        confirmedImmutable: Bool = false,
        createsDebt: Bool = false,
        persistentInventoryChanged: Bool = false,
        differentiatedClinicalOrientation: Bool = false
    ) {
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.decision = decision
        self.sessionId = sessionId
        self.mode = mode
        self.estimatedSeconds = estimatedSeconds
        self.plan = plan
        self.confirmed = confirmed
        self.coveredAnchors = coveredAnchors
        self.omittedAnchors = omittedAnchors
        self.reasons = reasons
        self.automaticProgression = automaticProgression
        self.confirmedImmutable = confirmedImmutable
        self.createsDebt = createsDebt
        self.persistentInventoryChanged = persistentInventoryChanged
        self.differentiatedClinicalOrientation = differentiatedClinicalOrientation
    }
}

public struct V2Prescription: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetReps: Int
    public let load: V2Load?
    public let progressionContext: String
    public let catalogVersion: String?
    public let decisionPolicyVersion: String?

    public init(
        exerciseId: String,
        sets: Int,
        targetReps: Int,
        load: V2Load? = nil,
        progressionContext: String,
        catalogVersion: String? = nil,
        decisionPolicyVersion: String? = nil
    ) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.targetReps = targetReps
        self.load = load
        self.progressionContext = progressionContext
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
    }
}

public struct V2Exposure: Codable, Equatable, Sendable {
    public let confirmedReps: [Int]
    public let loadKg: Double?
    public let loadOptionID: String?
    public let allPrescribedSetsConfirmed: Bool
    public let progressionContext: String
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let interruptedBySafetySignal: Bool

    public init(
        confirmedReps: [Int],
        loadKg: Double? = nil,
        loadOptionID: String? = nil,
        allPrescribedSetsConfirmed: Bool,
        progressionContext: String,
        catalogVersion: String,
        decisionPolicyVersion: String,
        interruptedBySafetySignal: Bool = false
    ) {
        self.confirmedReps = confirmedReps
        self.loadKg = loadKg
        self.loadOptionID = loadOptionID
        self.allPrescribedSetsConfirmed = allPrescribedSetsConfirmed
        self.progressionContext = progressionContext
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.interruptedBySafetySignal = interruptedBySafetySignal
    }

    private enum CodingKeys: String, CodingKey {
        case confirmedReps
        case loadKg
        case loadOptionID
        case allPrescribedSetsConfirmed
        case progressionContext
        case catalogVersion
        case decisionPolicyVersion
        case interruptedBySafetySignal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmedReps = try container.decode([Int].self, forKey: .confirmedReps)
        loadKg = try container.decodeIfPresent(Double.self, forKey: .loadKg)
        loadOptionID = try container.decodeIfPresent(String.self, forKey: .loadOptionID)
        allPrescribedSetsConfirmed = try container.decode(Bool.self, forKey: .allPrescribedSetsConfirmed)
        progressionContext = try container.decode(String.self, forKey: .progressionContext)
        catalogVersion = try container.decode(String.self, forKey: .catalogVersion)
        decisionPolicyVersion = try container.decode(String.self, forKey: .decisionPolicyVersion)
        interruptedBySafetySignal = try container.decodeIfPresent(Bool.self, forKey: .interruptedBySafetySignal) ?? false
    }
}

public struct V2ProgressionInput: Equatable, Sendable {
    public let todayInventory: [V2InventoryItem]
    public let previousPrescription: V2Prescription
    public let exposures: [V2Exposure]
    public let todaySupports: [String]

    public init(
        todayInventory: [V2InventoryItem],
        previousPrescription: V2Prescription,
        exposures: [V2Exposure],
        todaySupports: [String] = []
    ) {
        self.todayInventory = todayInventory
        self.previousPrescription = previousPrescription
        self.exposures = exposures
        self.todaySupports = todaySupports
    }
}

public struct V2ProgressionDecision: Equatable, Sendable {
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let decision: V2DecisionName
    public let nextPrescription: V2Prescription
    public let changedFields: [String]
    public let atomicChange: String?
    public let reasons: [V2Reason]

    public init(
        catalogVersion: String,
        decisionPolicyVersion: String,
        decision: V2DecisionName,
        nextPrescription: V2Prescription,
        changedFields: [String] = [],
        atomicChange: String? = nil,
        reasons: [V2Reason] = []
    ) {
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.decision = decision
        self.nextPrescription = nextPrescription
        self.changedFields = changedFields
        self.atomicChange = atomicChange
        self.reasons = reasons
    }
}

public enum V2ActiveAction: String, Codable, Equatable, Sendable {
    case finishOnTime = "finish_on_time"
    case declareHealthSignal = "declare_health_signal"
}

public struct V2ActiveTransitionInput: Equatable, Sendable {
    public let action: V2ActiveAction
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let remainingSeconds: Int?
    public let activeExerciseId: String?
    public let confirmed: [V2ConfirmedWork]
    public let unstarted: [V2UnstartedWork]

    public init(
        action: V2ActiveAction,
        catalogVersion: String,
        decisionPolicyVersion: String,
        remainingSeconds: Int? = nil,
        activeExerciseId: String? = nil,
        confirmed: [V2ConfirmedWork] = [],
        unstarted: [V2UnstartedWork] = []
    ) {
        self.action = action
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.remainingSeconds = remainingSeconds
        self.activeExerciseId = activeExerciseId
        self.confirmed = confirmed
        self.unstarted = unstarted
    }
}

public struct V2RemovedWork: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let progressionContext: String

    public init(exerciseId: String, sets: Int, progressionContext: String) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.progressionContext = progressionContext
    }
}

public struct V2ActiveTransitionDecision: Equatable, Sendable {
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let decision: V2DecisionName
    public let confirmedImmutable: Bool
    public let createsDebt: Bool
    public let estimatedSeconds: Int
    public let plan: [V2PlanItem]
    public let removed: [V2RemovedWork]
    public let confirmed: [V2ConfirmedWork]
    public let exposedActions: [String]
    public let loadedAlternative: V2PlanItem?
    public let reasons: [V2Reason]

    public init(
        catalogVersion: String,
        decisionPolicyVersion: String,
        decision: V2DecisionName,
        confirmedImmutable: Bool = true,
        createsDebt: Bool = false,
        estimatedSeconds: Int = 0,
        plan: [V2PlanItem] = [],
        removed: [V2RemovedWork] = [],
        confirmed: [V2ConfirmedWork] = [],
        exposedActions: [String] = [],
        loadedAlternative: V2PlanItem? = nil,
        reasons: [V2Reason] = []
    ) {
        self.catalogVersion = catalogVersion
        self.decisionPolicyVersion = decisionPolicyVersion
        self.decision = decision
        self.confirmedImmutable = confirmedImmutable
        self.createsDebt = createsDebt
        self.estimatedSeconds = estimatedSeconds
        self.plan = plan
        self.removed = removed
        self.confirmed = confirmed
        self.exposedActions = exposedActions
        self.loadedAlternative = loadedAlternative
        self.reasons = reasons
    }
}

public enum V2EngineRequest: Equatable, Sendable {
    case sessionDecision(V2SessionDecisionInput, now: Date)
    case progressionTransition(V2ProgressionInput)
    case activeSessionTransition(V2ActiveTransitionInput)
}

public enum V2EngineResult: Equatable, Sendable {
    case sessionDecision(V2SessionDecision)
    case progressionTransition(V2ProgressionDecision)
    case activeSessionTransition(V2ActiveTransitionDecision)
}
