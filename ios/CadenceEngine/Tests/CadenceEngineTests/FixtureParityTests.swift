import Foundation
import Testing
import CadenceEngine

struct FixtureParityTests {
    @Test("L'API publique construit une entree sans passer par JSON")
    func publicConstructionAPI() throws {
        let bodyweight = EquipmentItem(
            category: "bodyweight",
            units: 1,
            supportedConfigurations: ["bodyweight"]
        )
        let input = EngineInput(durationMinutes: 20, inventory: [bodyweight])
        let requirement = EquipmentRequirement(category: "bodyweight", configuration: "bodyweight")
        let catalog = EngineCatalog(
            exercises: [
                "incline_pushup": ExerciseDefinition(
                    pattern: "push",
                    variant: "incline_pushup",
                    target: "6-12 reps",
                    restSeconds: 90,
                    equipment: [requirement]
                ),
                "bodyweight_squat": ExerciseDefinition(
                    pattern: "knee",
                    variant: "bodyweight_squat",
                    target: "8-15 reps",
                    restSeconds: 90,
                    equipment: [requirement]
                ),
                "bodyweight_hinge": ExerciseDefinition(
                    pattern: "hinge",
                    variant: "bodyweight_hinge",
                    target: "8-15 reps",
                    restSeconds: 90,
                    equipment: [requirement]
                ),
            ],
            planProfiles: [
                "bodyweight-8": [
                    PlanRow(exerciseKey: "incline_pushup", sets: 3),
                    PlanRow(exerciseKey: "bodyweight_squat", sets: 3),
                    PlanRow(exerciseKey: "bodyweight_hinge", sets: 2),
                ],
            ]
        )
        let now = try #require(Self.date("2026-09-01T08:00:00.000Z"))
        let decision = CadenceEngine.generateNextWorkout(input: input, now: now, catalog: catalog)
        #expect(decision.planProfileId == "bodyweight-8")
    }

