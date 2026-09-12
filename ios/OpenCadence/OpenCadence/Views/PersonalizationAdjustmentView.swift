import CadenceEngine
import SwiftUI

struct PersonalizationAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String
    let options: [V2MovementOption]
    let inventory: [V2InventoryItem]
    let currentSets: Int
    var releaseConfiguration = false
    var hasRepetitionPreference = false
    let onApply: (String, V2DirectChoice?, V2ChoiceScope, V2MovementKnowledge?) throws -> Void
    @State private var selectedID: String?
    @State private var scope: V2ChoiceScope = .today
    @State private var repetitions = 5
    @State private var chosenLoad: V2Load?
    @State private var error = false

    private var selected: String { selectedID ?? exerciseID }
    private var configuration: V2EngineConfiguration { releaseConfiguration ? .releaseV2 : .productPreview }
    private var exercise: V2ExerciseDefinition? { configuration.catalog[selected] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Choisis le mouvement qui te convient.")
                    ForEach(Array(Set([exerciseID] + options.map(\.exerciseId))).sorted(), id: \.self) { id in
                        Button {
                            selectedID = id
                            chosenLoad = nil
                        } label: {
                            HStack {
                                MovementDemonstrationView(exerciseID: id, showsPlaybackControls: false)
                                    .frame(width: 100, height: 85).clipped()
                                Text(PresentationCopy.movementTitle(id))
                                Spacer()
                                if selected == id { Image(systemName: "checkmark.circle.fill") }
                            }
                        }.buttonStyle(.plain).frame(minHeight: 44)
                    }
                    Picker("Appliquer", selection: $scope) {
                        Text("Aujourd’hui").tag(V2ChoiceScope.today)
                        Text("Habituellement").tag(V2ChoiceScope.usual)
                    }.pickerStyle(.segmented)
                    if let exercise, exercise.initialCapacityRequired == true {
                        Text("Combien en fais-tu dans une série confortable, sans aller au maximum ?")
                        Stepper(value: $repetitions, in: 0...exercise.repRange.max) {
                            Text("\(repetitions) répétitions")
                        }
                        let loads = CadenceEngine.personalizationLoads(exerciseId: selected, inventory: inventory, configuration: configuration)
                        if exercise.loadMode != .bodyweight {
                            ForEach(Array(loads.enumerated()), id: \.offset) { _, load in
                                Button(load.optionID ?? load.kg.map { "\($0) kg" } ?? "—") { chosenLoad = load }
                                    .buttonStyle(.bordered)
                                    .tint(chosenLoad == load ? LBSBrand.orange : .secondary)
                            }
                        }
                        Button("Utiliser ce repère") {
                            let declaration = V2MovementKnowledge(exerciseId: selected, progressionContext: exercise.progressionContext,
                                familiar: true, declaredReps: repetitions, declaredLoad: chosenLoad,
                                at: .now, catalogVersion: configuration.catalogVersion)
                            apply(selected == exerciseID ? nil : .variant(selected), declaration: declaration)
                        }.disabled(repetitions < exercise.repRange.min || (exercise.loadMode != .bodyweight && chosenLoad == nil))
                        if repetitions < exercise.repRange.min {
                            Text("Choisis une autre variante pour commencer confortablement.").font(.footnote)
                        }
                    } else {
                        Button("Choisir ce mouvement pour aujourd’hui") { apply(.variant(selected)) }
                        if let exercise {
                            Button("Je connais déjà ce mouvement") {
                                apply(selected == exerciseID ? nil : .variant(selected), declaration: .init(
                                    exerciseId: selected, progressionContext: exercise.progressionContext,
                                    familiar: true, at: .now, catalogVersion: configuration.catalogVersion))
                            }
                        }
                    }
                    if selected == exerciseID && hasRepetitionPreference {
                        Button("Laisser les répétitions évoluer") {
                            scope = .usual
                            apply(.resumeRepetitionProgression)
                        }
                    }
                    if selected == exerciseID {
                        Text("Nombre de séries").font(.headline)
                        HStack {
                            ForEach([2, 3], id: \.self) { count in
                                Button { apply(.sets(count)) } label: {
                                    Text("\(count) séries")
                                }.buttonStyle(.bordered).tint(currentSets == count ? LBSBrand.orange : .secondary)
                            }
                        }
                    }
                    Button("Ce mouvement est impossible ici") { apply(.exclude) }
                    if error {
                        Text("Ce réglage n’a pas pu être appliqué. La séance est conservée ; choisis un autre repère ou réessaie.")
                            .foregroundStyle(.red)
                    }
                }.padding()
            }
            .navigationTitle("Adapter le mouvement")
        }
    }

    private func apply(_ choice: V2DirectChoice?, declaration: V2MovementKnowledge? = nil) {
        do { try onApply(exerciseID, choice, scope, declaration); dismiss() }
        catch { self.error = true }
    }
}
