import CadenceEngine
import SwiftData
import SwiftUI

struct EquipmentOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let existing: UserSetupRecord?
    private let onSaved: (() -> Void)?

    @State private var equipmentDraft: EquipmentConfigurationDraft
    private let savedDraftUnreadable: Bool

    @State private var fixedDumbbellsEnabled: Bool
    @State private var adjustablePairWeightsText: String
    @State private var showingDetails = false
    @State private var noEquipment: Bool
    @State private var editedCategories: Set<String> = []
    @State private var adjustableDumbbellsEnabled: Bool
    @State private var adjustableWeightsText: String
    @State private var kettlebellsEnabled: Bool
    @State private var bandsEnabled: Bool
    @State private var weightedVestEnabled: Bool
    @State private var vestWeightsText: String
    @State private var pullupBarEnabled: Bool
    @State private var dipBarsEnabled: Bool
    @State private var rowerEnabled: Bool
    @State private var errorMessage: String?

    init(existing: UserSetupRecord? = nil, onSaved: (() -> Void)? = nil) {
        self.existing = existing
        self.onSaved = onSaved
        let inventory = existing?.inventory ?? []
        let fixed = inventory.first { $0.category == "fixed_dumbbell" }
        let adjustable = inventory.first { $0.category == "adjustable_dumbbell" }
        let kettlebell = inventory.first { $0.category == "kettlebell" }
        let savedDraft = EquipmentConfigurationDraft.decode(existing?.equipmentDraftData)
        savedDraftUnreadable = existing?.equipmentDraftData != nil && savedDraft == nil
        func weights(_ category: String, pair: Bool) -> String {
            inventory.filter { $0.category == category && $0.supports(pair ? "pair" : "single") }
                .flatMap { $0.weightKg.map { [$0] } ?? $0.perUnitWeightsKg ?? [] }
                .reduce(into: [Double]()) { if !$0.contains($1) { $0.append($1) } }
                .sorted().map { String($0) }.joined(separator: " ")
        }
        func weightObjects(_ category: String) -> [EquipmentWeightObject] {
            inventory.filter { $0.category == category }.flatMap { item in
                (item.weightKg.map { [$0] } ?? item.perUnitWeightsKg ?? []).map { weight in
                    EquipmentWeightObject(
                        weightText: weight.formatted(.number.precision(.fractionLength(0...2))),
                        count: category == "fixed_dumbbell" && item.supports("pair") ? 2 : 1
                    )
                }
            }
        }
        let legacyBands = inventory.filter { $0.category == "resistance_band" }
            .flatMap { $0.optionIDs ?? [] }
            .map { optionID in
                EquipmentBandObject(
                    name: EquipmentConfigurationDraft.bandDisplayName(for: optionID),
                    resistance: .unknown,
                    optionID: optionID
                )
            }
        var initialDraft = savedDraft ?? EquipmentConfigurationDraft(
            fixed: weightObjects("fixed_dumbbell"),
            kettlebells: weightObjects("kettlebell"),
            adjustable: adjustable == nil ? AdjustableEquipmentDraft() : nil,
            bands: legacyBands
        )
        if initialDraft.fixed == nil { initialDraft.fixed = weightObjects("fixed_dumbbell") }
        if initialDraft.kettlebells == nil { initialDraft.kettlebells = weightObjects("kettlebell") }
        if initialDraft.bands == nil { initialDraft.bands = legacyBands }
        _equipmentDraft = State(initialValue: initialDraft)
        _fixedDumbbellsEnabled = State(initialValue: fixed != nil)
        _adjustableDumbbellsEnabled = State(initialValue: adjustable != nil)
        _adjustableWeightsText = State(initialValue: weights("adjustable_dumbbell", pair: false))
        _adjustablePairWeightsText = State(initialValue: weights("adjustable_dumbbell", pair: true))
        _noEquipment = State(initialValue: existing != nil && inventory.allSatisfy { $0.category == "bodyweight" })
        _kettlebellsEnabled = State(initialValue: kettlebell != nil)
        _bandsEnabled = State(initialValue: inventory.contains { $0.category == "resistance_band" })
        _weightedVestEnabled = State(initialValue: inventory.contains { $0.category == "weighted_vest" })
        let savedVestWeights = inventory.filter { $0.category == "weighted_vest" }
            .flatMap { $0.perUnitWeightsKg ?? [] }
            .sorted()
        let normalizedVestWeights: [Double]
        if savedVestWeights.count == 1, let maximum = savedVestWeights.first,
           Self.isHalfKiloVestMaximum(maximum) {
            normalizedVestWeights = (1...max(1, Int((maximum * 2).rounded())))
                .map { Double($0) / 2 }
        } else {
            normalizedVestWeights = savedVestWeights
        }
        _vestWeightsText = State(initialValue: normalizedVestWeights
            .map { $0.formatted(.number.precision(.fractionLength(0...1))) }
            .joined(separator: " "))
        _pullupBarEnabled = State(initialValue: inventory.contains { $0.category == "pullup_bar" })
        _dipBarsEnabled = State(initialValue: inventory.contains { $0.category == "dip_bars" })
        _rowerEnabled = State(initialValue: inventory.contains { $0.category == "rower" })
    }

    var body: some View {
        Group {
            if showingDetails { details }
            else { familySelection }
        }
        .id(showingDetails)
        .tint(LBSBrand.controlTint)

    }

    private func tracked(_ value: Binding<String>, category: String) -> Binding<String> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                editedCategories.insert(category)
            }
        )
    }

    private func draftBinding<Value>(_ path: WritableKeyPath<EquipmentConfigurationDraft, Value?>, fallback: Value, category: String) -> Binding<Value> {
        Binding(get: { equipmentDraft[keyPath: path] ?? fallback }, set: { value in
            equipmentDraft[keyPath: path] = value
            editedCategories.insert(category)
        })
    }

    private var needsLoadDetails: Bool {
        fixedDumbbellsEnabled || adjustableDumbbellsEnabled || kettlebellsEnabled
            || bandsEnabled || weightedVestEnabled
    }

    private func advance() {
        guard needsLoadDetails else { save(); return }
        if bandsEnabled, equipmentDraft.bands?.isEmpty == true {
            equipmentDraft.bands?.append(EquipmentBandObject())
        }
        showingDetails = true
    }

    private func equipmentCard<Content: View>(
        _ title: LocalizedStringKey,
        asset: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.archivoBlack(21, relativeTo: .title3))
                    .foregroundStyle(LBSBrand.brandText)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LBSBrand.border))
        .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var details: some View {
        List {
            Button("Matériel", systemImage: "chevron.left") { showingDetails = false }
                .font(.headline)
                .frame(minHeight: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 0, trailing: 24))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Text(needsLoadDetails ? "Précise simplement ce que tu as" : "Ton matériel est prêt")
                .font(.archivoBlack(30, relativeTo: .title))
                .foregroundStyle(LBSBrand.brandText)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 12, trailing: 24))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if savedDraftUnreadable {
                Label("Les anciens détails seront conservés tant que tu ne modifies pas ce matériel.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            loadDetails

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button(existing == nil ? "Continuer" : "Mettre à jour") { save() }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .buttonStyle(.plain)
                .foregroundStyle(LBSBrand.cream)
                .background(LBSBrand.ink, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var loadDetails: some View {
            if fixedDumbbellsEnabled {
                fixedObjects
            }
            if adjustableDumbbellsEnabled {
                if equipmentDraft.adjustable != nil { adjustableObjects } else {
                equipmentCard("Haltères réglables", asset: "gear-db-transparent") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Poids montables sur un haltère (kg)")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("kg", text: tracked($adjustableWeightsText, category: "adjustable_dumbbell"))
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Poids montables sur un haltère (kg)")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Poids montables sur deux haltères à la fois (kg chacun)")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("kg", text: tracked($adjustablePairWeightsText, category: "adjustable_dumbbell"))
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Poids montables sur deux haltères à la fois (kg chacun)")
                    }
                    Button("Décrire les objets et leur montage") {
                        equipmentDraft.adjustable = AdjustableEquipmentDraft()
                        editedCategories.insert("adjustable_dumbbell")
                    }
                }
                }
            }
            if kettlebellsEnabled {
                kettlebellObjects
            }

            if bandsEnabled {
                bandObjects
            }

            if weightedVestEnabled {
                equipmentCard("Gilet lesté", asset: "gear-vest-transparent") {
                    Menu {
                        ForEach(Self.vestMaximumWeights, id: \.self) { weight in
                            Button("\(weightLabel(weight)) kg") {
                                setVestMaximum(weight)
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Charge maximale")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(vestMaximumWeight.map { "\(weightLabel($0)) kg" } ?? String(localized: "Choisir"))
                                    .font(.headline)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Charge maximale")
                    .accessibilityValue(vestMaximumWeight.map { "\(weightLabel($0)) kg" } ?? String(localized: "Non choisie"))
                }
            }


    }

    private var fixedObjects: some View {
        Section {
            let objects = draftBinding(\.fixed, fallback: [], category: "fixed_dumbbell")
            weightObjectRows(objects, options: Self.dumbbellWeights, allowsPair: true)
            addWeightMenu("Ajouter un haltère", objects: objects, options: Self.dumbbellWeights)
        } header: {
            equipmentHeader("Haltères fixes", asset: "gear-fixed-db-transparent")
        }
    }

    private var kettlebellObjects: some View {
        Section {
            let objects = draftBinding(\.kettlebells, fallback: [], category: "kettlebell")
            weightObjectRows(objects, options: Self.kettlebellWeights, allowsPair: false)
            addWeightMenu("Ajouter une kettlebell", objects: objects, options: Self.kettlebellWeights)
        } header: {
            equipmentHeader("Kettlebells", asset: "gear-kb-transparent")
        }
    }

    private func equipmentHeader(_ title: LocalizedStringKey, asset: String) -> some View {
        HStack(spacing: 10) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            Text(title)
                .font(.archivoBlack(20, relativeTo: .headline))
                .foregroundStyle(LBSBrand.brandText)
                .textCase(nil)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private static let kettlebellWeights = Array(stride(from: 2.0, through: 48.0, by: 2.0))
    private static let vestMaximumWeights = (1...20).map { Double($0) / 2 }
    private static func isHalfKiloVestMaximum(_ value: Double) -> Bool {
        value >= 0.5 && value <= 10 && abs(value * 2 - (value * 2).rounded()) < 0.000_001
    }
    private static let dumbbellWeights: [Double] = [
        1, 2, 3, 4, 5, 6, 7, 7.5, 8, 9, 10, 12, 12.5, 14, 15, 16,
        17.5, 18, 20, 22.5, 24, 25, 27.5, 30, 32.5, 35, 37.5, 40, 42.5, 45, 47.5, 50
    ]

    private func weightObjectRows(
        _ objects: Binding<[EquipmentWeightObject]>,
        options: [Double],
        allowsPair: Bool
    ) -> some View {
        ForEach(objects) { object in
            VStack(alignment: .leading, spacing: 12) {
                Menu {
                    ForEach(options, id: \.self) { weight in
                        Button("\(weightLabel(weight)) kg") {
                            object.weightText.wrappedValue = weightLabel(weight)
                        }
                    }
                } label: {
                    HStack {
                        Text(object.weightText.wrappedValue.isEmpty ? "Choisir un poids" : "\(object.weightText.wrappedValue) kg")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityLabel("Poids")
                .accessibilityValue(object.weightText.wrappedValue.isEmpty ? "Non choisi" : "\(object.weightText.wrappedValue) kg")
                if allowsPair {
                    Picker("Nombre d’haltères", selection: object.count) {
                        Text("Un").tag(1)
                        Text("Deux identiques").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    withAnimation {
                        objects.wrappedValue.removeAll { $0.id == object.wrappedValue.id }
                    }
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
    }

    private func addWeightMenu(
        _ title: LocalizedStringKey,
        objects: Binding<[EquipmentWeightObject]>,
        options: [Double]
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { weight in
                Button("\(weightLabel(weight)) kg") {
                    objects.wrappedValue.append(EquipmentWeightObject(weightText: weightLabel(weight)))
                }
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "plus.circle.fill")
            }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 10, trailing: 24))
        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func weightLabel(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var vestMaximumWeight: Double? {
        vestWeightsText
            .split(whereSeparator: { $0.isWhitespace || $0 == ";" })
            .compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            .max()
    }

    private func setVestMaximum(_ maximum: Double) {
        let halfKiloSteps = Int((maximum * 2).rounded())
        vestWeightsText = (1...halfKiloSteps)
            .map { weightLabel(Double($0) / 2) }
            .joined(separator: " ")
        editedCategories.insert("weighted_vest")
    }

    private var adjustableObjects: some View {
        let binding = draftBinding(\.adjustable, fallback: AdjustableEquipmentDraft(), category: "adjustable_dumbbell")
        return equipmentCard("Haltères réglables", asset: "gear-db-transparent") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Poids d’une poignée nue en kg").font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("kg", text: binding.handleWeightText).keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Poids d’une poignée nue en kg")
            }
            Picker("Poignées disponibles", selection: binding.handleCount) {
                Text("Une poignée").tag(1)
                Text("Deux poignées identiques").tag(2)
            }
            .pickerStyle(.segmented)
            Text("Quels disques as-tu ?").font(.headline)
            plateChoices
            Toggle("Le montage tient correctement sur mes poignées", isOn: binding.compatibleSetupConfirmed)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var plateChoices: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85), spacing: 8)], spacing: 8) {
                ForEach(AdjustableEquipmentDraft.plateGrams, id: \.self) { grams in
                    Button {
                        let value = plateCount(grams)
                        value.wrappedValue = value.wrappedValue > 0 ? 0 : 1
                    } label: {
                        Text("\((Double(grams) / 1_000).formatted()) kg")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(plateCount(grams).wrappedValue > 0 ? LBSBrand.orange.opacity(0.2) : LBSBrand.cardBackground,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LBSBrand.border))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(plateCount(grams).wrappedValue > 0 ? [.isSelected] : [])
                }
            }
            ForEach(AdjustableEquipmentDraft.plateGrams.filter { plateCount($0).wrappedValue > 0 }, id: \.self) { grams in
                Stepper(value: plateCount(grams), in: 1...40) {
                    VStack(alignment: .leading) {
                        Text("\((Double(grams) / 1_000).formatted()) kg")
                        Text("\(plateCount(grams).wrappedValue) disques").font(.subheadline)
                    }
                }
                .accessibilityLabel(Text("\((Double(grams) / 1_000).formatted()) kg"))
                .accessibilityValue(Text("\(plateCount(grams).wrappedValue) disques"))
            }
        }
    }

    private func plateCount(_ grams: Int) -> Binding<Int> {
        Binding(get: { equipmentDraft.adjustable?.plates.first { $0.grams == grams }?.count ?? 0 }, set: { count in
            equipmentDraft.adjustable?.plates.removeAll { $0.grams == grams }
            if count > 0 { equipmentDraft.adjustable?.plates.append(EquipmentPlateCount(grams: grams, count: count)) }
            equipmentDraft.adjustable?.compatibleSetupConfirmed = false
            editedCategories.insert("adjustable_dumbbell")
        })
    }

    private var bandObjects: some View {
        let bands = draftBinding(\.bands, fallback: [EquipmentBandObject](), category: "resistance_band")
        return Section {
            ForEach(bands) { band in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Couleur ou nom", text: band.name)
                    Picker("Résistance déclarée", selection: band.resistance) {
                        ForEach(EquipmentBandResistance.allCases) { resistance in
                            Text(resistance.title).tag(resistance)
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        withAnimation {
                            bands.wrappedValue.removeAll { $0.id == band.wrappedValue.id }
                        }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            Button("Ajouter un élastique") {
                equipmentDraft.bands?.append(EquipmentBandObject())
                editedCategories.insert("resistance_band")
            }
            .frame(minHeight: 44)
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 10, trailing: 24))
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
        } header: {
            equipmentHeader("Élastiques longs", asset: "gear-bands-transparent")
        }
    }

    private func save() {
        do {
            var savingDraft = equipmentDraft
            savingDraft.freezeBandIdentities()
            let inventory = try makeInventory(using: savingDraft)
            let draftData = try JSONEncoder().encode(savingDraft)
            let supportProfile = UserSupportProfile(
                floorAllowed: true,
                stableSeatOrBench: true,
                solidWall: true,
                overheadClearance: true,
                travelSpace: true,
                bandFootSetupAllowed: bandsEnabled,
                pullupClearance: pullupBarEnabled,
                pullupTopStartSupport: false,
                bandOnPullupBarAllowed: false,
                dipBarsRowSafe: false,
                floorGripSafe: dipBarsEnabled,
                stepUpApprovedSupport: false,
                hipThrustBenchApproved: false
            )
            if let existing {
                let previous = (existing.inventoryData, existing.supportProfileData, existing.updatedAt, existing.equipmentDraftData)
                if !savedDraftUnreadable || !editedCategories.isEmpty {
                    existing.equipmentDraftData = draftData
                }
                existing.inventory = inventory
                existing.supportProfile = supportProfile
                do { try modelContext.save() }
                catch {
                    existing.inventoryData = previous.0
                    existing.supportProfileData = previous.1
                    existing.updatedAt = previous.2
                    existing.equipmentDraftData = previous.3
                    throw error
                }
            } else {
                let record = try UserSetupRecord(
                    inventory: inventory,
                    supportProfile: supportProfile
                )
                record.equipmentDraftData = draftData
                modelContext.insert(record)
                do { try modelContext.save() }
                catch {
                    modelContext.delete(record)
                    throw error
                }
            }
            equipmentDraft = savingDraft
            errorMessage = nil
            onSaved?()
            if existing != nil { dismiss() }
        } catch let error as EquipmentDeclarationError {
            errorMessage = error.localizedDescription
        } catch let error as InventoryInputError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = String(localized: "L’enregistrement a échoué. Tes saisies sont conservées pour réessayer.")
        }
    }

    private func makeInventory(using savingDraft: EquipmentConfigurationDraft) throws -> [EquipmentItem] {
        let selection: [(String, Bool)] = [
            ("bodyweight", true), ("fixed_dumbbell", fixedDumbbellsEnabled),
            ("adjustable_dumbbell", adjustableDumbbellsEnabled), ("kettlebell", kettlebellsEnabled),
            ("resistance_band", bandsEnabled), ("weighted_vest", weightedVestEnabled),
            ("pullup_bar", pullupBarEnabled), ("dip_bars", dipBarsEnabled), ("rower", rowerEnabled)
        ]
        let selected = Set(selection.filter { $0.1 }.map { $0.0 })
        let original = existing?.inventory ?? []
        var preserved = Set(original.map(\.category)).intersection(selected).subtracting(editedCategories)
        let savedVestWeights = original.filter { $0.category == "weighted_vest" }
            .flatMap { $0.perUnitWeightsKg ?? [] }
        if savedVestWeights.count == 1, Self.isHalfKiloVestMaximum(savedVestWeights[0]) {
            preserved.remove("weighted_vest")
        }
        var inventory = [
            EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
        ]

        if fixedDumbbellsEnabled && !preserved.contains("fixed_dumbbell") {
            guard let projected = try savingDraft.projectedFamily("fixed_dumbbell") else {
                throw EquipmentDeclarationError.incomplete
            }
            inventory += projected
        }
        if adjustableDumbbellsEnabled && !preserved.contains("adjustable_dumbbell") {
            if let projected = try savingDraft.projectedFamily("adjustable_dumbbell") {
                inventory += projected
            } else {
            inventory += try EquipmentInventoryInput.dumbbells(category: "adjustable_dumbbell", single: adjustableWeightsText, pair: adjustablePairWeightsText)
                    }
        }

        if kettlebellsEnabled && !preserved.contains("kettlebell") {
            guard let projected = try savingDraft.projectedFamily("kettlebell") else {
                throw EquipmentDeclarationError.incomplete
            }
            inventory += projected
        }

        if bandsEnabled && !preserved.contains("resistance_band") {
            guard let projected = try savingDraft.projectedFamily("resistance_band") else {
                throw EquipmentDeclarationError.incomplete
            }
            inventory += projected
        }

        if weightedVestEnabled && !preserved.contains("weighted_vest") {
            let weights = try EquipmentInventoryInput.weights(vestWeightsText)
            guard !weights.isEmpty else { throw InventoryInputError.missingVestWeights }
            inventory.append(
                EquipmentItem(
                    category: "weighted_vest",
                    units: 1,
                    perUnitWeightsKg: weights,
                    supportedConfigurations: ["vest", "central"]
                )
            )
        }

        if pullupBarEnabled {
            inventory.append(EquipmentItem(category: "pullup_bar", units: 1, supportedConfigurations: ["bodyweight"]))
        }
        if dipBarsEnabled {
            inventory.append(EquipmentItem(category: "dip_bars", units: 1, supportedConfigurations: ["bodyweight"]))
        }
        if rowerEnabled {
            inventory.append(EquipmentItem(category: "rower", units: 1, supportedConfigurations: ["rower"]))
        }
        let known: Set<String> = ["bodyweight", "fixed_dumbbell", "adjustable_dumbbell", "kettlebell", "resistance_band", "weighted_vest", "pullup_bar", "dip_bars", "rower"]
        return inventory.filter { !preserved.contains($0.category) }
            + original.filter { preserved.contains($0.category) || (!noEquipment && !known.contains($0.category)) }
    }

    private var familySelection: some View {
        let isLandscape = verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        ScrollView {
            VStack(alignment: .leading, spacing: isLandscape ? 14 : 24) {
                LBSWordmark()
                Text("De quoi disposes-tu chez toi ?")
                    .font(.archivoBlack(isLandscape ? 27 : 32, relativeTo: .title))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Choisis ton matériel. Le poids du corps est toujours inclus.")
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 140), spacing: 12)],
                    spacing: 12
                ) {
                    family("Haltères fixes", asset: "gear-fixed-db-transparent", selected: $fixedDumbbellsEnabled)
                    family("Haltères réglables", asset: "gear-db-transparent", selected: $adjustableDumbbellsEnabled)
                    family("Kettlebells", asset: "gear-kb-transparent", selected: $kettlebellsEnabled)
                    family("Élastiques longs", asset: "gear-bands-transparent", selected: $bandsEnabled)
                    family("Gilet lesté", asset: "gear-vest-transparent", selected: $weightedVestEnabled)
                    family("Barre de traction", asset: "gear-pullup-transparent", selected: $pullupBarEnabled)
                    family("Barres de dips stables", asset: "gear-dips-transparent", selected: $dipBarsEnabled)
                    family("Rameur", asset: "gear-rower-transparent", selected: $rowerEnabled)
                }
                Button {
                    noEquipment.toggle()
                    if noEquipment {
                        fixedDumbbellsEnabled = false; adjustableDumbbellsEnabled = false
                        kettlebellsEnabled = false; bandsEnabled = false; weightedVestEnabled = false
                        pullupBarEnabled = false; dipBarsEnabled = false; rowerEnabled = false
                    }
                } label: {
                    Label("Sans matériel", systemImage: noEquipment ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(noEquipment ? LBSBrand.ink : LBSBrand.border, lineWidth: noEquipment ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(noEquipment ? [.isSelected] : [])
            }
            .padding(.horizontal, isLandscape ? 32 : 24)
            .padding(.vertical, isLandscape ? 14 : 24)
        }
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer(minLength: 0)
                Button(needsLoadDetails ? "Continuer" : (existing == nil ? "Commencer" : "Mettre à jour")) { advance() }
                    .font(.headline)
                    .frame(maxWidth: isLandscape ? 360 : .infinity, minHeight: 54)
                    .buttonStyle(.plain)
                    .foregroundStyle(LBSBrand.cream)
                    .background(LBSBrand.ink, in: RoundedRectangle(cornerRadius: 16))
                    .disabled(!hasSelection)
                    .opacity(hasSelection ? 1 : 0.45)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, isLandscape ? 32 : 24)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hasSelection: Bool {
        noEquipment || fixedDumbbellsEnabled || adjustableDumbbellsEnabled || kettlebellsEnabled
            || bandsEnabled || weightedVestEnabled || pullupBarEnabled || dipBarsEnabled || rowerEnabled
    }

    private func family(_ title: LocalizedStringKey, asset: String, selected: Binding<Bool>) -> some View {
        let isLandscape = verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        Button {
            selected.wrappedValue.toggle()
            if selected.wrappedValue { noEquipment = false }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(asset).resizable().scaledToFit().frame(height: isLandscape ? 72 : 100).accessibilityHidden(true)
                HStack(alignment: .top) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2, reservesSpace: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.wrappedValue ? LBSBrand.orange : LBSBrand.secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected.wrappedValue ? LBSBrand.orange.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected.wrappedValue ? LBSBrand.ink : LBSBrand.border, lineWidth: selected.wrappedValue ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected.wrappedValue ? [.isSelected] : [])
    }
}

