import CadenceEngine
import SwiftUI

/// A truthful local limit, not a full programme or a compulsory preparation step.
struct SessionAdaptationNotice: View {
    let context: ActiveWorkoutV2Context
    let onAdjust: (String) -> Void
    private var configuration: V2EngineConfiguration {
        context.personalization?.releaseConfiguration == true ? .releaseV2 : .productPreview
    }
    private var missing: [String] { context.personalization?.coverage.missingPrimary ?? [] }
    private var names: String {
        missing.map { muscle in
            switch muscle {
            case "back": String(localized: "le dos")
            case "hamstrings": String(localized: "l’arrière des cuisses")
            case "chest": String(localized: "les pectoraux")
            case "quadriceps": String(localized: "l’avant des cuisses")
            case "glutes": String(localized: "les fessiers")
            default: muscle
            }
        }.joined(separator: ", ")
    }
    private var actionableID: String? {
        guard let personal = context.personalization else { return nil }
        if let check = personal.checks.first(where: { $0.requiredBeforeMovement }) { return check.exerciseId }
        return context.plan.first { row in
            (personal.options[row.exerciseId] ?? []).contains { option in
                !(Set(configuration.catalog[option.exerciseId]?.primaryContributions ?? []).intersection(missing)).isEmpty
            }
        }?.exerciseId
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !missing.isEmpty {
                Text("Cette séance ne couvre pas complètement \(names).")
                    .font(.footnote).foregroundStyle(LBSBrand.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let id = actionableID {
                    Button("Voir les mouvements possibles") { onAdjust(id) }
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
            if let ids = context.personalization?.incompatibleChoices, !ids.isEmpty {
                Text("Réglage remplacé car il n’est plus compatible ici : \(ids.map(PresentationCopy.movementTitle).joined(separator: ", ")).")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RepetitionReviewNotice: View {
    let exerciseID: String
    let repetitions: Int
    let onAnswer: (V2DirectChoice, V2ChoiceScope) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PresentationCopy.movementTitle(exerciseID)).font(.headline)
            Text("Sur les séances précédentes, tu as fait moins de répétitions que prévu.")
                .font(.footnote).foregroundStyle(LBSBrand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(repetitions) répétitions : c’était ton choix ou c’était déjà difficile ?")
                .fixedSize(horizontal: false, vertical: true)
            Button("Je préfère rester à \(repetitions)") { onAnswer(.holdRepetitions(repetitions), .usual) }
                .buttonStyle(.bordered).frame(minHeight: 44)
            Button("C’était déjà difficile") { onAnswer(.difficultyTooHigh, .today) }
                .buttonStyle(.bordered).frame(minHeight: 44)
            Button("Plus tard") { onAnswer(.deferRepetitionReview, .today) }
                .frame(minHeight: 44)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
