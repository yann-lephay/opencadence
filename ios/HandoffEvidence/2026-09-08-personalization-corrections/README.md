# Corrections de personnalisation — 8 septembre 2026

## Résultat

Corrections locales dans le moteur et les écrans iOS, après l'audit `2026-09-08-ten-session-personas`. Pas de publication ni de données personnelles utilisées. Le catalogue reste inchangé.

- **TEN-01 corrigé** : le choix de 6 kg reste 6 kg après recalcul. Les derniers choix explicites de charge, variante et séries sont conservés ; les choix d'une variante abandonnée ne sont pas rejoués. Un choix devenu incompatible avec le matériel du jour laisse une proposition compatible et une notice. Les contrôles directs de charge mettent également à jour le plan actif et sont verrouillés pendant l'effort.
- **TEN-02 traité dans l'expérience** : une couverture incomplète est annoncée avant le premier effort. Une action n'apparaît que si une question locale ou une alternative disponible peut modifier la séance. Le kickstand Romanian deadlift déjà présent permet de compléter les ischio-jambiers avec un haltère, sur choix explicite. **La lacune de couverture au poids du corps seul demeure** ; elle n'est ni cachée ni compensée artificiellement.
- **TEN-03 corrigé dans le périmètre testé** : la cible réellement affichée est figée au démarrage de la série et enregistrée séparément du résultat. Après deux expositions complètes, récentes et comparables sous la cible, le réalisé est maintenu et une question facultative peut apparaître pendant le repos. Une seule question est affichée à la fois ; répondre ferme les questions de ce type pour la séance. Le mouvement doit encore avoir du travail à faire pour que la question soit affichée.

## Comportement des réponses

« Je préfère rester à huit » conserve une préférence de répétitions attachée à cette charge, sans transformer cette préférence en capacité. « Laisser les répétitions évoluer », dans Adapter le mouvement, libère explicitement cette préférence et ne réutilise pas les anciens écarts pour bloquer la reprise de progression.

« C'était déjà difficile » tente l'ajustement local de difficulté. Si aucun ajustement direct ne peut être appliqué, le sélecteur de mouvements s'ouvre avec la séance conservée : aucune diminution de charge impossible n'est inventée. « Plus tard » suspend la question dans ce contexte ; sans réponse, les répétitions maintenues ne provoquent pas une nouvelle question à chaque séance réussie à cette cible.

Le seuil de deux expositions et le maintien provisoire sont des **conventions produit à éprouver**, pas des seuils physiologiques établis. Deux séries d'une même séance, des événements dupliqués, des charges différentes, des interruptions et des anciennes cibles inconnues ne suffisent pas à déclencher la question. Aucune fatigue n'est déduite des seules répétitions.

Un cas supplémentaire révélé par la fixture a été corrigé : terminer pendant le repos, après toutes les séries d'un mouvement, ne marque plus ce mouvement comme passé. Le comportement historique V1 reste préservé.

## Dix séances rejouées

18 profils × 10 séances connectées via les services natifs, stockage SwiftData en mémoire, confirmations sauvegardées/restaurées. Le simulateur historique de quotas de durée n'est pas utilisé pour cette preuve.

| Situation | Avant | Après |
|---|---|---|
| Huit répétitions réalisées au rowing | Neuf demandées de S2 à S10 | Neuf à S2/S3 ; huit maintenues de S4 à S10, sans question répétée à S5–S10 |
| Cinq tractions réalisées | Six demandées continuellement | Cinq maintenues de S4 à S10 après deux écarts comparables |
| Charge de 8 kg trop difficile, retour à 6 kg pendant le repos | Correction déjà retenue par les faits, mais vulnérable à certains recalculs | Correction retenue et contrôle direct synchronisé avec le plan ; aucun transfert d'écarts de 6 kg à 8 kg |
| Charge A puis variante B puis recalcul | Une ancienne charge pouvait revenir dans le recalcul | Charge A retirée des choix applicables, pas de fausse notice |
| Un haltère | Ischio-jambiers non couverts principalement par le plan initial | Alternative existante accessible ; la sélection effective retire le manque |
| Aucun matériel | Dos et ischio-jambiers non couverts principalement | Limite toujours réelle, désormais visible avant l'effort |

`trajectories-after.json` contient les 180 traces. Comme dans l'audit précédent, `plan` décrit le plan après les corrections avant effort et avant les corrections pendant la séance ; `checks` décrit le contexte final. Plusieurs contrôles peuvent exister côté moteur, mais l'écran ne présente qu'une question de répétitions à la fois.

## Vérifications

- **115 tests natifs / 13 suites : PASS**, aucune anomalie connue masquée. Le test TEN-01 est devenu une assertion normale.
- **46 tests moteur / 7 suites : PASS**, dont cas de cibles absentes, charges différentes, duplications, interruptions, maintien, report de question et libération de préférence.
- Build iOS final : PASS.
- Build web webpack et typecheck : PASS ; aucun code web modifié.
- Contrat de surface validé : `qc/decision-surfaces/ios-personalized-first-sessions.json`.
- 575 clés localisées FR/EN/ES/DE, aucune traduction EN/ES/DE absente.
- Revue indépendante anti-overengineering du diff final : PASS après correction des deux cas de charge signalés.
- QC design indépendant sur captures compactes : PASS ciblé. La question laisse le minuteur prioritaire et le démarrage n'exige aucune nouvelle saisie.

Preuves : `verification.txt`, `source-hashes.json`, `trajectories-after.json` et captures `01-coverage-compact.png`, `02-repetition-rest.png`, `03-repetition-large-type.png`.

La capture grands textes montre la mise en page défilante et les retours à la ligne du haut de l'écran ; le défilement interactif jusqu'aux dernières réponses et VoiceOver n'ont pas été vérifiés. Aucun gain de conversion ou résultat humain n'est déduit des tests.

Configuration testée : **previewV2**, chemin DEBUG iOS utilisant les mêmes services. Le catalogue de publication reste soumis aux validations des médias. Les tests `LifetimePurchaseTests` sont exclus comme lors de l'audit précédent, en raison du problème StoreKit du simulateur déjà documenté ; aucun nouveau verdict paiement.

## Reproduction

```sh
xcodebuild -project ios/OpenCadence/OpenCadence.xcodeproj -scheme OpenCadence \
  -destination 'platform=iOS Simulator,id=0A3268F6-E69E-4150-88A6-9EBD0428B6B5' \
  -parallel-testing-enabled NO -skip-testing:OpenCadenceTests/LifetimePurchaseTests \
  -derivedDataPath /tmp/lbs-personalization-native test
```

Tests ciblés : `PersonalizationCorrectionsTests`, `PersonalizationNativeTests`, `TenSessionPersonaTests`, et `PersonalizedSessionTests` dans le package moteur. Les fixtures visuelles sont accessibles uniquement en DEBUG via `-OpenCadencePersonalizationProof`, éventuellement `-OpenCadenceRepetitionProof` et `-OpenCadenceLargeTypeProof` ; elles n'ouvrent pas le store utilisateur.
