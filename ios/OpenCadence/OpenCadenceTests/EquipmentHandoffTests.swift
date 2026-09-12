import CadenceEngine
import Foundation
import Testing
@testable import OpenCadence

struct EquipmentHandoffTests {
    private func movement(_ category: String, _ configuration: String) -> PrescribedMovement {
        PrescribedMovement(exerciseKey: "fixture", variant: "fixture", pattern: "push", sets: 2,
                           target: "8", restSeconds: 60,
                           equipment: [.init(category: category, configuration: configuration)])
    }

    @Test("Two handles do not imply every single dumbbell weight is mountable as a pair")
    func actualPairWeights() throws {
        let inventory = try EquipmentInventoryInput.dumbbells(category: "adjustable_dumbbell", single: "4 6 8 10", pair: "4 6")
        #expect(WorkoutLoadResolver.options(for: movement("adjustable_dumbbell", "single"), inventory: inventory) == [4, 6, 8, 10])
        #expect(WorkoutLoadResolver.options(for: movement("adjustable_dumbbell", "pair"), inventory: inventory) == [4, 6])
    }

    @Test("An undeclared pair remains unavailable")
    func noInferredPair() throws {
        let inventory = try EquipmentInventoryInput.dumbbells(category: "fixed_dumbbell", single: "8 12", pair: "")
        #expect(WorkoutLoadResolver.options(for: movement("fixed_dumbbell", "pair"), inventory: inventory).isEmpty)
        let ambiguous = EquipmentItem(category: "fixed_dumbbell", units: 2, weightKg: 20, supportedConfigurations: ["single"])
        #expect(WorkoutLoadResolver.options(for: movement("fixed_dumbbell", "pair"), inventory: [ambiguous]).isEmpty)
    }

    @Test("Multiple fixed weights preserve their individual configurations")
    func multipleFixedWeights() throws {
        let inventory = try EquipmentInventoryInput.dumbbells(category: "fixed_dumbbell", single: "8 12", pair: "8")
        #expect(inventory.count == 2)
        #expect(WorkoutLoadResolver.options(for: movement("fixed_dumbbell", "single"), inventory: inventory) == [8, 12])
        #expect(WorkoutLoadResolver.options(for: movement("fixed_dumbbell", "pair"), inventory: inventory) == [8])
    }

    @Test("Invalid input is rejected instead of silently dropping weights")
    func strictWeightInput() {
        for value in ["8 invalid 12", "nan", "inf", "0", "-2"] {
            #expect(throws: (any Error).self) { try EquipmentInventoryInput.weights(value) }
        }
        #expect(throws: (any Error).self) {
            try EquipmentInventoryInput.dumbbells(category: "adjustable_dumbbell", single: "", pair: "")
        }
    }

    @Test("Decimal comma, duplicates and pair-only declarations are supported")
    func localizedWeights() throws {
        #expect(try EquipmentInventoryInput.weights("2,5 4 2,5") == [2.5, 4])
        let inventory = try EquipmentInventoryInput.dumbbells(category: "fixed_dumbbell", single: "", pair: "6")
        #expect(WorkoutLoadResolver.options(for: movement("fixed_dumbbell", "single"), inventory: inventory) == [6])
    }

    @Test("Band names are only offered for a supported configuration")
    func bandConfigurations() {
        let inventory = [EquipmentItem(category: "resistance_band", units: 1, optionIDs: ["blue"], supportedConfigurations: ["band"])]
        #expect(WorkoutLoadResolver.optionIDs(for: movement("resistance_band", "band"), inventory: inventory) == ["blue"])
        #expect(WorkoutLoadResolver.optionIDs(for: movement("resistance_band", "pair"), inventory: inventory).isEmpty)
    }
}

struct EquipmentDeclarationTests {
    private func adjustable(_ counts: [(Int, Int)], handles: Int = 2) -> AdjustableEquipmentDraft {
        AdjustableEquipmentDraft(handleWeightText: "2", handleCount: handles, compatibleSetupConfirmed: true,
                                 plates: counts.map { EquipmentPlateCount(grams: $0.0, count: $0.1) })
    }

    @Test("Two sides and two handles consume actual available disks")
    func diskScarcity() throws {
        let result = try adjustable([(1_000, 2)]).mountableWeights()
        #expect(result.single == [2, 4])
        #expect(result.pair == [2])
        let odd = try adjustable([(1_000, 3)], handles: 1).mountableWeights()
        #expect(odd.single == [2, 4])
        #expect(odd.pair.isEmpty)
    }

    @Test("Identical masses may use different plate compositions on the two handles")
    func differentCompositions() throws {
        let result = try adjustable([(1_000, 2), (500, 4)]).mountableWeights()
        #expect(result.single == [2, 3, 4, 5, 6])
        #expect(result.pair == [2, 3, 4])
    }

