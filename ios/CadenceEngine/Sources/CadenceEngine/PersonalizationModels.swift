import Foundation

/// Programming conventions, not a physiological classification.
public enum V2StrengthPractice: String, Codable, Sendable { case discovering, occasional, regular }
public enum V2ChoiceScope: String, Codable, Sendable { case today, usual }

/// User statements only. Confirmed performances remain exclusively in V2HistoryEntry.
public struct V2MovementKnowledge: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let progressionContext: String
    public var familiar: Bool
    public var usualSets: Int?
    public var preferredReps: Int?
    public var preferredRepsLoad: V2Load?
    public var repetitionReviewAt: Date?
    public var repetitionHoldReleasedAt: Date?
    public var declaredReps: Int?
    public var repetitionsAreMaximum: Bool
    public var declaredLoad: V2Load?
    public var unavailable: Bool
    /// A dated inability report prompts re-evaluation; it is not a permanent exclusion.
    public var reportedUnableAt: Date?
    public var preferenceUpdatedAt: Date?
    /// Date of the original familiarity/capacity statement, never refreshed by a volume choice.
    public var at: Date
    public let catalogVersion: String
    public init(exerciseId: String, progressionContext: String, familiar: Bool = false,
                usualSets: Int? = nil, declaredReps: Int? = nil, repetitionsAreMaximum: Bool = false,
                declaredLoad: V2Load? = nil, unavailable: Bool = false, reportedUnableAt: Date? = nil,
                preferenceUpdatedAt: Date? = nil, at: Date, catalogVersion: String) {
        self.exerciseId = exerciseId; self.progressionContext = progressionContext; self.familiar = familiar
        self.usualSets = usualSets; self.declaredReps = declaredReps; self.repetitionsAreMaximum = repetitionsAreMaximum
        self.declaredLoad = declaredLoad; self.unavailable = unavailable; self.at = at; self.catalogVersion = catalogVersion
        self.reportedUnableAt = reportedUnableAt
        self.preferenceUpdatedAt = preferenceUpdatedAt
    }
}

public enum V2DirectChoice: Codable, Equatable, Sendable {
    case variant(String), load(V2Load), sets(Int), cannotPerform, difficultyTooHigh, exclude
    case holdRepetitions(Int), deferRepetitionReview, resumeRepetitionProgression
}

/// Bound to an explicit session. Replaying a today's choice in another session is rejected.
public struct V2SessionChoice: Codable, Equatable, Sendable {
    public let sessionId: String
    public let exerciseId: String
    public let choice: V2DirectChoice
    public let scope: V2ChoiceScope
    public let at: Date
    public init(sessionId: String, exerciseId: String, choice: V2DirectChoice,
                scope: V2ChoiceScope = .today, at: Date) {
        self.sessionId = sessionId; self.exerciseId = exerciseId; self.choice = choice; self.scope = scope; self.at = at
    }
}

public struct V2Personalization: Codable, Equatable, Sendable {
    public let sessionId: String
    public let practice: V2StrengthPractice?
    /// Explicit return choice; never inferred from absence in the app.
    public let returning: Bool
    public let knowledge: [V2MovementKnowledge]
    public let choices: [V2SessionChoice]
    /// The caller must exclude the running set from activeSession.unstarted.
    public let inProgressExerciseId: String?
    public init(sessionId: String, practice: V2StrengthPractice? = nil, returning: Bool = false,
                knowledge: [V2MovementKnowledge] = [], choices: [V2SessionChoice] = [],
                inProgressExerciseId: String? = nil) {
        self.sessionId = sessionId; self.practice = practice; self.returning = returning
        self.knowledge = knowledge; self.choices = choices; self.inProgressExerciseId = inProgressExerciseId
    }
}

public struct V2MovementOption: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let requiresCapacityAnswer: Bool
    public let availableLoads: [V2Load]
}

public struct V2MovementCheck: Codable, Equatable, Sendable {
    public let anchor: String
    public let exerciseId: String
    public let reason: String
    /// Must be resolved before this movement starts, not necessarily before other movements.
    public let requiredBeforeMovement: Bool
    public let alternatives: [V2MovementOption]
}

public struct V2MuscleCoverage: Codable, Equatable, Sendable {
    public let primary: [String]
    public let secondary: [String]
    /// Editorial coverage goals, not equivalent set counts or an efficacy score.
    public let missingPrimary: [String]
}

public struct V2PersonalizedSessionResult: Equatable, Sendable {
    public let decision: V2SessionDecision
    public let knowledge: [V2MovementKnowledge]
    public let checks: [V2MovementCheck]
    public let optionsByExercise: [String: [V2MovementOption]]
    public let coverage: V2MuscleCoverage
    public let policyVersion: String
    /// Frozen block order; pairs alternate, singletons stay grouped.
    public let blocks: [[String]]
}
