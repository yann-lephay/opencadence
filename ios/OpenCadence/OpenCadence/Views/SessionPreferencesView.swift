import CadenceEngine
import SwiftUI

/// Optional, contextual settings. This is never presented automatically.
struct SessionPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    let setup: UserSetupRecord
    let snapshot: ActiveWorkoutSnapshot
    let onApply: (String?, Bool, V2SessionMode, Set<String>, Bool) throws -> Void
    @State private var practice = "unknown"
    @State private var returning = false
    @State private var mode: V2SessionMode = .normal
    @State private var unavailableEquipment: Set<String> = []
    @State private var familiar = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Ta pratique du renforcement", selection: $practice) {
                        Text("Sans repère pour le moment").tag("unknown")
                        Text("Je découvre").tag("discovering")
                        Text("De temps en temps").tag("occasional")
                        Text("Régulièrement").tag("regular")
                    }.pickerStyle(.inline)
                    if let movement = snapshot.currentMovement {
                        Toggle(isOn: $familiar) {
                            Text("Je connais ce mouvement : \(PresentationCopy.movementTitle(movement.exerciseKey))")
                        }
                    }
                } header: { Text("Tes repères") }
                Section {
                    Toggle("Je reprends après une pause", isOn: $returning)
                    Picker("Intention", selection: $mode) {
                        Text("Normale").tag(V2SessionMode.normal)
                        Text("Allégée").tag(V2SessionMode.light)
                        Text("Retrouver mes repères").tag(V2SessionMode.recalibration)
                    }
                    DisclosureGroup("Matériel disponible aujourd’hui") {
                        ForEach(Array(Set(setup.inventory.map(\.category))).filter { $0 != "bodyweight" }.sorted(), id: \.self) { category in
                            Toggle(PresentationCopy.equipmentSummary(setup.inventory.filter { $0.category == category }),
                                isOn: Binding(get: { !unavailableEquipment.contains(category) }, set: {
                                    if $0 { unavailableEquipment.remove(category) } else { unavailableEquipment.insert(category) }
                                }))
                        }
                    }
                } header: { Text("Pour cette séance") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Adapter la séance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        do {
                            try onApply(practice == "unknown" ? nil : practice, returning, mode, unavailableEquipment, familiar)
                            dismiss()
                        } catch {
                            errorMessage = String(localized: "Ce réglage n’a pas pu être appliqué. La séance est conservée ; choisis un autre repère ou réessaie.")
                        }
                    }
                }
            }
            .onAppear {
                practice = setup.strengthPracticeRaw ?? "unknown"
                returning = snapshot.v2Context?.personalization?.person.returning ?? false
                mode = snapshot.v2Context?.mode ?? .normal
                let available = Set(snapshot.v2Context?.inventory.map(\.category) ?? [])
                unavailableEquipment = Set(setup.inventory.map(\.category)).subtracting(available)
                familiar = snapshot.v2Context?.personalization?.person.knowledge.first(where: { $0.exerciseId == snapshot.currentMovement?.exerciseKey })?.familiar ?? false
            }
        }.tint(LBSBrand.controlTint)
    }
}
