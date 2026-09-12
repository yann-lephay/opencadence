public extension EngineCatalog {
    static let referenceV1 = EngineCatalog(
        exercises: [
            "incline_pushup": exercise(
                pattern: "push",
                variant: "incline_pushup",
                target: "6-12 reps",
                rest: 90,
                equipment: [("bodyweight", "bodyweight")]
            ),
            "bodyweight_squat": exercise(
                pattern: "knee",
                variant: "bodyweight_squat",
                target: "8-15 reps",
                rest: 90,
                equipment: [("bodyweight", "bodyweight")]
            ),
            "bodyweight_hinge": exercise(
                pattern: "hinge",
                variant: "bodyweight_hinge",
                target: "8-15 reps",
                rest: 90,
                equipment: [("bodyweight", "bodyweight")]
            ),
            "assisted_pullup": exercise(
                pattern: "pull",
                variant: "foot_assisted_pullup",
                target: "3-8 reps",
                rest: 120,
                equipment: [("bodyweight", "bodyweight"), ("pullup_bar", "bodyweight")]
            ),
            "one_arm_row": exercise(
                pattern: "pull",
                variant: "supported_one_arm_row",
                target: "8-12 reps per side",
                rest: 90,
                equipment: [("adjustable_dumbbell", "unilateral")]
            ),
            "goblet_squat": exercise(
                pattern: "knee",
                variant: "goblet_squat",
                target: "8-12 reps",
                rest: 90,
                equipment: [("adjustable_dumbbell", "central")]
            ),
            "floor_press": exercise(
                pattern: "push",
                variant: "dumbbell_floor_press",
                target: "6-12 reps",
                rest: 120,
                equipment: [("adjustable_dumbbell", "pair")]
            ),
            "romanian_deadlift": exercise(
                pattern: "hinge",
                variant: "dumbbell_romanian_deadlift",
                target: "8-12 reps",
                rest: 120,
                equipment: [("adjustable_dumbbell", "pair")]
            ),
            "fixed_goblet_squat": exercise(
                pattern: "knee",
                variant: "goblet_squat",
                target: "8-12 reps",
                rest: 90,
                equipment: [("fixed_dumbbell", "central")]
            ),
            "fixed_floor_press": exercise(
                pattern: "push",
                variant: "dumbbell_floor_press",
                target: "6-12 reps",
                rest: 120,
                equipment: [("fixed_dumbbell", "pair")]
            ),
            "fixed_romanian_deadlift": exercise(
                pattern: "hinge",
                variant: "dumbbell_romanian_deadlift",
                target: "8-12 reps",
                rest: 120,
                equipment: [("fixed_dumbbell", "pair")]
            ),
            "foundation_one_arm_row": exercise(
                pattern: "pull",
                variant: "supported_one_arm_row_short_range",
                calibration: "foundation",
                target: "6-10 reps per side",
                rest: 90,
                equipment: [("adjustable_dumbbell", "unilateral")]
            ),
            "foundation_floor_press": exercise(
                pattern: "push",
                variant: "neutral_grip_floor_press",
                calibration: "foundation",
                target: "6-10 reps",
                rest: 120,
                equipment: [("adjustable_dumbbell", "pair")]
            ),
            "established_goblet_squat": exercise(
                pattern: "knee",
                variant: "tempo_goblet_squat",
                calibration: "established",
                target: "8-12 reps",
                rest: 90,
                equipment: [("adjustable_dumbbell", "central")]
            ),
            "established_romanian_deadlift": exercise(
                pattern: "hinge",
                variant: "dumbbell_romanian_deadlift",
                calibration: "established",
                target: "8-12 reps",
                rest: 120,
                equipment: [("adjustable_dumbbell", "pair")]
            ),
        ],
        planProfiles: [
            "bodyweight-7": plan(("incline_pushup", 3), ("bodyweight_squat", 2), ("bodyweight_hinge", 2)),
            "bodyweight-8": plan(("incline_pushup", 3), ("bodyweight_squat", 3), ("bodyweight_hinge", 2)),
            "bodyweight-9": plan(("incline_pushup", 3), ("bodyweight_squat", 3), ("bodyweight_hinge", 3)),
            "bodyweight-10": plan(("incline_pushup", 4), ("bodyweight_squat", 3), ("bodyweight_hinge", 3)),
            "bodyweight-12": plan(("incline_pushup", 4), ("bodyweight_squat", 4), ("bodyweight_hinge", 4)),
            "fixed-full-12": plan(
                ("assisted_pullup", 3),
                ("fixed_goblet_squat", 3),
                ("fixed_floor_press", 3),
                ("fixed_romanian_deadlift", 3)
            ),
            "adjustable-full-8": plan(
                ("one_arm_row", 2), ("goblet_squat", 2), ("floor_press", 2), ("romanian_deadlift", 2)
            ),
            "adjustable-full-12": plan(
                ("one_arm_row", 3), ("goblet_squat", 3), ("floor_press", 3), ("romanian_deadlift", 3)
            ),
            "adjustable-full-16": plan(
                ("one_arm_row", 4), ("goblet_squat", 4), ("floor_press", 4), ("romanian_deadlift", 4)
            ),
            "adjustable-pull-priority-9": plan(
                ("one_arm_row", 3), ("goblet_squat", 2), ("floor_press", 2), ("romanian_deadlift", 2)
            ),
            "adjustable-push-priority-9": plan(
                ("one_arm_row", 2), ("goblet_squat", 2), ("floor_press", 3), ("romanian_deadlift", 2)
            ),
            "adjustable-pull-priority-12": plan(
                ("one_arm_row", 4), ("goblet_squat", 3), ("floor_press", 2), ("romanian_deadlift", 3)
            ),
            "split-calibrated-12": plan(
                ("foundation_one_arm_row", 3),
                ("established_goblet_squat", 3),
                ("foundation_floor_press", 3),
                ("established_romanian_deadlift", 3)
            ),
            "foundation-foundation-12": plan(
                ("foundation_one_arm_row", 3),
                ("goblet_squat", 3),
                ("foundation_floor_press", 3),
                ("romanian_deadlift", 3)
            ),
            "established-established-12": plan(
                ("one_arm_row", 3),
                ("established_goblet_squat", 3),
                ("floor_press", 3),
                ("established_romanian_deadlift", 3)
            ),
            "wrist-baseline-12": plan(
                ("one_arm_row", 3), ("goblet_squat", 3), ("incline_pushup", 3), ("romanian_deadlift", 3)
            ),
            "wrist-substitution-12": plan(
                ("one_arm_row", 3), ("goblet_squat", 3), ("floor_press", 3), ("romanian_deadlift", 3)
            ),
        ]
    )

    private static func exercise(
        pattern: String,
        variant: String,
        calibration: String? = nil,
        target: String,
        rest: Int,
        equipment: [(String, String)]
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            pattern: pattern,
            variant: variant,
            calibrationBand: calibration,
            target: target,
            restSeconds: rest,
            equipment: equipment.map(EquipmentRequirement.init(category:configuration:))
        )
    }

    private static func plan(_ rows: (String, Int)...) -> [PlanRow] {
        rows.map(PlanRow.init(exerciseKey:sets:))
    }
}