    @Test("Duplicate disk rows are merged before symmetric availability is computed")
    func duplicateRows() throws {
        let split = try adjustable([(1_250, 1), (1_250, 3)]).mountableWeights()
        #expect(split.single == [2, 4.5, 7])
        #expect(split.pair == [2, 4.5])
        #expect(throws: (any Error).self) {
            try adjustable([(1_000, 30), (1_000, 20)]).mountableWeights()
        }
    }

    @Test("Unknown or unsupported physical declarations cannot produce loads")
    func incompleteDeclarations() {
        #expect(throws: (any Error).self) { try AdjustableEquipmentDraft().mountableWeights() }
        #expect(throws: (any Error).self) { try adjustable([(750, 4)]).mountableWeights() }
        #expect(throws: (any Error).self) { try adjustable([(1_000, -1)]).mountableWeights() }
        #expect(throws: (any Error).self) { try adjustable([(1_000, 41)]).mountableWeights() }
        #expect(throws: (any Error).self) { try adjustable([(1_000, 4)], handles: 3).mountableWeights() }
        var declaration = adjustable([(1_000, 4)])
        declaration.handleWeightText = "nan"
        #expect(throws: (any Error).self) { try declaration.mountableWeights() }
        declaration.handleWeightText = "2"
        declaration.compatibleSetupConfirmed = false
        #expect(throws: (any Error).self) { try declaration.mountableWeights() }
    }

    @Test("Bitset allocation matches exhaustive physical allocations for small inventories")
    func exactAllocationOracle() throws {
        for oneKilogramCount in 0...8 {
            for halfKilogramCount in 0...8 {
                let counts = [(1_000, oneKilogramCount), (500, halfKilogramCount)].filter { $0.1 > 0 }
                let result = try adjustable(counts).mountableWeights()
                var expected: Set<Double> = [2]
                let onePairs = oneKilogramCount / 2
                let halfPairs = halfKilogramCount / 2
                for aOne in 0...onePairs {
                    for bOne in 0...(onePairs - aOne) {
                        for aHalf in 0...halfPairs {
                            for bHalf in 0...(halfPairs - aHalf) where 2 * aOne + aHalf == 2 * bOne + bHalf {
                                expected.insert(2 + Double(2 * aOne + aHalf))
                            }
                        }
                    }
                }
                #expect(result.pair == expected.sorted())
            }
        }
    }

    @Test("Draft round-trip preserves objects and immutable band identity through rename")
    func identityAndPersistence() throws {
        var draft = EquipmentConfigurationDraft(
            fixed: [EquipmentWeightObject(weightText: "8", count: 2), EquipmentWeightObject(weightText: "12", count: 1)],
            bands: [EquipmentBandObject(name: "Bleu", resistance: .unknown), EquipmentBandObject(name: "Bleu", resistance: .light)]
        )
        draft.freezeBandIdentities()
        let identities = try #require(draft.bands?.map(\.optionID))
        #expect(identities.count == 2 && Set(identities).count == 2)
        #expect(identities.allSatisfy { $0.hasPrefix("lbs-band-v1:") && $0.hasSuffix(":Bleu") })
        draft.bands?[0].name = "Bleu renommé"
        draft.bands?[0].resistance = .strong
        draft.freezeBandIdentities()
        #expect(draft.bands?.map(\.optionID) == identities)
        #expect(draft.bandDisplayName(for: identities[0]) == "Bleu renommé")
        let restored = try #require(EquipmentConfigurationDraft.decode(JSONEncoder().encode(draft)))
        #expect(restored == draft)
        let bands = try #require(try restored.projectedFamily("resistance_band"))
        #expect(bands.count == 2)
        #expect(bands.allSatisfy { $0.optionIDs?.count == 1 && $0.weightKg == nil && $0.perUnitWeightsKg == nil })
        let fixed = try #require(try restored.projectedFamily("fixed_dumbbell"))
        #expect(fixed.first?.supports("pair") == true)
        #expect(fixed.last?.supports("pair") == false)
    }

    @Test("Deleting and recreating a same-name band never reuses historical identity")
    func recreatedBandIdentity() throws {
        var draft = EquipmentConfigurationDraft(bands: [EquipmentBandObject(name: "Bleu")])
        draft.freezeBandIdentities()
        let oldID = try #require(draft.bands?.first?.optionID)
        draft.bands = []
        draft = try #require(EquipmentConfigurationDraft.decode(JSONEncoder().encode(draft)))
        draft.bands = [EquipmentBandObject(name: "Bleu")]
        draft.freezeBandIdentities()
        #expect(draft.bands?.first?.optionID != oldID)
        #expect(draft.bandDisplayName(for: oldID) == "Bleu")
        #expect(EquipmentConfigurationDraft.bandDisplayName(for: oldID, draftData: nil) == "Bleu")
        #expect(EquipmentConfigurationDraft.bandDisplayName(for: oldID, draftData: Data("broken".utf8)) == "Bleu")
        #expect(EquipmentConfigurationDraft.bandDisplayName(for: "ancienne bande", draftData: nil) == "ancienne bande")
    }

    @Test("Missing, corrupt and newer drafts never invent a physical inventory")
    func conservativeLegacy() throws {
        #expect(EquipmentConfigurationDraft.decode(nil) == nil)
        #expect(EquipmentConfigurationDraft.decode(Data("invalid".utf8)) == nil)
        var newer = EquipmentConfigurationDraft()
        newer.version = 99
        #expect(EquipmentConfigurationDraft.decode(try JSONEncoder().encode(newer)) == nil)
        #expect(try EquipmentConfigurationDraft().projectedFamily("adjustable_dumbbell") == nil)
    }
}
