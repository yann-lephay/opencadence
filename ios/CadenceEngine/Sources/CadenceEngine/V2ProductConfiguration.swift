import Foundation

public extension V2EngineConfiguration {
    /// Product use approved by Yann on 2026-09-08; no clinical endorsement implied.
    /// Future movements remain unapproved until explicitly reviewed.
    static let approvedMovementIDs: Set<String> = [
        "assisted_split_squat",
        "band_assisted_pull_up",
        "band_good_morning",
        "band_lat_pulldown_over_bar",
        "band_overhead_press",
        "bent_over_dumbbell_row",
        "chair_sit_to_stand",
        "dead_bug",
        "dip_bar_inverted_row",
        "double_dumbbell_front_squat",
        "dumbbell_biceps_curl",
        "dumbbell_floor_press",
        "dumbbell_hip_thrust",
        "dumbbell_lateral_raise",
        "dumbbell_romanian_deadlift",
        "easy_rower_intervals",
        "eccentric_pull_up",
        "elevated_front_plank",
        "farmer_carry",
        "front_plank",
        "glute_bridge",
        "goblet_squat",
        "incline_push_up",
        "kettlebell_deadlift",
        "kickstand_romanian_deadlift",
        "low_step_up",
        "pull_up",
        "push_up",
        "reverse_lunge",
        "seated_band_row",
        "seated_dumbbell_overhead_press",
        "side_plank",
        "single_arm_dumbbell_floor_press",
        "single_arm_overhead_press",
        "split_squat",
        "squat",
        "suitcase_carry",
        "suitcase_march",
        "supported_calf_raise",
        "supported_one_arm_row",
        "supported_single_leg_calf_raise",
        "wall_hip_hinge",
    ]

    /// Full product catalogue used by the iOS integration while the movement
    /// cards and demonstrations are being validated. Release builds must use
    /// `releaseV2` so an unapproved movement can never leak into production.
    static let productPreview: V2EngineConfiguration = makeProductConfiguration(
        requiresProductApproval: false
    )

    static let releaseV2: V2EngineConfiguration = makeProductConfiguration(
        requiresProductApproval: true
    )
}

private extension V2EngineConfiguration {
    /// Editorial contributions: no fractional set equivalence or efficacy claim.
    static func primaryMuscles(_ movement: String) -> [String] {
        switch movement {
        case "push_up", "incline_push_up", "dumbbell_floor_press", "single_arm_dumbbell_floor_press":
            return ["chest"]
        case "seated_dumbbell_overhead_press", "single_arm_overhead_press", "band_overhead_press":
            return ["shoulders"]
        case "supported_one_arm_row", "seated_band_row", "bent_over_dumbbell_row", "dip_bar_inverted_row",
             "band_lat_pulldown_over_bar", "band_assisted_pull_up", "eccentric_pull_up", "pull_up":
            return ["back"]
        case "chair_sit_to_stand", "squat", "goblet_squat", "double_dumbbell_front_squat",
             "assisted_split_squat", "split_squat", "reverse_lunge", "low_step_up":
            return ["quadriceps", "glutes"]
        case "glute_bridge", "dumbbell_hip_thrust": return ["glutes"]
        case "dumbbell_romanian_deadlift", "kettlebell_deadlift", "band_good_morning", "kickstand_romanian_deadlift":
            return ["hamstrings", "glutes"]
        // A learning drill does not by itself establish muscle-work coverage.
        case "wall_hip_hinge": return ["motor_learning"]
        default: return ["unspecified"]
        }
    }

