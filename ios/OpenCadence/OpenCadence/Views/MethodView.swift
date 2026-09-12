import SwiftUI

struct MethodView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LBSWordmark()
                Text("La recherche.\nDes choix concrets.")
                    .font(.archivoBlack(42, relativeTo: .largeTitle))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
                Text("Nos séances s’appuient sur les recherches en renforcement musculaire. Voici ce qu’elles changent dans notre façon de te faire bouger.")
                Text("Trois questions. Nos raisons. Les sources.")
                    .font(.subheadline.weight(.semibold))
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ce qu’on sait").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Le renforcement musculaire est recommandé aux femmes comme aux hommes. Cela ne veut pas dire que leurs capacités, leurs besoins ou toutes leurs réponses à l’entraînement sont identiques.")
                        Text("Notre choix dans l’app").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Nous partons du matériel, puis du travail que tu confirmes et de tes retours, plutôt que de déduire ton niveau d’une catégorie femme ou homme. C’est notre choix de personnalisation, pas une conclusion imposée par une étude.")
                        Text("À la première séance, ton niveau reste à découvrir. Tu peux modifier la charge ou t’arrêter.")
                        Link("Source · Recommandations de l’OMS", destination: URL(string: "https://www.who.int/europe/news-room/fact-sheets/item/physical-activity")!)
                    }
                    .padding(.top, 16)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pourquoi pas femme ou homme ?").font(.archivoBlack(22, relativeTo: .title2))
                        Text("Des principes communs, une difficulté individuelle.").font(.subheadline)
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ce qu’on sait").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Dans une étude de 8 semaines auprès de 18 personnes entraînées, garder 1 à 2 répétitions en réserve a produit une croissance des quadriceps similaire à l’échec, avec moins de fatigue aiguë.")
                        Text("Notre choix dans l’app").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Nous privilégions une progression prudente. Une série n’a pas besoin de finir dans l’épuisement pour compter ; le travail confirmé reste enregistré.")
                        Text("Un résultat sur ces exercices et cette population ne définit pas une intensité idéale pour tout le monde.")
                        Link("Étude · Refalo et al., 2024", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/38393985/")!)
                    }
                    .padding(.top, 16)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Faut-il finir chaque série à bout ?").font(.archivoBlack(22, relativeTo: .title2))
                        Text("L’échec n’est pas un passage obligé.").font(.subheadline)
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ce qu’on sait").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Chez 39 jeunes débutants suivis pendant 10 semaines, augmenter les répétitions ou la charge a permis des gains de force et de masse musculaire, sans différence détectée entre les deux approches.")
                        Text("Notre choix dans l’app").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Les répétitions et les charges réalisées servent de repères pour la suite. La proposition tient compte du matériel disponible et reste ajustable.")
                        Text("Tu n’as pas à commencer lourd. Selon le mouvement, tu peux utiliser ton poids du corps, des élastiques ou des poids. Le renforcement peut compléter les activités que tu aimes déjà.")
                        Link("Étude · Chaves et al., 2024", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/38286426/")!)
                    }
                    .padding(.top, 16)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plus de répétitions ou plus de poids ?").font(.archivoBlack(22, relativeTo: .title2))
                        Text("Il existe plusieurs façons de progresser.").font(.subheadline)
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("La recherche guide nos principes.").font(.headline)
                    Text("Elle ne valide pas à elle seule notre moteur. Ses règles d’adaptation et de reprise sont des choix produit dont l’efficacité reste à évaluer.")
                }
                .padding(20)
                .background(LBSBrand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                DisclosureGroup("Une situation particulière ?") {
                    Text("Grossesse, post-partum, rééducation ou douleur demandent une attention particulière. Ce parcours général n’est pas un programme dédié à ces situations. L’app ne mesure pas ta récupération et ne remplace pas un avis médical.")
                        .padding(.top, 12)
                }
                DisclosureGroup("Comment l’adaptation fonctionne") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Le moteur local utilise le matériel, l’historique confirmé, le temps écoulé et les retours renseignés. Une pause ne crée pas de dette : le travail réalisé reste conservé.")
                        Text("Les simulations vérifient la cohérence des règles ; elles ne prouvent pas leur efficacité chez chaque personne.")
                    }
                    .padding(.top, 12)
                }
                Text("Sources consultées le 7 septembre 2026.").font(.footnote)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .multilineTextAlignment(.leading)
        .font(.body)
        .foregroundStyle(LBSBrand.brandText)
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .tint(LBSBrand.controlTint)
        .navigationTitle(Text("Notre méthode"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
