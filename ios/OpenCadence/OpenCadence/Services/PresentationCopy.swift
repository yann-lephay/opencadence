import CadenceEngine
import Foundation

enum PresentationCopy {
    static func movementTitle(_ exerciseKey: String) -> String {
        let movementID = V2EngineConfiguration.productPreview.catalog[exerciseKey]?.resolvedMovementId ?? exerciseKey
        return switch movementID {
        case "incline_pushup", "incline_push_up": String(localized: "Pompes inclinées")
        case "bodyweight_squat", "squat": String(localized: "Squat libre")
        case "bodyweight_hinge", "wall_hip_hinge": String(localized: "Charnière de hanche vers le mur")
        case "assisted_pullup": String(localized: "Tractions assistées")
        case "one_arm_row", "foundation_one_arm_row": String(localized: "Rowing à un bras")
        case "goblet_squat", "fixed_goblet_squat", "established_goblet_squat": String(localized: "Goblet squat")
        case "floor_press", "fixed_floor_press", "foundation_floor_press", "dumbbell_floor_press": String(localized: "Développé au sol avec haltères")
        case "romanian_deadlift", "fixed_romanian_deadlift", "established_romanian_deadlift", "dumbbell_romanian_deadlift": String(localized: "Soulevé de terre roumain avec haltères")
        case "push_up": String(localized: "Pompes")
        case "single_arm_dumbbell_floor_press": String(localized: "Développé au sol à un bras")
        case "seated_dumbbell_overhead_press": String(localized: "Développé épaules assis")
        case "single_arm_overhead_press": String(localized: "Développé au-dessus de la tête à un bras")
        case "band_overhead_press": String(localized: "Développé épaules à l’élastique")
        case "supported_one_arm_row": String(localized: "Rowing unilatéral avec appui")
        case "seated_band_row": String(localized: "Tirage assis à l’élastique")
        case "bent_over_dumbbell_row": String(localized: "Rowing penché avec haltères")
        case "dip_bar_inverted_row": String(localized: "Rowing inversé aux barres de dips")
        case "band_lat_pulldown_over_bar": String(localized: "Tirage vertical à l’élastique")
        case "band_assisted_pull_up": String(localized: "Tractions assistées par élastique")
        case "eccentric_pull_up": String(localized: "Descente contrôlée de traction")
        case "pull_up": String(localized: "Tractions en pronation")
        case "chair_sit_to_stand": String(localized: "Lever de chaise")
        case "double_dumbbell_front_squat": String(localized: "Squat avec haltères aux épaules")
        case "assisted_split_squat": String(localized: "Fente statique assistée")
        case "split_squat": String(localized: "Fente statique")
        case "reverse_lunge": String(localized: "Fente arrière")
        case "low_step_up": String(localized: "Montée sur banc bas")
        case "glute_bridge": String(localized: "Pont fessier")
        case "kettlebell_deadlift": String(localized: "Soulevé de terre avec kettlebell")
        case "band_good_morning": String(localized: "Good morning à l’élastique")
        case "dumbbell_hip_thrust": String(localized: "Hip thrust avec haltère")
        case "kickstand_romanian_deadlift": String(localized: "Soulevé de terre roumain décalé")
        case "dead_bug": String(localized: "Dead bug")
        case "elevated_front_plank": String(localized: "Planche inclinée")
        case "front_plank": String(localized: "Planche avant")
        case "side_plank": String(localized: "Planche latérale")
        case "suitcase_carry": String(localized: "Marche chargée unilatérale")
        case "farmer_carry": String(localized: "Marche du fermier")
        case "suitcase_march": String(localized: "Marche sur place chargée")
        case "supported_calf_raise": String(localized: "Élévations de mollets avec appui")
        case "supported_single_leg_calf_raise": String(localized: "Élévation de mollet sur une jambe")
        case "dumbbell_lateral_raise": String(localized: "Élévations latérales")
        case "dumbbell_biceps_curl": String(localized: "Curl biceps avec haltères")
        case "easy_rower_intervals": String(localized: "Intervalles faciles au rameur")
        default: movementID.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func patternTitle(_ pattern: String) -> String {
        switch pattern {
        case "pull": String(localized: "Tirer")
        case "push": String(localized: "Pousser")
        case "knee": String(localized: "Jambes")
        case "hinge": String(localized: "Hanches")
        case "core": String(localized: "Tronc")
        case "carry": String(localized: "Porté")
        case "calf": String(localized: "Mollets")
        case "accessory": String(localized: "Complément")
        case "conditioning": String(localized: "Conditionnement")
        default: pattern.capitalized
        }
    }

    static func readinessTitle(_ readiness: Readiness?) -> String {
        switch readiness?.label {
        case "green": String(localized: "Rythme habituel")
        case "reduced": String(localized: "Séance allégée")
        case "technical": String(localized: "Séance technique")
        case "recalibration": String(localized: "Reprise progressive")
        case "return": String(localized: "Retour en douceur")
        default: String(localized: "Séance adaptée")
        }
    }

    static func explanation(_ reasonCodes: [String]) -> String {
        if reasonCodes.contains("limitation.no_compatible_plan") {
            return String(localized: "Les mouvements écartés ne laissent aucun programme valide dans le catalogue actuel. Tes choix sont conservés pour être modifiés.")
        }
        if reasonCodes.contains("limitation.user_excluded_movement") {
            return String(localized: "La séance a été recalculée sans les mouvements que tu as écartés. Vérifie le nouveau programme avant de commencer.")
        }
        if reasonCodes.contains("equipment.pattern_capacity_cap") {
            return String(localized: "La séance reste volontairement compacte : elle utilise seulement les mouvements compatibles avec ton matériel.")
        }
        if reasonCodes.contains("equipment.no_supported_pull") {
            return String(localized: "Le matériel enregistré ne permet pas encore un mouvement de tirage validé. Les autres familles restent couvertes.")
        }
        if reasonCodes.contains(where: { $0.hasPrefix("readiness.") }) {
            return String(localized: "Le volume a été ajusté à partir de tes dernières séances, sans chercher à compenser ni à te pousser au-delà du nécessaire.")
        }
        return String(localized: "Le moteur répartit le temps entre les grandes familles de mouvements compatibles avec ce que tu as chez toi.")
    }

    static func equipmentSummary(_ inventory: [EquipmentItem]) -> String {
        inventory.compactMap { item in
            switch item.category {
            case "bodyweight": String(localized: "Poids du corps")
            case "fixed_dumbbell": item.weightKg.map { value in
                item.units == 1
                    ? String.localizedStringWithFormat(
                        String(localized: "1 haltère de %@ kg"),
                        weight(value)
                    )
                    : String.localizedStringWithFormat(
                        String(localized: "%lld haltères de %@ kg chacun"),
                        item.units,
                        weight(value)
                    )
            } ?? String(localized: "Haltères fixes")
            case "adjustable_dumbbell": String(localized: "Haltères réglables")
            case "kettlebell": String(localized: "Kettlebells")
            case "resistance_band": String(localized: "Élastiques")
            case "pullup_bar": String(localized: "Barre de traction")
            case "dip_bars": String(localized: "Barres de dips")
            case "weighted_vest": String(localized: "Gilet lesté")
            case "rower": String(localized: "Rameur")
            default: nil
            }
        }.joined(separator: " · ")
    }

    static func calibrationTitle(_ value: String) -> String {
        value == "established"
            ? String(localized: "Mouvements familiers")
            : String(localized: "Reprendre progressivement")
    }

    static func loadSummary(_ movement: PrescribedMovement, decision: EngineDecision) -> String? {
        guard let recommendation = decision.recommendedLoads?.first(where: { recommendation in
            movement.equipment.contains {
                $0.category == recommendation.category && $0.configuration == recommendation.configuration
            }
        }), let weight = recommendation.perUnitWeightKg else { return nil }
        return String.localizedStringWithFormat(
            String(localized: "%@ kg par haltère"),
            Self.weight(weight)
        )
    }

    static func progression(_ progression: Progression) -> String {
        let movement = movementTitle(progression.exerciseKey)
        switch progression.action {
        case "increase_reps":
            return String.localizedStringWithFormat(
                String(localized: "Sur %@, le moteur propose une répétition de plus à charge identique."),
                movement
            )
        case "increase_load":
            return String.localizedStringWithFormat(
                String(localized: "Sur %@, le prochain palier disponible est %@ kg par haltère, avec un retour en bas de fourchette."),
                movement,
                weight(progression.perUnitWeightKg)
            )
        case "hold_load":
            return String.localizedStringWithFormat(
                String(localized: "Sur %@, garde la même charge : aucun palier supérieur déclaré n’est disponible."),
                movement
            )
        default:
            return String.localizedStringWithFormat(
                String(localized: "La prochaine adaptation de %@ repose sur tes résultats enregistrés."),
                movement
            )
        }
    }

    private static func weight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}
