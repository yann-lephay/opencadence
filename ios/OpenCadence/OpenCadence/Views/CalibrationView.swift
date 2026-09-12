import SwiftData
import SwiftUI

struct CalibrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let setup: UserSetupRecord

    @State private var upperChoice: CalibrationChoice?
    @State private var lowerChoice: CalibrationChoice?
    @State private var errorMessage: String?

    init(setup: UserSetupRecord) {
        self.setup = setup
        _upperChoice = State(initialValue: Self.initialChoice(
            rawValue: setup.upperCalibration,
            isEditing: setup.calibrationIsExplicit
        ))
        _lowerChoice = State(initialValue: Self.initialChoice(
            rawValue: setup.lowerCalibration,
            isEditing: setup.calibrationIsExplicit
        ))
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    LBSWordmark()
                    Text("Deux repères, pas un niveau")
                        .font(.archivoBlack(32, relativeTo: .title))
                        .foregroundStyle(LBSBrand.brandText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Le haut et le bas du corps peuvent démarrer différemment. Choisis ce qui te semble le plus naturel aujourd’hui ; tu pourras modifier chaque repère séparément.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            calibrationSection(
                title: "Haut du corps",
                detail: "Tirages et poussées",
                selection: $upperChoice
            )

            calibrationSection(
                title: "Bas du corps",
                detail: "Jambes et mouvements de hanches",
                selection: $lowerChoice
            )

            Section {
                Text("La Bonne Séance n’en déduit aucun niveau sportif global. Le moteur utilise ces repères seulement pour choisir une variante compatible lors des prochaines séances.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Enregistrer mes repères") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(upperChoice == nil || lowerChoice == nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(LBSBrand.screenBackground)
        .navigationTitle("Repères de départ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func calibrationSection(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        selection: Binding<CalibrationChoice?>
    ) -> some View {
        Section {
            ForEach(CalibrationChoice.allCases) { choice in
                Button {
                    selection.wrappedValue = choice
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selection.wrappedValue == choice
                            ? "checkmark.circle.fill"
                            : "circle")
                            .foregroundStyle(selection.wrappedValue == choice ? .teal : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(choice.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(choice.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.wrappedValue == choice ? .isSelected : [])
            }
        } header: {
            Text(title)
        } footer: {
            Text(detail)
        }
    }

    private func save() {
        guard let upperChoice, let lowerChoice else { return }
        setup.upperCalibration = upperChoice.rawValue
        setup.lowerCalibration = lowerChoice.rawValue
        setup.calibrationCompletedAt = .now
        setup.updatedAt = .now
        do {
            try modelContext.save()
            errorMessage = nil
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Les repères n’ont pas été enregistrés. Tes choix restent affichés pour réessayer.")
        }
    }

    static func initialChoice(
        rawValue: String?,
        isEditing: Bool
    ) -> CalibrationChoice? {
        guard isEditing, let rawValue else { return nil }
        return CalibrationChoice(rawValue: rawValue)
    }
}

enum CalibrationChoice: String, CaseIterable, Identifiable {
    case foundation
    case established

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .foundation: "Reprendre progressivement"
        case .established: "Mouvements déjà familiers"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .foundation:
            "Je préfère une variante plus simple à prendre en main, puis ajuster avec mes séries réelles."
        case .established:
            "Je pratique déjà régulièrement ces mouvements et leur exécution m’est familière."
        }
    }
}
