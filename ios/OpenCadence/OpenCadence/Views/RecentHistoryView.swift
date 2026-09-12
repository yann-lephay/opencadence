import SwiftUI

struct RecentHistoryView: View {
    let records: [CompletedWorkoutRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dernières séances")
                .font(.archivoBlack(28, relativeTo: .title2))
                .foregroundStyle(LBSBrand.brandText)
            ForEach(records, id: \.sessionID) { record in
                if let payload = record.payload {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: payload.snapshot.endedEarly ? "heart" : "checkmark")
                            .font(.headline)
                            .foregroundStyle(LBSBrand.ink)
                            .frame(width: 32, height: 32)
                            .background(LBSBrand.orange, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.endedAt.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.semibold)
                            Text(summary(payload))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if payload.snapshot.endedEarly {
                                Text("Terminée plus tôt, sans pénalité")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(LBSBrand.cardBackground, in: LBSChamferedRectangle(cut: 12))
                    .overlay {
                        LBSChamferedRectangle(cut: 12)
                            .stroke(LBSBrand.border, lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("L’historique montre les faits enregistrés. Une tendance ne sera affichée qu’avec plusieurs séances comparables.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ payload: CompletedWorkoutPayload) -> String {
        let sets = payload.snapshot.recordedSets.count
        let exercises = Set(payload.snapshot.recordedSets.map(\.exerciseKey)).count
        let setText = sets == 1
            ? String(localized: "1 série")
            : String.localizedStringWithFormat(String(localized: "%lld séries"), sets)
        let exerciseText = exercises == 1
            ? String(localized: "1 mouvement")
            : String.localizedStringWithFormat(String(localized: "%lld mouvements"), exercises)
        return String.localizedStringWithFormat(String(localized: "%@ · %@"), setText, exerciseText)
    }
}
