# Achat à vie — vérification locale du 7 septembre 2026

Modèle confirmé par Yann : une première séance complète offerte, puis 59,99 €
en achat unique pour un accès à vie, sans abonnement (référence zone euro).

## Modification

Un seul produit StoreKit non consommable : `fr.labonneseance.lifetime`.
L’app affiche `Product.displayPrice`, filtre le type du produit, vérifie les
transactions et propose la restauration avec le même compte Apple.
Écran d’achat, réglages, traductions FR/EN/ES/DE, descriptions App Store et
documentation de lancement alignés. Aucun changement au moteur des séances.
Les noms internes SubscriptionStore/hasActiveSubscription sont conservés pour
éviter un renommage transversal sans effet pour l’utilisateur.

## Preuves et limites

- Compilation iOS simulateur : PASS.
- 57 tests Swift de logique : PASS, dont le produit non consommable attendu,
  la première séance offerte et la reprise d’une séance active.
- Test intégré achat/restauration/remboursement : NON VALIDÉ à ce stade.
  Le produit était absent dans le test. iOS 26.5 rapporte également
  `SKInternalErrorDomain Code=3` au chargement de la configuration de test.
  La dernière relance avec identifiant interne numérique a été interrompue
  après compilation, sans démarrage des tests. Ne pas assimiler les tests
  logiques à la validation d’un paiement.
- TypeScript : PASS. Build Next.js annexe : bloqué par l’environnement
  (`binding to a port: Operation not permitted`), y compris la relance autorisée.
- Revue indépendante de simplicité : correction de la dernière référence
  à un abonnement dans le contrat de release appliquée.
- Rendu de l’écran d’achat avec produit chargé : reste à vérifier.
- App Store Connect, Sandbox, TestFlight et appareil physique : NON TESTÉS.

Avant diffusion, créer/configurer le produit non consommable avec cet identifiant
et le prix France de 59,99 €, puis vérifier l’achat, la restauration et la
révocation en Sandbox. Aucun produit App Store Connect ni tarif live n’a été
modifié par cette intervention. Aucun commit, push ou déploiement.