enum EquipmentInventoryInput {
    static func weights(_ text: String) throws -> [Double] {
        let tokens = text.split { $0.isWhitespace || $0 == ";" }
        let values = try tokens.map { token -> Double in
            guard let value = Double(token.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else {
                throw InventoryInputError.invalidFixedWeight
            }
            return value
        }
        return Array(Set(values)).sorted()
    }

    static func dumbbells(category: String, single: String, pair: String) throws -> [EquipmentItem] {
        let singles = try weights(single)
        let pairs = try weights(pair)
        guard !singles.isEmpty || !pairs.isEmpty else { throw InventoryInputError.missingAdjustableWeights }
        return Array(Set(singles + pairs)).sorted().map { weight in
            let isPair = pairs.contains(weight)
            return EquipmentItem(
                category: category, units: isPair ? 2 : 1,
                weightKg: category == "fixed_dumbbell" ? weight : nil,
                perUnitWeightsKg: category == "adjustable_dumbbell" ? [weight] : nil,
                supportedConfigurations: ["single", "central", "unilateral"] + (isPair ? ["pair"] : [])
            )
        }
    }
}

private enum InventoryInputError: LocalizedError {
    case invalidFixedWeight
    case missingAdjustableWeights
    case missingVestWeights

    var errorDescription: String? {
        switch self {
        case .invalidFixedWeight: String(localized: "Indique des poids valides, supérieurs à zéro.")
        case .missingAdjustableWeights: String(localized: "Indique au moins un poids réellement utilisable pour tes haltères.")
        case .missingVestWeights: String(localized: "Indique au moins une masse réellement disponible pour le gilet.")
        }
    }
}
