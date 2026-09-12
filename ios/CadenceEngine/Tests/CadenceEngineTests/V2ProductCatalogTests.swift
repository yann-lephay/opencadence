import Foundation
import Testing
import CadenceEngine

struct V2ProductCatalogTests {
    private static let expectedMovements: Set<String> = [
        "push_up", "incline_push_up", "dumbbell_floor_press", "single_arm_dumbbell_floor_press",
        "seated_dumbbell_overhead_press", "single_arm_overhead_press", "band_overhead_press",
        "supported_one_arm_row", "seated_band_row", "bent_over_dumbbell_row", "dip_bar_inverted_row",
        "band_lat_pulldown_over_bar", "band_assisted_pull_up", "eccentric_pull_up", "pull_up",
        "chair_sit_to_stand", "squat", "goblet_squat", "double_dumbbell_front_squat",
        "assisted_split_squat", "split_squat", "reverse_lunge", "low_step_up",
        "wall_hip_hinge", "glute_bridge", "dumbbell_romanian_deadlift", "kettlebell_deadlift",
        "band_good_morning", "dumbbell_hip_thrust", "kickstand_romanian_deadlift",
        "dead_bug", "elevated_front_plank", "front_plank", "side_plank", "suitcase_carry",
        "farmer_carry", "suitcase_march", "supported_calf_raise", "supported_single_leg_calf_raise",
        "dumbbell_lateral_raise", "dumbbell_biceps_curl", "easy_rower_intervals",
    ]

    @Test("Le catalogue produit contient exactement les 42 mouvements retenus")
    func productCatalogueHasFortyTwoMovements() {
        let configuration = V2EngineConfiguration.productPreview
        let movements = Set(configuration.catalog.values.map(\.resolvedMovementId))

        #expect(movements == Self.expectedMovements)
        #expect(configuration.catalog.count > movements.count)
        #expect(configuration.catalog.values.allSatisfy { $0.productPublicationStatus == "approved_for_product" })
    }

