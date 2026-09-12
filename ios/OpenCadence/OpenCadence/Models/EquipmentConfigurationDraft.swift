import CadenceEngine
import Foundation

/// Editable declarations; EquipmentItem remains their atomic engine projection.
/// A nil family represents legacy data whose physical composition is unknown.
struct EquipmentConfigurationDraft: Codable, Equatable {
    var version = 1
    var fixed: [EquipmentWeightObject]?
    var kettlebells: [EquipmentWeightObject]?
    var adjustable: AdjustableEquipmentDraft?
    var bands: [EquipmentBandObject]?

    static func decode(_ data: Data?) -> Self? {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data), value.version == 1 else { return nil }
        return value
    }

    func projectedFamily(_ category: String) throws -> [EquipmentItem]? {
        switch category {
        case "fixed_dumbbell":
            guard let fixed else { return nil }
            guard !fixed.isEmpty else { throw EquipmentDeclarationError.incomplete }
            return try fixed.map { object in
                let weight = try object.validWeight()
                guard (1...2).contains(object.count) else { throw EquipmentDeclarationError.incomplete }
                return EquipmentItem(category: category, units: object.count, weightKg: weight,
                                     supportedConfigurations: ["single", "central", "unilateral"] + (object.count == 2 ? ["pair"] : []))
            }
        case "kettlebell":
            guard let kettlebells else { return nil }
            guard !kettlebells.isEmpty else { throw EquipmentDeclarationError.incomplete }
            return try kettlebells.map { object in
                EquipmentItem(category: category, units: 1, perUnitWeightsKg: [try object.validWeight()],
                              supportedConfigurations: ["single", "central", "unilateral"])
            }
        case "adjustable_dumbbell":
            guard let adjustable else { return nil }
            let loads = try adjustable.mountableWeights()
            let paired = Set(loads.pair)
            return loads.single.map { weight in
                EquipmentItem(category: category, units: paired.contains(weight) ? 2 : 1, perUnitWeightsKg: [weight],
                              supportedConfigurations: ["single", "central", "unilateral"] + (paired.contains(weight) ? ["pair"] : []))
            }
        case "resistance_band":
            guard let bands else { return nil }
            guard !bands.isEmpty, Set(bands.map(\.optionID)).count == bands.count else { throw EquipmentDeclarationError.incomplete }
            return try bands.map { band in
                guard !band.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !band.optionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EquipmentDeclarationError.incomplete }
                return EquipmentItem(category: category, units: 1, optionIDs: [band.optionID], supportedConfigurations: ["band"])
            }
        default: return nil
        }
    }

    mutating func freezeBandIdentities() {
        guard var values = bands else { return }
        for index in values.indices where values[index].optionID.isEmpty {
            let initialName = values[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !initialName.isEmpty else { continue }
            values[index].optionID = "lbs-band-v1:\(values[index].id.uuidString):\(initialName)"
        }
        bands = values
    }

    func bandDisplayName(for optionID: String) -> String {
        bands?.first { $0.optionID == optionID }?.name ?? Self.initialBandName(optionID)
    }

    static func bandDisplayName(for optionID: String, draftData: Data? = nil) -> String {
        decode(draftData)?.bandDisplayName(for: optionID) ?? initialBandName(optionID)
    }

    private static func initialBandName(_ optionID: String) -> String {
        let fields = optionID.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0] == "lbs-band-v1", UUID(uuidString: String(fields[1])) != nil else { return optionID }
        return String(fields[2])
    }

}

struct EquipmentWeightObject: Codable, Equatable, Identifiable {
    var id = UUID()
    var weightText = ""
    var count = 1

    func validWeight() throws -> Double {
        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")), value.isFinite,
              value > 0, value <= 100 else { throw EquipmentDeclarationError.weight }
        return value
    }
}

