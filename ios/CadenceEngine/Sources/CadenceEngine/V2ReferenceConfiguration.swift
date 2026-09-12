public extension V2EngineConfiguration {
    static let referencePreview = V2EngineConfiguration(
        catalogVersion: "fixture-v2.0.0",
        decisionPolicyVersion: "2.0.0",
        catalog: [
            "incline_pushup": previewExercise(
                anchor: "push",
                loadMode: .bodyweight,
                supports: ["wall_or_stable_plane"],
                repRange: .init(min: 6, max: 12, entry: 6),
                timing: .init(setup: 30, execution: 40, secondSide: 0, rest: 75, transition: 20),
                difficultyRank: 1,
                selectionRank: 20,
                progressionContext: "incline_pushup|bodyweight|bilateral|wall_or_stable_plane"
            ),
            "bodyweight_squat": previewExercise(
                anchor: "knee",
                loadMode: .bodyweight,
                repRange: .init(min: 8, max: 15, entry: 8),
                timing: .init(setup: 20, execution: 45, secondSide: 0, rest: 75, transition: 20),
                difficultyRank: 1,
                selectionRank: 20,
                progressionContext: "bodyweight_squat|bodyweight|bilateral"
            ),
            "bodyweight_hinge": previewExercise(
                anchor: "hinge",
                publicationStatus: "validation_required_before_product",
                loadMode: .bodyweight,
                repRange: .init(min: 8, max: 15, entry: 8),
                timing: .init(setup: 20, execution: 40, secondSide: 0, rest: 75, transition: 20),
                difficultyRank: 1,
                selectionRank: 20,
                progressionContext: "bodyweight_hinge|bodyweight|bilateral"
            ),
            "one_arm_row": previewExercise(
                anchor: "pull",
                loadMode: .singleTotalKg,
                equipment: [.init(category: "adjustable_dumbbell", configuration: "single", units: 1)],
                supports: ["stable_hand_support"],
                repRange: .init(min: 8, max: 12, entry: 8),
                timing: .init(setup: 60, execution: 35, secondSide: 35, rest: 90, transition: 30),
                difficultyRank: 2,
                selectionRank: 10,
                progressionContext: "one_arm_row|adjustable_dumbbell|single_total_kg|unilateral|stable_hand_support"
            ),
            "floor_press": previewExercise(
                anchor: "push",
                loadMode: .pairEachKg,
                equipment: [.init(category: "adjustable_dumbbell", configuration: "pair", units: 2)],
                supports: ["floor_allowed"],
                repRange: .init(min: 6, max: 12, entry: 6),
                timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 90, transition: 30),
                difficultyRank: 2,
                selectionRank: 10,
                progressionContext: "floor_press|adjustable_dumbbell|pair_each_kg|bilateral|floor"
            ),
            "goblet_squat": previewExercise(
                anchor: "knee",
                loadMode: .centralTotalKg,
                equipment: [.init(category: "adjustable_dumbbell", configuration: "single", units: 1)],
                repRange: .init(min: 8, max: 12, entry: 8),
                timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25),
                difficultyRank: 2,
                selectionRank: 10,
                progressionContext: "goblet_squat|adjustable_dumbbell|central_total_kg|bilateral"
            ),
            "romanian_deadlift": previewExercise(
                anchor: "hinge",
                loadMode: .pairEachKg,
                equipment: [.init(category: "adjustable_dumbbell", configuration: "pair", units: 2)],
                repRange: .init(min: 8, max: 12, entry: 8),
                timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25),
                difficultyRank: 2,
                selectionRank: 10,
                progressionContext: "romanian_deadlift|adjustable_dumbbell|pair_each_kg|bilateral"
            ),
        ],
        substitutions: [
            .init(from: "floor_press", to: "incline_pushup", type: "partial", rank: 1),
            .init(from: "goblet_squat", to: "bodyweight_squat", type: "partial", rank: 1),
            .init(from: "romanian_deadlift", to: "bodyweight_hinge", type: "partial", rank: 1),
        ],
        policy: V2DecisionPolicy(
            durationBudgetsSeconds: ["20": 1_200, "30": 1_800, "45": 2_700],
            historyDepthCompletedSessions: 12,
            returnQuestionAfterDaysWithoutComparableExposure: 30,
            anchorTieOrder: ["pull", "push", "knee", "hinge"],
            rangeCeilingConfirmations: 2
        )
    )
}

private func previewExercise(
    anchor: String,
    publicationStatus: String = "candidate_validation_required",
    loadMode: V2LoadMode,
    equipment: [V2EquipmentRequirement] = [],
    supports: [String] = [],
    repRange: V2RepRange,
    timing: V2Timing,
    difficultyRank: Int,
    selectionRank: Int,
    progressionContext: String
) -> V2ExerciseDefinition {
    V2ExerciseDefinition(
        anchor: anchor,
        productPublicationStatus: publicationStatus,
        loadMode: loadMode,
        equipment: equipment,
        supports: supports,
        repRange: repRange,
        sets: .init(min: 1, max: 4),
        timingSeconds: timing,
        difficultyRank: difficultyRank,
        selectionRank: selectionRank,
        primaryContributions: [anchor],
        progressionContext: progressionContext
    )
}