    static func makeProductConfiguration(requiresProductApproval: Bool) -> V2EngineConfiguration {
        var catalog: [String: V2ExerciseDefinition] = [:]

        func add(
            _ key: String,
            movement: String? = nil,
            anchor: String,
            role: V2SelectionRole = .anchor,
            loadMode: V2LoadMode = .bodyweight,
            equipment: [V2EquipmentRequirement] = [],
            supports: [String] = [],
            reps: ClosedRange<Int>,
            entry: Int? = nil,
            unit: V2TargetUnit = .repetitions,
            sets: ClosedRange<Int> = 1...3,
            timing: V2Timing,
            difficulty: Int,
            selection: Int,
            primary: [String]? = nil,
            secondary: [String] = []
        ) {
            let movementId = movement ?? key.components(separatedBy: "__").first ?? key
            catalog[key] = V2ExerciseDefinition(
                movementId: movementId,
                anchor: anchor,
                productPublicationStatus: approvedMovementIDs.contains(movementId) ? "approved_for_product" : "awaiting_movement_validation",
                loadMode: loadMode,
                equipment: equipment,
                supports: supports,
                repRange: .init(min: reps.lowerBound, max: reps.upperBound, entry: entry ?? reps.lowerBound),
                sets: .init(min: sets.lowerBound, max: sets.upperBound),
                timingSeconds: timing,
                difficultyRank: difficulty,
                selectionRank: selection,
                primaryContributions: primary ?? primaryMuscles(movementId),
                secondaryContributions: secondary,
                progressionContext: key,
                targetUnit: unit,
                selectionRole: role,
                initialCapacityRequired: ["pull_up", "band_assisted_pull_up", "eccentric_pull_up",
                                          "dip_bar_inverted_row", "push_up"].contains(movementId)
            )
        }

        let body = V2EquipmentRequirement(category: "bodyweight", configuration: "bodyweight", units: 1)
        let fixedOne = V2EquipmentRequirement(category: "fixed_dumbbell", configuration: "single", units: 1)
        let fixedPair = V2EquipmentRequirement(category: "fixed_dumbbell", configuration: "pair", units: 2)
        let adjustableOne = V2EquipmentRequirement(category: "adjustable_dumbbell", configuration: "single", units: 1)
        let adjustablePair = V2EquipmentRequirement(category: "adjustable_dumbbell", configuration: "pair", units: 2)
        let kettlebell = V2EquipmentRequirement(category: "kettlebell", configuration: "single", units: 1)
        let band = V2EquipmentRequirement(category: "resistance_band", configuration: "band", units: 1)
        let pullupBar = V2EquipmentRequirement(category: "pullup_bar", configuration: "bodyweight", units: 1)
        let dipBars = V2EquipmentRequirement(category: "dip_bars", configuration: "bodyweight", units: 1)
        let vest = V2EquipmentRequirement(category: "weighted_vest", configuration: "vest", units: 1)
        let rower = V2EquipmentRequirement(category: "rower", configuration: "rower", units: 1)

        // Poussées — 7 mouvements, avec configurations de charge séparées.
        add("push_up", anchor: "push", equipment: [body], supports: ["floor_allowed"], reps: 6...15,
            timing: .init(setup: 20, execution: 40, secondSide: 0, rest: 75, transition: 20), difficulty: 2, selection: 15,
            secondary: ["triceps", "core"])
        add("push_up__weighted_vest", movement: "push_up", anchor: "push", loadMode: .centralTotalKg, equipment: [vest], supports: ["floor_allowed"], reps: 6...12,
            timing: .init(setup: 45, execution: 40, secondSide: 0, rest: 90, transition: 25), difficulty: 3, selection: 45,
            secondary: ["triceps", "core"])
        add("incline_push_up", anchor: "push", equipment: [body], supports: ["stable_incline_support"], reps: 6...15,
            timing: .init(setup: 30, execution: 40, secondSide: 0, rest: 75, transition: 20), difficulty: 1, selection: 25,
            secondary: ["triceps", "core"])
        add("dumbbell_floor_press__fixed", movement: "dumbbell_floor_press", anchor: "push", loadMode: .pairEachKg, equipment: [fixedPair], supports: ["floor_allowed"], reps: 6...12,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 90, transition: 30), difficulty: 2, selection: 10, secondary: ["triceps"])
        add("dumbbell_floor_press__adjustable", movement: "dumbbell_floor_press", anchor: "push", loadMode: .pairEachKg, equipment: [adjustablePair], supports: ["floor_allowed"], reps: 6...12,
            timing: .init(setup: 75, execution: 45, secondSide: 0, rest: 90, transition: 35), difficulty: 2, selection: 11, secondary: ["triceps"])
        add("single_arm_dumbbell_floor_press__fixed", movement: "single_arm_dumbbell_floor_press", anchor: "push", loadMode: .singleTotalKg, equipment: [fixedOne], supports: ["floor_allowed"], reps: 6...12,
            timing: .init(setup: 50, execution: 35, secondSide: 35, rest: 90, transition: 30), difficulty: 2, selection: 30, secondary: ["triceps", "core"])
        add("single_arm_dumbbell_floor_press__adjustable", movement: "single_arm_dumbbell_floor_press", anchor: "push", loadMode: .singleTotalKg, equipment: [adjustableOne], supports: ["floor_allowed"], reps: 6...12,
            timing: .init(setup: 65, execution: 35, secondSide: 35, rest: 90, transition: 35), difficulty: 2, selection: 31, secondary: ["triceps", "core"])
        add("seated_dumbbell_overhead_press__fixed", movement: "seated_dumbbell_overhead_press", anchor: "push", loadMode: .pairEachKg, equipment: [fixedPair], supports: ["seated_support", "overhead_clearance"], reps: 6...12,
            timing: .init(setup: 55, execution: 40, secondSide: 0, rest: 90, transition: 30), difficulty: 2, selection: 35, secondary: ["triceps"])
        add("seated_dumbbell_overhead_press__adjustable", movement: "seated_dumbbell_overhead_press", anchor: "push", loadMode: .pairEachKg, equipment: [adjustablePair], supports: ["seated_support", "overhead_clearance"], reps: 6...12,
            timing: .init(setup: 70, execution: 40, secondSide: 0, rest: 90, transition: 35), difficulty: 2, selection: 36, secondary: ["triceps"])
        add("single_arm_overhead_press__dumbbell", movement: "single_arm_overhead_press", anchor: "push", loadMode: .singleTotalKg, equipment: [adjustableOne], supports: ["overhead_clearance"], reps: 6...12,
            timing: .init(setup: 45, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 3, selection: 55, secondary: ["triceps", "core"])
        add("single_arm_overhead_press__kettlebell", movement: "single_arm_overhead_press", anchor: "push", loadMode: .singleTotalKg, equipment: [kettlebell], supports: ["overhead_clearance"], reps: 6...12,
            timing: .init(setup: 45, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 3, selection: 56, secondary: ["triceps", "core"])
        add("band_overhead_press", anchor: "push", loadMode: .bandOption, equipment: [band], supports: ["overhead_clearance", "band_under_feet_allowed"], reps: 8...15,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 75, transition: 30), difficulty: 2, selection: 40, secondary: ["triceps"])

        // Tirages — 8 mouvements.
        add("supported_one_arm_row__fixed", movement: "supported_one_arm_row", anchor: "pull", loadMode: .singleTotalKg, equipment: [fixedOne], supports: ["stable_hand_support"], reps: 8...12,
            timing: .init(setup: 50, execution: 35, secondSide: 35, rest: 90, transition: 30), difficulty: 2, selection: 10, secondary: ["biceps"])
        add("supported_one_arm_row__adjustable", movement: "supported_one_arm_row", anchor: "pull", loadMode: .singleTotalKg, equipment: [adjustableOne], supports: ["stable_hand_support"], reps: 8...12,
            timing: .init(setup: 65, execution: 35, secondSide: 35, rest: 90, transition: 35), difficulty: 2, selection: 11, secondary: ["biceps"])
        add("supported_one_arm_row__kettlebell", movement: "supported_one_arm_row", anchor: "pull", loadMode: .singleTotalKg, equipment: [kettlebell], supports: ["stable_hand_support"], reps: 8...12,
            timing: .init(setup: 50, execution: 35, secondSide: 35, rest: 90, transition: 30), difficulty: 2, selection: 12, secondary: ["biceps"])
        add("seated_band_row", anchor: "pull", loadMode: .bandOption, equipment: [band], supports: ["floor_allowed", "band_around_feet_allowed"], reps: 10...15,
            timing: .init(setup: 55, execution: 45, secondSide: 0, rest: 75, transition: 25), difficulty: 1, selection: 25, secondary: ["biceps"])
        add("bent_over_dumbbell_row__fixed", movement: "bent_over_dumbbell_row", anchor: "pull", loadMode: .pairEachKg, equipment: [fixedPair], reps: 8...12,
            timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 3, selection: 50, secondary: ["biceps", "hinge"])
        add("bent_over_dumbbell_row__adjustable", movement: "bent_over_dumbbell_row", anchor: "pull", loadMode: .pairEachKg, equipment: [adjustablePair], reps: 8...12,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 90, transition: 30), difficulty: 3, selection: 51, secondary: ["biceps", "hinge"])
        add("dip_bar_inverted_row", anchor: "pull", equipment: [dipBars], supports: ["dip_bars_row_safe", "floor_grip_safe"], reps: 6...12,
            timing: .init(setup: 75, execution: 45, secondSide: 0, rest: 90, transition: 35), difficulty: 3, selection: 60, secondary: ["biceps", "core"])
        add("band_lat_pulldown_over_bar", anchor: "pull", loadMode: .bandOption, equipment: [band, pullupBar], supports: ["floor_allowed", "band_over_bar_allowed"], reps: 8...15,
            timing: .init(setup: 90, execution: 45, secondSide: 0, rest: 75, transition: 40), difficulty: 3, selection: 40, secondary: ["biceps"])
        add("band_assisted_pull_up", anchor: "pull", loadMode: .bandOption, equipment: [band, pullupBar], supports: ["band_on_pullup_bar_allowed", "pullup_clearance"], reps: 4...10,
            timing: .init(setup: 105, execution: 45, secondSide: 0, rest: 105, transition: 45), difficulty: 3, selection: 30, secondary: ["biceps", "core"])
        add("eccentric_pull_up", anchor: "pull", equipment: [pullupBar], supports: ["pullup_clearance", "pullup_top_start_support"], reps: 3...6,
            timing: .init(setup: 80, execution: 45, secondSide: 0, rest: 120, transition: 35), difficulty: 3, selection: 45, secondary: ["biceps", "core"])
        add("pull_up", anchor: "pull", equipment: [pullupBar], supports: ["pullup_clearance"], reps: 3...10,
            timing: .init(setup: 35, execution: 40, secondSide: 0, rest: 120, transition: 25), difficulty: 4, selection: 35, secondary: ["biceps", "core"])

