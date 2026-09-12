import SwiftUI

struct MovementAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss

    let movementKeys: [String]
    let initiallyExcluded: Set<String>
    let initiallyPersistent: Set<String>
    let onApply: (Set<String>, Set<String>) -> Void

    @State private var selected: Set<String>
    @State private var persistent: Set<String>

    init(
        movementKeys: [String],
        initiallyExcluded: Set<String>,
        initiallyPersistent: Set<String>,
        onApply: @escaping (Set<String>, Set<String>) -> Void
    ) {
        self.movementKeys = movementKeys
        self.initiallyExcluded = initiallyExcluded
        self.initiallyPersistent = initiallyPersistent
        self.onApply = onApply
        _selected = State(initialValue: initiallyExcluded)
        _persistent = State(initialValue: initiallyPersistent)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Écarter pour aujourd’hui")
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choisis les mouvements que tu ne souhaites pas faire dans cette séance. Le moteur cherchera une autre combinaison avec ton matériel.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }


            Section {
                ForEach(movementKeys, id: \.self) { key in
                    Toggle(
                        PresentationCopy.movementTitle(key),
                        isOn: persistentBinding(for: key)
                    )
                }
            } header: {
                Text("Ne plus proposer cette configuration")
            } footer: {
                Text("Ce choix reste actif jusqu’à ce que tu le modifies ici. Il concerne cette configuration précise, pas toutes les variantes du mouvement.")
            }

            Section {
                ForEach(movementKeys, id: \.self) { key in
                    Button {
                        toggle(key)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected.contains(key)
                                ? "checkmark.circle.fill"
                                : "circle")
                                .foregroundStyle(selected.contains(key) ? .teal : .secondary)
                                .font(.title3)
                            Text(PresentationCopy.movementTitle(key))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected.contains(key) ? .isSelected : [])
                }
            } header: {
                Text("Mouvements prévus")
            } footer: {
                Text("Ces choix concernent seulement la séance en préparation. Tu peux réintégrer un mouvement avant de commencer.")
            }

            Section {
                Text("Si tu ressens une douleur, un mal-être ou une fatigue excessive pendant l’exercice, arrête l’exercice en cours. Cette adaptation ne remplace pas un avis médical.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Recalculer la séance") {
                    onApply(selected, persistent)
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(selected == initiallyExcluded && persistent == initiallyPersistent)
            }
        }
        .navigationTitle("Adapter les mouvements")
        .navigationBarTitleDisplayMode(.inline)
    }


    private func persistentBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { persistent.contains(key) },
            set: { enabled in
                if enabled {
                    persistent.insert(key)
                    selected.remove(key)
                } else {
                    persistent.remove(key)
                }
            }
        )
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }
}
