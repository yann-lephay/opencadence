# QA localisation iOS — 4 septembre 2026

## Verdict

Le lot technique est prêt pour une revue linguistique humaine, mais **pas pour
publication**. Le français est la langue source et de repli ; les catalogues
anglais, espagnol et allemand sont complets et les captures demandées ont été
produites depuis les vues réelles de l'app.

## Preuves automatisées

- `Localizable.xcstrings` : 384 clés, sans valeur vide en `en`, `es` ou `de`.
- Parité des paramètres de format contrôlée dans les quatre langues.
- Nom `La Bonne Séance` conservé sans traduction.
- Régions Xcode connues : `fr`, `en`, `es`, `de`, avec `fr` comme
  `developmentRegion`.
- Métadonnées présentes pour `fr-FR`, `en-US`, `es-ES` et `de-DE`, avec
  contrôle des limites App Store.
- Validation : `node scripts/validate-localizations.mjs`.
- Suite Xcode complète sur iPhone 17 / iOS 26.5 : `TEST SUCCEEDED`.
- Build simulateur Release avec validation Store : `BUILD SUCCEEDED`.

## Captures App Store

Chaque capture mesure 1206 × 2622 px et provient d'un scénario DEBUG
déterministe utilisant `HomeView` ou `ActiveWorkoutView`, un conteneur SwiftData
en mémoire et les versions courantes du contexte moteur.

- anglais : `en-US/screenshots/{today,exercise,summary}.png` ;
- espagnol : `es-ES/screenshots/{today,exercise,summary}.png` ;
- allemand : `de-DE/screenshots/{today,exercise,summary}.png` ;
- planches de contrôle : `qa/{en-US,es-ES,de-DE}-contact-sheet.png`.

Le scénario de capture est exclu des builds Release par `#if DEBUG`. Il ne
modifie ni le moteur, ni les données persistantes, ni StoreKit.

## Accessibilité et formats

- Dynamic Type : contrôle visuel allemand effectué en taille
  `accessibility-extra-extra-extra-large`. Les contrôles de charge et de
  répétitions passent en disposition verticale afin d'éviter les textes
  tronqués. Les écrans longs restent défilables.
- Reduce Motion : la démonstration sélectionne le fallback statique avant toute
  lecture explicite ; ce comportement est couvert par le test
  `reducedMotionSelectsStaticFallback()`.
- VoiceOver : les libellés explicites, valeurs de progression, boutons de
  répétition et descriptions de démonstration sont localisés et présents dans
  le code. L'ordre parlé de bout en bout n'a pas été certifié sur appareil réel
  et reste une vérification humaine avant publication.
- Nombres et unités : les masses utilisent le formatage local de `Double` et
  distinguent une charge totale d'une paire en kg par unité.
- Prix : l'interface d'achat utilise `Product.displayPrice`. Les montants
  59,99 € en achat unique pour un accès à vie, sans abonnement, est la référence en zone euro ;
  le prix local affiché par l'App Store fait foi.
- Permissions et notifications : `N/A` dans l'état actuel, car l'app ne demande
  aucune permission système et ne programme aucune notification.

## Principes produit vérifiés dans les textes

- durées 20, 30 et 45 minutes ;
- matériel réellement disponible ;
- travail confirmé conservé ;
- aucune dette ou culpabilisation après une séance raccourcie ;
- arrêt prudent après une gêne, sans diagnostic ;
- historique local sur l'iPhone par défaut ;
- première séance complète gratuite, puis achat unique pour un accès à vie.

## Divergences et portes de sortie

1. Les textes App Store sont des brouillons. Chaque langue doit recevoir une
   validation linguistique explicite avant copie dans App Store Connect.
2. Le contrôle VoiceOver réalisé ici vérifie la présence et la localisation des
   libellés, pas toute l'expérience parlée sur appareil physique.
3. Les huit URL de confidentialité et d'assistance répondaient en HTTP 200 le
   4 septembre 2026 ; elles devront être recontrôlées au moment de la soumission.
4. Les médias d'exercice non validés restent `awaitingBranding` dans le
   manifeste ; aucune ressource n'est déclarée prête artificiellement.
5. Le dépôt du site n'a pas été modifié.