enum EquipmentBandResistance: String, Codable, CaseIterable, Identifiable {
    case light, medium, strong, unknown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: String(localized: "Léger")
        case .medium: String(localized: "Moyen")
        case .strong: String(localized: "Fort")
        case .unknown: String(localized: "Je ne sais pas")
        }
    }
}

struct EquipmentBandObject: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var resistance: EquipmentBandResistance = .unknown
    /// Frozen on first save. Never rewrite an option referenced by history.
    var optionID = ""
}

struct EquipmentPlateCount: Codable, Equatable, Identifiable {
    var grams: Int
    var count: Int
    var id: Int { grams }
}

struct AdjustableEquipmentDraft: Codable, Equatable {
    static let plateGrams = [500, 1_000, 1_250, 2_000, 2_500, 5_000, 10_000, 15_000, 20_000]
    var handleWeightText = ""
    var handleCount = 1
    var compatibleSetupConfirmed = false
    var plates: [EquipmentPlateCount] = []

    func mountableWeights() throws -> (single: [Double], pair: [Double]) {
        guard let handle = Double(handleWeightText.replacingOccurrences(of: ",", with: ".")), handle.isFinite,
              handle > 0, handle <= 20, (1...2).contains(handleCount), compatibleSetupConfirmed else {
            throw EquipmentDeclarationError.handles
        }
        var totals: [Int: Int] = [:]
        for plate in plates {
            guard Self.plateGrams.contains(plate.grams), (1...40).contains(plate.count) else { throw EquipmentDeclarationError.plates }
            totals[plate.grams, default: 0] += plate.count
        }
        guard totals.values.allSatisfy({ $0 <= 40 }) else { throw EquipmentDeclarationError.plates }
        // One token means two identical disks: one on each side of one handle.
        let tokens = totals.keys.sorted().flatMap { grams in
            Array(repeating: grams / 250, count: totals[grams, default: 0] / 2)
        }
        var singleSums: Set<Int> = [0]
        for token in tokens { singleSums.formUnion(singleSums.map { $0 + token }) }
        let single = singleSums.sorted().map { handle + Double($0) / 2 }
        guard handleCount == 2 else { return (single, []) }
        // Exact two-bin subset sum. A and B may use different plates, but each
        // handle is symmetric and both final masses must match. Integer units
        // and bounded standard plate quantities keep the bitset below 0.7 MB.
        let cap = tokens.reduce(0, +) / 2
        let stride = cap / 64 + 1
        var bits = [UInt64](repeating: 0, count: (cap + 1) * stride)
        bits[0] = 1
        for token in tokens {
            let wordShift = token / 64
            let bitShift = token % 64
            for a in Swift.stride(from: cap, through: 0, by: -1) {
                let row = a * stride
                for word in Swift.stride(from: stride - 1, through: 0, by: -1) {
                    let old = bits[row + word]
                    guard old != 0 else { continue }
                    if a + token <= cap { bits[(a + token) * stride + word] |= old }
                    let destination = word + wordShift
                    if destination < stride { bits[row + destination] |= old << bitShift }
                    if bitShift > 0, destination + 1 < stride {
                        bits[row + destination + 1] |= old >> (64 - bitShift)
                    }
                }
            }
        }
        let paired = (0...cap).filter { a in
            bits[a * stride + a / 64] & (UInt64(1) << (a % 64)) != 0
        }.map { handle + Double($0) / 2 }
        return (single, paired)
    }
}

enum EquipmentDeclarationError: LocalizedError {
    case incomplete, weight, handles, plates
    var errorDescription: String? {
        switch self {
        case .incomplete: String(localized: "Complète chaque objet sélectionné avant de continuer.")
        case .weight: String(localized: "Indique un poids entre 0 et 100 kg, sans inclure zéro.")
        case .handles: String(localized: "Précise le poids des poignées et confirme que ton montage est compatible et sécurisé.")
        case .plates: String(localized: "Vérifie les disques : de 1 à 40 pour chaque poids disponible.")
        }
    }
}