    @Test("Chaque configuration produit porte une dose, un temps et un contexte distincts")
    func productConfigurationsAreComplete() {
        let catalog = V2EngineConfiguration.productPreview.catalog
        let contexts = catalog.values.map(\.progressionContext)

        #expect(Set(contexts).count == catalog.count)
        #expect(catalog.values.allSatisfy { exercise in
            exercise.repRange.min > 0
                && exercise.repRange.entry >= exercise.repRange.min
                && exercise.repRange.entry <= exercise.repRange.max
                && exercise.sets.min > 0
                && exercise.sets.max >= exercise.sets.min
                && exercise.timingSeconds.execution > 0
                && exercise.timingSeconds.transition >= 0
                && !exercise.primaryContributions.isEmpty
        })
    }

    @Test("Les formats 20, 30 et 45 minutes gardent les ancrages puis ajoutent peu de compléments")
    func durationBudgetsExposeComplexityProgressively() throws {
        let configuration = V2EngineConfiguration.productPreview
        let inventory = Self.fullInventory
        let supports = Array(Set(configuration.catalog.values.flatMap(\.supports)))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-02T08:00:00Z"))

        func decision(_ duration: Int) throws -> V2SessionDecision {
            let result = CadenceEngine.decideV2(
                request: .sessionDecision(
                    V2SessionDecisionInput(
                        request: V2SessionRequest(durationMinutes: duration),
                        persistentInventory: inventory,
                        todayInventory: inventory,
                        todaySupports: supports
                    ),
                    now: now
                ),
                configuration: configuration
            )
            guard case let .sessionDecision(decision) = result else {
                throw ProductCatalogTestError.missingSessionDecision
            }
            return decision
        }

        let short = try decision(20)
        let medium = try decision(30)
        let long = try decision(45)

        #expect(Set(short.coveredAnchors).isSuperset(of: ["pull", "push", "knee", "hinge"]))
        #expect(short.plan.allSatisfy { configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .anchor })
        #expect(medium.plan.filter { configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .optional }.count == 1)
        #expect(long.plan.filter { configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .optional }.count == 2)
        #expect(long.plan.contains { configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .conditioning })
        #expect(short.estimatedSeconds <= 1_200)
        #expect(medium.estimatedSeconds <= 1_800)
        #expect(long.estimatedSeconds <= 2_700)
    }

    @Test("Le catalogue Release refuse tout mouvement encore non approuvé")
    func releaseCatalogueEnforcesApprovalGate() throws {
        let source = V2EngineConfiguration.referencePreview
        let configuration = V2EngineConfiguration(catalogVersion: source.catalogVersion, decisionPolicyVersion: source.decisionPolicyVersion, catalog: source.catalog, substitutions: source.substitutions, policy: source.policy, requiresProductApproval: true)
        let result = CadenceEngine.decideV2(
            request: .sessionDecision(
                V2SessionDecisionInput(
                    request: V2SessionRequest(durationMinutes: 20),
                    persistentInventory: Self.fullInventory,
                    todayInventory: Self.fullInventory,
                    todaySupports: Array(Set(configuration.catalog.values.flatMap(\.supports)))
                ),
                now: try #require(ISO8601DateFormatter().date(from: "2026-09-02T08:00:00Z"))
            ),
            configuration: configuration
        )
        guard case let .sessionDecision(decision) = result else {
            Issue.record("Une décision de séance était attendue")
            return
        }
        #expect(decision.decision == .noCleanSession)
        #expect(decision.plan.isEmpty)
    }

    @Test("Une bande est une option comparable et ne devient jamais un faux poids")
    func bandProgressionUsesDeclaredOption() {
        let configuration = V2EngineConfiguration.productPreview
        let exercise = configuration.catalog["seated_band_row"]!
        let previous = V2Prescription(
            exerciseId: "seated_band_row",
            sets: 1,
            targetReps: exercise.repRange.max,
            load: V2Load(optionID: "bande-claire"),
            progressionContext: exercise.progressionContext,
            catalogVersion: configuration.catalogVersion,
            decisionPolicyVersion: configuration.decisionPolicyVersion
        )
        let exposures = (0..<2).map { _ in
            V2Exposure(
                confirmedReps: [exercise.repRange.max],
                loadOptionID: "bande-claire",
                allPrescribedSetsConfirmed: true,
                progressionContext: exercise.progressionContext,
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion
            )
        }
        let result = CadenceEngine.decideV2(
            request: .progressionTransition(
                V2ProgressionInput(
                    todayInventory: [
                        .init(
                            category: "resistance_band",
                            units: 1,
                            optionIDs: ["bande-claire", "bande-foncee"],
                            optionProgressionIsDeclared: true
                        )
                    ],
                    previousPrescription: previous,
                    exposures: exposures,
                    todaySupports: exercise.supports
                )
            ),
            configuration: configuration
        )
        guard case let .progressionTransition(decision) = result else {
            Issue.record("Une décision de progression était attendue")
            return
        }
        #expect(decision.nextPrescription.load?.kg == nil)
        #expect(decision.nextPrescription.load?.optionID == "bande-foncee")
    }

    @Test("Trois repos systématiquement plus longs ajustent le budget sans modifier la charge")
    func repeatedLongerRestAdjustsPlanningOnly() throws {
        let configuration = V2EngineConfiguration.productPreview
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-02T08:00:00Z"))
        let baseline = try Self.session(duration: 30, history: [], now: now)
        let item = try #require(baseline.plan.first)
        let dates = ["2026-08-29T08:00:00Z", "2026-08-30T08:00:00Z", "2026-08-31T08:00:00Z"]
        let history = dates.map { date in
            V2HistoryEntry(
                endedAt: date,
                completedExerciseIds: [item.exerciseId],
                restObservations: [
                    V2RestObservation(
                        progressionContext: item.progressionContext,
                        plannedSeconds: item.restSeconds,
                        actualSeconds: 150
                    )
                ],
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion
            )
        }
        let adjusted = try Self.session(duration: 30, history: history, now: now)
        let adjustedItem = try #require(adjusted.plan.first { $0.progressionContext == item.progressionContext })
        #expect(adjustedItem.restSeconds == 150)
        #expect(adjustedItem.load == item.load)
    }

    @Test("Un complément récemment fait laisse la place à un autre complément disponible")
    func optionalMovementRotatesWithoutChangingAnchors() throws {
        let configuration = V2EngineConfiguration.productPreview
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-02T08:00:00Z"))
        let first = try Self.session(duration: 30, history: [], now: now)
        let firstOptional = try #require(first.plan.first {
            configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .optional
        })
        let history = [
            V2HistoryEntry(
                endedAt: "2026-09-01T08:00:00Z",
                completedExerciseIds: first.plan.map { $0.exerciseId },
                catalogVersion: configuration.catalogVersion,
                decisionPolicyVersion: configuration.decisionPolicyVersion
            )
        ]
        let next = try Self.session(duration: 30, history: history, now: now)
        let nextOptional = try #require(next.plan.first {
            configuration.catalog[$0.exerciseId]?.resolvedSelectionRole == .optional
        })
        #expect(
            configuration.catalog[firstOptional.exerciseId]?.resolvedMovementId
                != configuration.catalog[nextOptional.exerciseId]?.resolvedMovementId
        )
        #expect(Set(next.coveredAnchors).isSuperset(of: ["pull", "push", "knee", "hinge"]))
    }

    private static func session(
        duration: Int,
        history: [V2HistoryEntry],
        now: Date
    ) throws -> V2SessionDecision {
        let configuration = V2EngineConfiguration.productPreview
        let result = CadenceEngine.decideV2(
            request: .sessionDecision(
                V2SessionDecisionInput(
                    request: V2SessionRequest(durationMinutes: duration),
                    persistentInventory: fullInventory,
                    todayInventory: fullInventory,
                    todaySupports: Array(Set(configuration.catalog.values.flatMap(\.supports))),
                    history: history
                ),
                now: now
            ),
            configuration: configuration
        )
        guard case let .sessionDecision(decision) = result else {
            throw ProductCatalogTestError.missingSessionDecision
        }
        return decision
    }

    private static let fullInventory: [V2InventoryItem] = [
        .init(category: "bodyweight", units: 1),
        .init(category: "fixed_dumbbell", units: 2, perUnitWeightsKg: [8]),
        .init(category: "adjustable_dumbbell", units: 2, perUnitWeightsKg: [4, 6, 8, 10]),
        .init(category: "kettlebell", units: 1, perUnitWeightsKg: [8, 12, 16]),
        .init(category: "resistance_band", units: 1, optionIDs: ["bande-claire", "bande-foncee"]),
        .init(category: "pullup_bar", units: 1),
        .init(category: "dip_bars", units: 1),
        .init(category: "weighted_vest", units: 1, perUnitWeightsKg: [5, 10]),
        .init(category: "rower", units: 1),
    ]
}

private enum ProductCatalogTestError: Error {
    case missingSessionDecision
}