    @Test("Les combinaisons croisees restent generiques et explicites")
    func crossCombinationInvariants() throws {
        let manifest = try loadManifest()
        let catalog = EngineCatalog(
            exercises: manifest.exerciseCatalog.merging(manifest.calibratedExerciseCatalog) { _, calibrated in calibrated },
            planProfiles: manifest.planProfiles
        )
        let now = try #require(Self.date("2026-09-10T18:00:00.000Z"))
        let bodyweight = EquipmentItem(
            category: "bodyweight",
            units: 1,
            supportedConfigurations: ["bodyweight"]
        )

        let invalidDuration = CadenceEngine.generateNextWorkout(
            input: EngineInput(durationMinutes: 25, inventory: [bodyweight]),
            now: now,
            catalog: catalog
        )
        #expect(invalidDuration.decision == "request_valid_input")
        #expect(invalidDuration.errorCode == "duration.unsupported")

        let fixed = EquipmentItem(
            category: "fixed_dumbbell",
            units: 2,
            weightKg: 8,
            supportedConfigurations: ["pair", "central", "unilateral"]
        )
        let pullupBar = EquipmentItem(
            category: "pullup_bar",
            units: 1,
            supportedConfigurations: ["bodyweight"]
        )
        let shortFixed = CadenceEngine.generateNextWorkout(
            input: EngineInput(durationMinutes: 20, inventory: [bodyweight, fixed, pullupBar]),
            now: now,
            catalog: catalog
        )
        #expect(shortFixed.decision == "generate_workout")
        #expect(shortFixed.plan?.reduce(0, { $0 + $1.sets }) == 8)
        #expect(shortFixed.plan?.count == 4)
        #expect(shortFixed.plan?.allSatisfy { $0.sets == 2 } == true)
        #expect(shortFixed.recommendedLoads?.count == 1)
        #expect(shortFixed.recommendedLoads?.first?.category == "fixed_dumbbell")
        #expect(shortFixed.recommendedLoads?.first?.configuration == "pair")
        #expect(shortFixed.recommendedLoads?.first?.perUnitWeightKg == 8)

        let adjustable = EquipmentItem(
            category: "adjustable_dumbbell",
            units: 2,
            perUnitWeightsKg: [6, 8, 10],
            supportedConfigurations: ["pair", "central", "unilateral"]
        )
        let painHistory = HistorySession(
            sessionId: "cross-pain",
            endedAt: "2026-09-07T18:00:00.000Z",
            effort: 7,
            painScore: 5
        )
        let reducedAdjustable = CadenceEngine.generateNextWorkout(
            input: EngineInput(
                durationMinutes: 30,
                symptomTracking: .init(enabled: true, todayScore: 7),
                inventory: [adjustable],
                history: [painHistory]
            ),
            now: now,
            catalog: catalog
        )
        #expect(reducedAdjustable.decision == "generate_workout")
        #expect(reducedAdjustable.finalPrimarySetBudget == 7)
        #expect(reducedAdjustable.plan?.reduce(0, { $0 + $1.sets }) == 7)
        #expect(reducedAdjustable.reasonCodes.contains("readiness.previous_pain_five"))
        #expect(reducedAdjustable.reasonCodes.contains("symptoms.high_declared"))

        let equivalentVariantExcluded = CadenceEngine.generateNextWorkout(
            input: EngineInput(
                durationMinutes: 30,
                inventory: [bodyweight, adjustable],
                limitations: [
                    Limitation(
                        id: "session_exclusion",
                        excludedExerciseKeys: ["romanian_deadlift"]
                    )
                ]
            ),
            now: now,
            catalog: catalog
        )
        #expect(equivalentVariantExcluded.decision == "generate_workout")
        #expect(equivalentVariantExcluded.excludedExerciseKeys == ["romanian_deadlift"])
        #expect(equivalentVariantExcluded.movements?.contains {
            $0.variant == "dumbbell_romanian_deadlift"
        } == false)
        #expect(equivalentVariantExcluded.movements?.contains {
            $0.exerciseKey == "bodyweight_hinge"
        } == true)
        #expect(equivalentVariantExcluded.reasonCodes.contains("limitation.user_excluded_movement"))

        let sessionPushExcluded = CadenceEngine.generateNextWorkout(
            input: EngineInput(
                durationMinutes: 30,
                inventory: [bodyweight, adjustable],
                limitations: [
                    Limitation(
                        id: "session_movement_exclusion",
                        excludedExerciseKeys: ["incline_pushup"]
                    )
                ]
            ),
            now: now,
            catalog: catalog
        )
        #expect(sessionPushExcluded.reasonCodes.contains("limitation.user_excluded_movement"))
        #expect(!sessionPushExcluded.reasonCodes.contains("limitation.push_variant_substituted"))

        let progressionHistory = HistorySession(
            sessionId: "excluded-progression",
            endedAt: "2026-09-07T18:00:00.000Z",
            effort: 7,
            painScore: 0,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseKey: "romanian_deadlift",
                    perUnitWeightKg: 6,
                    topRangeReps: 12,
                    completedReps: 8,
                    lastSetRir: 3
                )
            ]
        )
        let excludedProgression = CadenceEngine.generateNextWorkout(
            input: EngineInput(
                durationMinutes: 30,
                inventory: [bodyweight, adjustable],
                history: [progressionHistory],
                limitations: [
                    Limitation(
                        id: "session_movement_exclusion",
                        excludedExerciseKeys: ["romanian_deadlift"]
                    )
                ]
            ),
            now: now,
            catalog: catalog
        )
        #expect(excludedProgression.progression == nil)
        #expect(!excludedProgression.reasonCodes.contains { $0.hasPrefix("progression.") })

        let rowerOnly = EquipmentItem(
            category: "rower",
            units: 1,
            supportedConfigurations: ["rower"]
        )
        let unsupportedInventory = CadenceEngine.generateNextWorkout(
            input: EngineInput(durationMinutes: 20, inventory: [rowerOnly]),
            now: now,
            catalog: catalog
        )
        #expect(unsupportedInventory.decision == "request_valid_input")
        #expect(unsupportedInventory.errorCode == "catalog.no_compatible_exercise")
    }

    @Test("Les 45 fixtures canoniques passent dans le moteur Swift")
    func allReferenceFixtures() throws {
        let manifest = try loadManifest()
        let fixtureExercises = manifest.exerciseCatalog.merging(manifest.calibratedExerciseCatalog) { _, calibrated in calibrated }
        let catalog = EngineCatalog.referenceV1

        #expect(manifest.cases.count == 45)
        #expect(catalog.exercises == fixtureExercises)
        #expect(catalog.planProfiles == manifest.planProfiles)
        var exercised = Set<String>()

        for fixture in manifest.cases {
            var input = fixture.input
            input.applyDefaults(
                calibrations: manifest.inputDefaults.calibrations,
                limitations: manifest.inputDefaults.limitations
            )
            let now = try #require(Self.date(fixture.now))
            let actual = CadenceEngine.generateNextWorkout(input: input, now: now, catalog: catalog)
            let repeated = CadenceEngine.generateNextWorkout(input: input, now: now, catalog: catalog)
            #expect(actual == repeated, Comment(rawValue: "\(fixture.id): sortie non deterministe"))
            exercised.insert(fixture.id)
            verify(actual: actual, expected: fixture.expected, fixture: fixture, catalog: catalog, input: input)
        }

        #expect(exercised.count == manifest.cases.count)
    }

    private func verify(
        actual: EngineDecision,
        expected: FixtureExpected,
        fixture: FixtureCase,
        catalog: EngineCatalog,
        input: EngineInput
    ) {
        let label = fixture.id
        #expect(actual.decision == expected.decision, Comment(rawValue: label))
        #expect(Set(expected.requiredReasonCodes).isSubset(of: Set(actual.reasonCodes)), Comment(rawValue: label))

        if let readiness = expected.readiness {
            #expect(actual.readiness == readiness, Comment(rawValue: label))
        }
        if let value = expected.basePrimarySetBudget {
            #expect(actual.basePrimarySetBudget == value, Comment(rawValue: label))
        }
        if let value = expected.finalPrimarySetBudget {
            #expect(actual.finalPrimarySetBudget == value, Comment(rawValue: label))
        }
        if let profileId = expected.planProfileId {
            #expect(actual.plan == catalog.planProfiles[profileId], Comment(rawValue: label))
            #expect(actual.movements?.count == actual.plan?.count, Comment(rawValue: label))
            for movement in actual.movements ?? [] {
                let definition = catalog.exercises[movement.exerciseKey]
                #expect(movement.variant == definition?.variant, Comment(rawValue: label))
                #expect(movement.pattern == definition?.pattern, Comment(rawValue: label))
                #expect(movement.target == definition?.target, Comment(rawValue: label))
                #expect(movement.restSeconds == definition?.restSeconds, Comment(rawValue: label))
                #expect(movement.equipment == definition?.equipment, Comment(rawValue: label))
            }
        }
        if let value = expected.allowHardRower {
            #expect(actual.allowHardRower == value, Comment(rawValue: label))
        }
        if let value = expected.progression {
            #expect(actual.progression == value, Comment(rawValue: label))
        }
        if let value = expected.rollingPriorityFirst {
            #expect(actual.rollingPriorityFirst == value, Comment(rawValue: label))
        }
        if let value = expected.excludedExerciseKeys {
            #expect(actual.excludedExerciseKeys == value, Comment(rawValue: label))
        }

        verifyPlanAssertions(actual: actual, expected: expected, catalog: catalog, input: input, label: label)

        if let value = expected.blockReason { #expect(actual.blockReason == value, Comment(rawValue: label)) }
        if let value = expected.errorCode { #expect(actual.errorCode == value, Comment(rawValue: label)) }
        if let value = expected.preserveInput { #expect(actual.preserveInput == value, Comment(rawValue: label)) }
        if let value = expected.recovery { #expect(actual.recovery == value, Comment(rawValue: label)) }
        if let value = expected.restoredVersion { #expect(actual.restoredVersion == value, Comment(rawValue: label)) }
        if let value = expected.makeup { #expect(actual.makeup == value, Comment(rawValue: label)) }
        if let value = expected.transition { #expect(actual.transition == value, Comment(rawValue: label)) }
        if let value = expected.completedSetCount { #expect(actual.completedSetCount == value, Comment(rawValue: label)) }
        if let value = expected.offeredActions { #expect(actual.offeredActions == value, Comment(rawValue: label)) }
        if let value = expected.mustNotDiagnose { #expect(actual.mustNotDiagnose == value, Comment(rawValue: label)) }
        if expected.expectsPausedRemainingSeconds {
            #expect(actual.pausedRemainingSeconds == expected.pausedRemainingSeconds, Comment(rawValue: label))
        }
        if expected.expectsRestDeadline {
            #expect(actual.restDeadline == expected.restDeadline, Comment(rawValue: label))
        }
        if let value = expected.inMemoryStatePreserved { #expect(actual.inMemoryStatePreserved == value, Comment(rawValue: label)) }
        if let value = expected.canRetry { #expect(actual.canRetry == value, Comment(rawValue: label)) }
        if let value = expected.canExportRecovery { #expect(actual.canExportRecovery == value, Comment(rawValue: label)) }
        if let timer = expected.restTimer {
            #expect(actual.restTimer?.deadline == timer.deadline, Comment(rawValue: label))
            #expect(actual.restTimer?.remainingSeconds == timer.remainingSeconds, Comment(rawValue: label))
            #expect(actual.restTimer?.remainingSeconds != timer.mustNotResetToSeconds, Comment(rawValue: label))
        }
    }

    private func verifyPlanAssertions(
        actual: EngineDecision,
        expected: FixtureExpected,
        catalog: EngineCatalog,
        input: EngineInput,
        label: String
    ) {
        guard let plan = actual.plan else { return }
        let exerciseKeys = plan.map(\.exerciseKey)
        let patterns = Set(exerciseKeys.compactMap { catalog.exercises[$0]?.pattern })

        for key in expected.forbiddenExerciseKeys ?? [] {
            #expect(!exerciseKeys.contains(key), Comment(rawValue: label))
        }
        for key in expected.stableExerciseKeys ?? [] {
            #expect(exerciseKeys.contains(key), Comment(rawValue: label))
        }
        for pattern in expected.requiredPatterns ?? [] {
            #expect(patterns.contains(pattern), Comment(rawValue: label))
        }
        for pattern in expected.omittedPatterns ?? [] {
            #expect(!patterns.contains(pattern), Comment(rawValue: label))
        }

        var used = Set<String>()
        for key in exerciseKeys {
            for requirement in catalog.exercises[key]?.equipment ?? [] { used.insert(requirement.category) }
        }
        if actual.allowHardRower == true { used.insert("rower") }
        if let expectedUsed = expected.usedEquipmentCategories {
            #expect(used == Set(expectedUsed), Comment(rawValue: label))
        }
        for category in expected.forbiddenEquipmentCategories ?? [] {
            #expect(!used.contains(category), Comment(rawValue: label))
        }

        for recommendation in expected.recommendedLoads ?? [] {
            #expect(actual.recommendedLoads?.contains(recommendation) == true, Comment(rawValue: label))
            let supported = input.inventory.contains { item in
                guard item.category == recommendation.category,
                      item.supports(recommendation.configuration) else { return false }
                if item.category == "fixed_dumbbell" { return item.weightKg == recommendation.perUnitWeightKg }
                if item.category == "adjustable_dumbbell" {
                    return item.perUnitWeightsKg?.contains(recommendation.perUnitWeightKg ?? -1) == true
                }
                return recommendation.perUnitWeightKg == nil
            }
            #expect(supported, Comment(rawValue: label))
        }

        for (key, band) in expected.calibrationAssertions ?? [:] {
            #expect(exerciseKeys.contains(key), Comment(rawValue: label))
            #expect(catalog.exercises[key]?.calibrationBand == band, Comment(rawValue: label))
        }
    }

    private func loadManifest() throws -> FixtureManifest {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appending(path: "fixtures/ios-engine-v1/cases.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try JSONDecoder().decode(FixtureManifest.self, from: Data(contentsOf: candidate))
            }
            directory.deleteLastPathComponent()
        }
        throw FixtureError.manifestNotFound
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private enum FixtureError: Error { case manifestNotFound }

private struct FixtureManifest: Decodable {
    let inputDefaults: FixtureDefaults
    let exerciseCatalog: [String: ExerciseDefinition]
    let calibratedExerciseCatalog: [String: ExerciseDefinition]
    let planProfiles: [String: [PlanRow]]
    let cases: [FixtureCase]
}

private struct FixtureDefaults: Decodable {
    let calibrations: Calibrations
    let limitations: [Limitation]
}

private struct FixtureCase: Decodable {
    let id: String
    let now: String
    let input: EngineInput
    let expected: FixtureExpected
}

private struct FixtureRestTimer: Decodable {
    let deadline: String
    let remainingSeconds: Int
    let mustNotResetToSeconds: Int
}

private struct FixtureExpected: Decodable {
    let decision: String
    let requiredReasonCodes: [String]
    let readiness: Readiness?
    let basePrimarySetBudget: Int?
    let finalPrimarySetBudget: Int?
    let planProfileId: String?
    let allowHardRower: Bool?
    let progression: Progression?
    let rollingPriorityFirst: String?
    let excludedExerciseKeys: [String]?
    let blockReason: String?
    let errorCode: String?
    let preserveInput: Bool?
    let recovery: String?
    let restoredVersion: Int?
    let makeup: MakeupDecision?
    let restTimer: FixtureRestTimer?
    let transition: String?
    let completedSetCount: Int?
    let offeredActions: [String]?
    let mustNotDiagnose: Bool?
    let pausedRemainingSeconds: Int?
    let restDeadline: String?
    let inMemoryStatePreserved: Bool?
    let canRetry: Bool?
    let canExportRecovery: Bool?
    let requiredPatterns: [String]?
    let omittedPatterns: [String]?
    let forbiddenExerciseKeys: [String]?
    let stableExerciseKeys: [String]?
    let usedEquipmentCategories: [String]?
    let forbiddenEquipmentCategories: [String]?
    let recommendedLoads: [LoadRecommendation]?
    let calibrationAssertions: [String: String]?
    let rawKeys: Set<String>

    var expectsPausedRemainingSeconds: Bool { rawKeys.contains("pausedRemainingSeconds") }
    var expectsRestDeadline: Bool { rawKeys.contains("restDeadline") }

    private enum CodingKeys: String, CodingKey {
        case decision, requiredReasonCodes, readiness, basePrimarySetBudget, finalPrimarySetBudget
        case planProfileId, allowHardRower, progression, rollingPriorityFirst, excludedExerciseKeys, blockReason
        case errorCode, preserveInput, recovery, restoredVersion, makeup, restTimer, transition
        case completedSetCount, offeredActions, mustNotDiagnose, pausedRemainingSeconds, restDeadline
        case inMemoryStatePreserved, canRetry, canExportRecovery, requiredPatterns, omittedPatterns
        case forbiddenExerciseKeys, stableExerciseKeys, usedEquipmentCategories
        case forbiddenEquipmentCategories, recommendedLoads, calibrationAssertions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        decision = try container.decode(String.self, forKey: .decision)
        requiredReasonCodes = try container.decode([String].self, forKey: .requiredReasonCodes)
        readiness = try container.decodeIfPresent(Readiness.self, forKey: .readiness)
        basePrimarySetBudget = try container.decodeIfPresent(Int.self, forKey: .basePrimarySetBudget)
        finalPrimarySetBudget = try container.decodeIfPresent(Int.self, forKey: .finalPrimarySetBudget)
        planProfileId = try container.decodeIfPresent(String.self, forKey: .planProfileId)
        allowHardRower = try container.decodeIfPresent(Bool.self, forKey: .allowHardRower)
        progression = try container.decodeIfPresent(Progression.self, forKey: .progression)
        rollingPriorityFirst = try container.decodeIfPresent(String.self, forKey: .rollingPriorityFirst)
        excludedExerciseKeys = try container.decodeIfPresent([String].self, forKey: .excludedExerciseKeys)
        blockReason = try container.decodeIfPresent(String.self, forKey: .blockReason)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        preserveInput = try container.decodeIfPresent(Bool.self, forKey: .preserveInput)
        recovery = try container.decodeIfPresent(String.self, forKey: .recovery)
        restoredVersion = try container.decodeIfPresent(Int.self, forKey: .restoredVersion)
        makeup = try container.decodeIfPresent(MakeupDecision.self, forKey: .makeup)
        restTimer = try container.decodeIfPresent(FixtureRestTimer.self, forKey: .restTimer)
        transition = try container.decodeIfPresent(String.self, forKey: .transition)
        completedSetCount = try container.decodeIfPresent(Int.self, forKey: .completedSetCount)
        offeredActions = try container.decodeIfPresent([String].self, forKey: .offeredActions)
        mustNotDiagnose = try container.decodeIfPresent(Bool.self, forKey: .mustNotDiagnose)
        pausedRemainingSeconds = try container.decodeIfPresent(Int.self, forKey: .pausedRemainingSeconds)
        restDeadline = try container.decodeIfPresent(String.self, forKey: .restDeadline)
        inMemoryStatePreserved = try container.decodeIfPresent(Bool.self, forKey: .inMemoryStatePreserved)
        canRetry = try container.decodeIfPresent(Bool.self, forKey: .canRetry)
        canExportRecovery = try container.decodeIfPresent(Bool.self, forKey: .canExportRecovery)
        requiredPatterns = try container.decodeIfPresent([String].self, forKey: .requiredPatterns)
        omittedPatterns = try container.decodeIfPresent([String].self, forKey: .omittedPatterns)
        forbiddenExerciseKeys = try container.decodeIfPresent([String].self, forKey: .forbiddenExerciseKeys)
        stableExerciseKeys = try container.decodeIfPresent([String].self, forKey: .stableExerciseKeys)
        usedEquipmentCategories = try container.decodeIfPresent([String].self, forKey: .usedEquipmentCategories)
        forbiddenEquipmentCategories = try container.decodeIfPresent([String].self, forKey: .forbiddenEquipmentCategories)
        recommendedLoads = try container.decodeIfPresent([LoadRecommendation].self, forKey: .recommendedLoads)
        calibrationAssertions = try container.decodeIfPresent([String: String].self, forKey: .calibrationAssertions)
        rawKeys = Set(container.allKeys.map(\.stringValue))
    }
}
