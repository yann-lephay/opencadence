import SwiftUI
import SwiftData

struct SessionSharingView: View {
    let hasPaidAccess: Bool
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var sharing: SessionSharing = .shared
    @Query private var records: [CompletedWorkoutRecord]

    private var paid: Bool { hasPaidAccess }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Aider à améliorer les séances")
                    .font(.archivoBlack(28, relativeTo: .title))
                Text("Avec ton accord, tes prochaines séances sont envoyées à l’équipe La Bonne Séance pour comprendre les recommandations et améliorer le moteur.")
                Text("Ce qui est partagé").font(.headline)
                Text("La date (sans l’heure), les mouvements proposés, les séries, répétitions, charges et repos prévus ou réalisés, ainsi que la version du moteur. Les séances interrompues sont aussi incluses. Aucun historique antérieur à ton accord n’est envoyé.")
                Text("Si tu réponds au retour facultatif du bilan, ton appréciation et la précision choisie (facilité, difficulté, répétition ou compréhension) sont aussi partagées.")
                Text("Un pseudonyme, pas ton identité").font(.headline)
                Text("Un identifiant aléatoire relie tes séances. Nous n’envoyons ni nom, ni e-mail, ni données de douleur, ni texte libre. Un historique reste personnel : ce partage n’est pas totalement anonyme.")
                Text("Les comptes rendus de séance sont conservés 90 jours sur notre serveur privé. Le partage ne change ni ton accès ni l’adaptation locale de tes séances et n’autorise pas une modification individuelle à distance.")
                if sharing.enrollment?.deleting == true {
                    Text("Partage arrêté · suppression en attente").font(.headline)
                    Text("Aucune nouvelle séance n’est envoyée. La suppression des données déjà reçues sera réessayée quand l’app sera ouverte et connectée.")
                    Button("Réessayer la suppression") { synchronize() }.frame(minHeight: 44)
                } else if sharing.enrollment != nil && !sharing.active {
                    Text("Le partage a évolué. Les envois sont suspendus jusqu’à un nouvel accord.")
                    Button("Supprimer l’ancien partage") { sharing.stop(); synchronize() }.frame(minHeight: 44)
                } else if sharing.active {
                    Text("Partage activé").font(.headline)
                    Button("Envoyer les séances en attente") { synchronize() }.frame(minHeight: 44)
                    if !paid { Text("Les envois sont suspendus tant que l’accès payant n’est pas vérifié.") }
                    Button("Arrêter le partage et supprimer mes données", role: .destructive) {
                        sharing.stop(); synchronize()
                    }.frame(minHeight: 44)
                    Text("Cela conserve ton historique sur cet iPhone.").font(.footnote)
                } else if !sharing.available {
                    Text("Le partage n’est pas disponible dans cette version. Aucune donnée n’est envoyée.")
                } else if paid {
                    Button("J’accepte de partager mes prochaines séances") {
                        sharing.accept(paid: paid); synchronize()
                    }.buttonStyle(.borderedProminent).tint(LBSBrand.orange).foregroundStyle(LBSBrand.ink)
                    Text("Facultatif. Tu peux refuser en quittant cet écran, puis changer d’avis dans les paramètres.").font(.footnote)
                }
                if let message = sharing.message { Text(message).font(.footnote).accessibilityIdentifier("sharing-status") }
                Link("Confidentialité", destination: URL(string: "https://labonneseance.com/confidentialite")!)
            }.padding(24).frame(maxWidth: 640, alignment: .leading)
        }
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .foregroundStyle(LBSBrand.brandText)
        .navigationTitle("Partage des séances")
    }
    private func synchronize() {
        Task { await sharing.sync(records: records, context: modelContext, paid: paid) }
    }
}

#if DEBUG
/// Isolated visual fixture: no user store, keychain, purchase or production endpoint.
struct SessionSharingProofView: View {
    @StateObject private var sharing = SessionSharing(endpoint: URL(string: "https://collector.invalid"),
        load: { nil }, persist: { _ in })
    var body: some View {
        NavigationStack { SessionSharingView(hasPaidAccess: true, sharing: sharing) }
            .modelContainer(for: [UserSetupRecord.self, ActiveWorkoutRecord.self, CompletedWorkoutRecord.self], inMemory: true)
    }
}
#endif

#if DEBUG
struct SessionReviewProofView: View {
    @State private var review: SessionReview?
    @State private var skipped = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Séance enregistrable").font(.archivoBlack(28, relativeTo: .title))
                    if !skipped { SessionReviewCard(sessionReview: $review, reviewSkipped: $skipped) }
                    Button("Retour à l’accueil") { skipped = true }.buttonStyle(.borderedProminent).tint(LBSBrand.ink)
                }.padding(24)
            }.background(LBSBrand.screenBackground).foregroundStyle(LBSBrand.brandText)
        }
    }
}
#endif
