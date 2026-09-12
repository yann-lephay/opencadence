import CadenceEngine
import Foundation

enum WorkoutLoadResolver {
    static func requiresLoad(_ movement: PrescribedMovement) -> Bool {
        movement.equipment.contains {
            ["fixed_dumbbell", "adjustable_dumbbell", "kettlebell", "weighted_vest"].contains($0.category)
        }
    }

    static func requiresOption(_ movement: PrescribedMovement) -> Bool {
        movement.equipment.contains { $0.category == "resistance_band" }
    }

    static func options(
        for movement: PrescribedMovement,
        inventory: [EquipmentItem]
    ) -> [Double] {
        return Array(Set(inventory.flatMap { item -> [Double] in
            guard movement.equipment.contains(where: { $0.category == item.category && item.supports($0.configuration) }) else { return [] }
            switch item.category {
            case "fixed_dumbbell":
                return item.weightKg.map { [$0] } ?? []
            case "adjustable_dumbbell", "kettlebell", "weighted_vest":
                return item.perUnitWeightsKg ?? []
            default:
                return []
            }
        })).sorted()
    }


    static func optionIDs(
        for movement: PrescribedMovement,
        inventory: [EquipmentItem]
    ) -> [String] {
        return inventory
            .filter { item in movement.equipment.contains { $0.category == item.category && item.supports($0.configuration) } }
            .flatMap { $0.optionIDs ?? [] }
            .reduce(into: [String]()) { result, option in
                if !result.contains(option) { result.append(option) }
            }
    }

    static func loadLabel(for movement: PrescribedMovement) -> String {
        let categories = Set(movement.equipment.map(\.category))
        if categories.contains("weighted_vest") { return String(localized: "kg ajoutés") }
        if categories.contains("kettlebell") { return String(localized: "kg") }
        if movement.equipment.contains(where: { $0.configuration == "pair" }) {
            return String(localized: "kg par haltère")
        }
        return String(localized: "kg")
    }
}
