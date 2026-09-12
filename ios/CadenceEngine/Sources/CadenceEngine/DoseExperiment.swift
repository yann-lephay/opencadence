import Foundation

// Local experiment only. No application persistence or default dispatcher consumes these types.
@_spi(AutomaticPolicyExperiment) public enum V2DoseAction: String, Codable, Sendable {
    case discover, preferOrdinary, preferHistorical, volumeTooHigh, difficultyTooHigh, difficultyTooLow
    case trainedElsewhere, noTrainingElsewhere
}
@_spi(AutomaticPolicyExperiment) public enum V2DoseSource: String, Codable, Sendable {
    case userDeclared, syntheticScenario
}
@_spi(AutomaticPolicyExperiment) public struct V2DoseFeedback: Codable, Equatable, Sendable {
    public let progressionContext: String
    public let action: V2DoseAction
    public let historicalSets: Int?
    public let at: Date
    public let source: V2DoseSource
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public init(progressionContext: String, action: V2DoseAction, at: Date, source: V2DoseSource,
                catalogVersion: String, decisionPolicyVersion: String, historicalSets: Int? = nil) {
        self.progressionContext = progressionContext; self.action = action; self.historicalSets = historicalSets; self.at = at; self.source = source
        self.catalogVersion = catalogVersion; self.decisionPolicyVersion = decisionPolicyVersion
    }
}
@_spi(AutomaticPolicyExperiment) public struct V2DoseMemory: Codable, Equatable, Sendable {
    public let ordinarySets: Int
    public let lastPlan: V2PlanItem
    public let at: Date
    public let preferenceSource: V2DoseSource?
    public let catalogVersion: String
    public let decisionPolicyVersion: String
    public let experimentVersion: String
    public init(ordinarySets: Int, lastPlan: V2PlanItem, at: Date, preferenceSource: V2DoseSource?,
                catalogVersion: String, decisionPolicyVersion: String, experimentVersion: String = "dose-choice-v1") {
        self.ordinarySets = ordinarySets; self.lastPlan = lastPlan; self.at = at; self.preferenceSource = preferenceSource
        self.catalogVersion = catalogVersion; self.decisionPolicyVersion = decisionPolicyVersion
        self.experimentVersion = experimentVersion
    }
}
@_spi(AutomaticPolicyExperiment) public struct V2DoseExperimentResult: Sendable {
    public let decision: V2SessionDecision
    public let memory: [V2DoseMemory]
}