        // Dominante genou — 8 mouvements.
        add("chair_sit_to_stand", anchor: "knee", equipment: [body], supports: ["seated_support"], reps: 8...15,
            timing: .init(setup: 25, execution: 45, secondSide: 0, rest: 75, transition: 20), difficulty: 1, selection: 25)
        add("squat", anchor: "knee", equipment: [body], reps: 8...15,
            timing: .init(setup: 20, execution: 45, secondSide: 0, rest: 75, transition: 20), difficulty: 1, selection: 15)
        add("squat__weighted_vest", movement: "squat", anchor: "knee", loadMode: .centralTotalKg, equipment: [vest], reps: 8...15,
            timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 2, selection: 45)
        add("goblet_squat__fixed", movement: "goblet_squat", anchor: "knee", loadMode: .centralTotalKg, equipment: [fixedOne], reps: 8...12,
            timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 2, selection: 10)
        add("goblet_squat__adjustable", movement: "goblet_squat", anchor: "knee", loadMode: .centralTotalKg, equipment: [adjustableOne], reps: 8...12,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 90, transition: 30), difficulty: 2, selection: 11)
        add("goblet_squat__kettlebell", movement: "goblet_squat", anchor: "knee", loadMode: .centralTotalKg, equipment: [kettlebell], reps: 8...12,
            timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 2, selection: 12)
        add("double_dumbbell_front_squat__fixed", movement: "double_dumbbell_front_squat", anchor: "knee", loadMode: .pairEachKg, equipment: [fixedPair], reps: 6...12,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 105, transition: 30), difficulty: 3, selection: 50)
        add("double_dumbbell_front_squat__adjustable", movement: "double_dumbbell_front_squat", anchor: "knee", loadMode: .pairEachKg, equipment: [adjustablePair], reps: 6...12,
            timing: .init(setup: 75, execution: 45, secondSide: 0, rest: 105, transition: 35), difficulty: 3, selection: 51)
        add("assisted_split_squat", anchor: "knee", equipment: [body], supports: ["stable_hand_support"], reps: 6...12,
            timing: .init(setup: 35, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 2, selection: 30)
        add("split_squat", anchor: "knee", equipment: [body], reps: 6...12,
            timing: .init(setup: 30, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 2, selection: 35)
        add("reverse_lunge", anchor: "knee", equipment: [body], supports: ["travel_space"], reps: 6...12,
            timing: .init(setup: 25, execution: 40, secondSide: 40, rest: 90, transition: 25), difficulty: 3, selection: 55)
        add("low_step_up", anchor: "knee", equipment: [body], supports: ["step_up_approved_support"], reps: 6...12,
            timing: .init(setup: 55, execution: 35, secondSide: 35, rest: 90, transition: 30), difficulty: 3, selection: 60)

        // Charnière et extension de hanche — 7 mouvements.
        add("wall_hip_hinge", anchor: "hinge", equipment: [body], supports: ["wall_or_stable_plane"], reps: 8...15,
            timing: .init(setup: 25, execution: 40, secondSide: 0, rest: 60, transition: 20), difficulty: 1, selection: 25)
        add("glute_bridge", anchor: "hinge", equipment: [body], supports: ["floor_allowed"], reps: 10...15,
            timing: .init(setup: 30, execution: 45, secondSide: 0, rest: 75, transition: 20), difficulty: 1, selection: 20)
        add("dumbbell_romanian_deadlift__fixed", movement: "dumbbell_romanian_deadlift", anchor: "hinge", loadMode: .pairEachKg, equipment: [fixedPair], reps: 8...12,
            timing: .init(setup: 45, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 2, selection: 10)
        add("dumbbell_romanian_deadlift__adjustable", movement: "dumbbell_romanian_deadlift", anchor: "hinge", loadMode: .pairEachKg, equipment: [adjustablePair], reps: 8...12,
            timing: .init(setup: 60, execution: 45, secondSide: 0, rest: 90, transition: 30), difficulty: 2, selection: 11)
        add("kettlebell_deadlift", anchor: "hinge", loadMode: .centralTotalKg, equipment: [kettlebell], reps: 8...12,
            timing: .init(setup: 40, execution: 45, secondSide: 0, rest: 90, transition: 25), difficulty: 2, selection: 12)
        add("band_good_morning", anchor: "hinge", loadMode: .bandOption, equipment: [band], supports: ["band_under_feet_allowed"], reps: 10...15,
            timing: .init(setup: 65, execution: 45, secondSide: 0, rest: 75, transition: 30), difficulty: 3, selection: 45)
        add("dumbbell_hip_thrust__fixed", movement: "dumbbell_hip_thrust", anchor: "hinge", loadMode: .centralTotalKg, equipment: [fixedOne], supports: ["hip_thrust_bench_approved"], reps: 8...15,
            timing: .init(setup: 85, execution: 45, secondSide: 0, rest: 90, transition: 40), difficulty: 3, selection: 55)
        add("dumbbell_hip_thrust__adjustable", movement: "dumbbell_hip_thrust", anchor: "hinge", loadMode: .centralTotalKg, equipment: [adjustableOne], supports: ["hip_thrust_bench_approved"], reps: 8...15,
            timing: .init(setup: 100, execution: 45, secondSide: 0, rest: 90, transition: 45), difficulty: 3, selection: 56)
        add("kickstand_romanian_deadlift__dumbbell", movement: "kickstand_romanian_deadlift", anchor: "hinge", loadMode: .singleTotalKg, equipment: [adjustableOne], reps: 6...12,
            timing: .init(setup: 40, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 3, selection: 60)
        add("kickstand_romanian_deadlift__kettlebell", movement: "kickstand_romanian_deadlift", anchor: "hinge", loadMode: .singleTotalKg, equipment: [kettlebell], reps: 6...12,
            timing: .init(setup: 40, execution: 35, secondSide: 35, rest: 90, transition: 25), difficulty: 3, selection: 61)

        // Tronc, portés, mollets et compléments — 12 mouvements.
        add("dead_bug", anchor: "core", role: .optional, equipment: [body], supports: ["floor_allowed"], reps: 6...10,
            timing: .init(setup: 30, execution: 35, secondSide: 35, rest: 60, transition: 20), difficulty: 1, selection: 10, primary: ["core"])
        add("elevated_front_plank", anchor: "core", role: .optional, equipment: [body], supports: ["stable_incline_support"], reps: 20...45, unit: .seconds,
            timing: .init(setup: 30, execution: 35, secondSide: 0, rest: 60, transition: 20), difficulty: 1, selection: 20, primary: ["core"])
        add("front_plank", anchor: "core", role: .optional, equipment: [body], supports: ["floor_allowed"], reps: 20...60, unit: .seconds,
            timing: .init(setup: 25, execution: 40, secondSide: 0, rest: 60, transition: 20), difficulty: 2, selection: 25, primary: ["core"])
        add("side_plank", anchor: "core", role: .optional, equipment: [body], supports: ["floor_allowed"], reps: 15...45, unit: .seconds,
            timing: .init(setup: 30, execution: 30, secondSide: 30, rest: 60, transition: 20), difficulty: 2, selection: 35, primary: ["core"])
        add("suitcase_carry__dumbbell", movement: "suitcase_carry", anchor: "carry", role: .optional, loadMode: .singleTotalKg, equipment: [adjustableOne], supports: ["travel_space"], reps: 20...60, unit: .seconds,
            timing: .init(setup: 35, execution: 35, secondSide: 35, rest: 75, transition: 25), difficulty: 2, selection: 10, primary: ["carry", "grip"], secondary: ["core"])
        add("suitcase_carry__kettlebell", movement: "suitcase_carry", anchor: "carry", role: .optional, loadMode: .singleTotalKg, equipment: [kettlebell], supports: ["travel_space"], reps: 20...60, unit: .seconds,
            timing: .init(setup: 35, execution: 35, secondSide: 35, rest: 75, transition: 25), difficulty: 2, selection: 11, primary: ["carry", "grip"], secondary: ["core"])
        add("farmer_carry__fixed", movement: "farmer_carry", anchor: "carry", role: .optional, loadMode: .pairEachKg, equipment: [fixedPair], supports: ["travel_space"], reps: 20...60, unit: .seconds,
            timing: .init(setup: 35, execution: 40, secondSide: 0, rest: 75, transition: 25), difficulty: 2, selection: 20, primary: ["carry", "grip"], secondary: ["core"])
        add("farmer_carry__adjustable", movement: "farmer_carry", anchor: "carry", role: .optional, loadMode: .pairEachKg, equipment: [adjustablePair], supports: ["travel_space"], reps: 20...60, unit: .seconds,
            timing: .init(setup: 50, execution: 40, secondSide: 0, rest: 75, transition: 30), difficulty: 2, selection: 21, primary: ["carry", "grip"], secondary: ["core"])
        add("suitcase_march__dumbbell", movement: "suitcase_march", anchor: "carry", role: .optional, loadMode: .singleTotalKg, equipment: [adjustableOne], reps: 20...60, unit: .seconds,
            timing: .init(setup: 35, execution: 35, secondSide: 35, rest: 75, transition: 25), difficulty: 2, selection: 30, primary: ["carry", "grip"], secondary: ["core"])
        add("suitcase_march__kettlebell", movement: "suitcase_march", anchor: "carry", role: .optional, loadMode: .singleTotalKg, equipment: [kettlebell], reps: 20...60, unit: .seconds,
            timing: .init(setup: 35, execution: 35, secondSide: 35, rest: 75, transition: 25), difficulty: 2, selection: 31, primary: ["carry", "grip"], secondary: ["core"])
        add("supported_calf_raise", anchor: "calf", role: .optional, equipment: [body], supports: ["stable_hand_support"], reps: 10...20,
            timing: .init(setup: 20, execution: 40, secondSide: 0, rest: 60, transition: 15), difficulty: 1, selection: 40, primary: ["calves"])
        add("supported_single_leg_calf_raise", anchor: "calf", role: .optional, equipment: [body], supports: ["stable_hand_support"], reps: 8...15,
            timing: .init(setup: 25, execution: 30, secondSide: 30, rest: 60, transition: 20), difficulty: 2, selection: 50, primary: ["calves"])
        add("dumbbell_lateral_raise__fixed", movement: "dumbbell_lateral_raise", anchor: "accessory", role: .optional, loadMode: .pairEachKg, equipment: [fixedPair], reps: 10...15,
            timing: .init(setup: 30, execution: 40, secondSide: 0, rest: 60, transition: 20), difficulty: 2, selection: 60, primary: ["shoulders"])
        add("dumbbell_lateral_raise__adjustable", movement: "dumbbell_lateral_raise", anchor: "accessory", role: .optional, loadMode: .pairEachKg, equipment: [adjustablePair], reps: 10...15,
            timing: .init(setup: 45, execution: 40, secondSide: 0, rest: 60, transition: 25), difficulty: 2, selection: 61, primary: ["shoulders"])
        add("dumbbell_biceps_curl__fixed", movement: "dumbbell_biceps_curl", anchor: "accessory", role: .optional, loadMode: .pairEachKg, equipment: [fixedPair], reps: 8...15,
            timing: .init(setup: 30, execution: 40, secondSide: 0, rest: 60, transition: 20), difficulty: 1, selection: 70, primary: ["biceps"])
        add("dumbbell_biceps_curl__adjustable", movement: "dumbbell_biceps_curl", anchor: "accessory", role: .optional, loadMode: .pairEachKg, equipment: [adjustablePair], reps: 8...15,
            timing: .init(setup: 45, execution: 40, secondSide: 0, rest: 60, transition: 25), difficulty: 1, selection: 71, primary: ["biceps"])
        add("easy_rower_intervals", anchor: "conditioning", role: .conditioning, equipment: [rower], reps: 4...6, unit: .intervals, sets: 1...1,
            timing: .init(setup: 75, execution: 300, secondSide: 0, rest: 0, transition: 45), difficulty: 2, selection: 10, primary: ["conditioning"])

        let substitutions: [V2Substitution] = [
            .init(from: "push_up", to: "incline_push_up", type: "strong", rank: 1),
            .init(from: "dumbbell_floor_press__fixed", to: "push_up", type: "partial", rank: 1),
            .init(from: "dumbbell_floor_press__adjustable", to: "push_up", type: "partial", rank: 1),
            .init(from: "seated_dumbbell_overhead_press__fixed", to: "band_overhead_press", type: "partial", rank: 1),
            .init(from: "seated_dumbbell_overhead_press__adjustable", to: "band_overhead_press", type: "partial", rank: 1),
            .init(from: "supported_one_arm_row__fixed", to: "seated_band_row", type: "partial", rank: 1),
            .init(from: "supported_one_arm_row__adjustable", to: "seated_band_row", type: "partial", rank: 1),
            .init(from: "supported_one_arm_row__kettlebell", to: "seated_band_row", type: "partial", rank: 1),
            .init(from: "pull_up", to: "band_assisted_pull_up", type: "strong", rank: 1),
            .init(from: "band_assisted_pull_up", to: "band_lat_pulldown_over_bar", type: "partial", rank: 1),
            .init(from: "squat", to: "chair_sit_to_stand", type: "strong", rank: 1),
            .init(from: "goblet_squat__fixed", to: "squat", type: "partial", rank: 1),
            .init(from: "goblet_squat__adjustable", to: "squat", type: "partial", rank: 1),
            .init(from: "goblet_squat__kettlebell", to: "squat", type: "partial", rank: 1),
            .init(from: "split_squat", to: "assisted_split_squat", type: "strong", rank: 1),
            .init(from: "dumbbell_romanian_deadlift__fixed", to: "wall_hip_hinge", type: "partial", rank: 1),
            .init(from: "dumbbell_romanian_deadlift__adjustable", to: "wall_hip_hinge", type: "partial", rank: 1),
            .init(from: "kettlebell_deadlift", to: "wall_hip_hinge", type: "partial", rank: 1),
            .init(from: "front_plank", to: "elevated_front_plank", type: "strong", rank: 1),
            .init(from: "suitcase_carry__dumbbell", to: "suitcase_march__dumbbell", type: "partial", rank: 1),
            .init(from: "suitcase_carry__kettlebell", to: "suitcase_march__kettlebell", type: "partial", rank: 1),
        ]

        return V2EngineConfiguration(
            catalogVersion: "product-v2.1.0",
            decisionPolicyVersion: "2.1.0",
            catalog: catalog,
            substitutions: substitutions,
            policy: V2DecisionPolicy(
                durationBudgetsSeconds: ["20": 1_200, "30": 1_800, "45": 2_700],
                historyDepthCompletedSessions: 12,
                returnQuestionAfterDaysWithoutComparableExposure: 30,
                anchorTieOrder: ["pull", "push", "knee", "hinge"],
                rangeCeilingConfirmations: 2
            ),
            requiresProductApproval: requiresProductApproval
        )
    }
}
