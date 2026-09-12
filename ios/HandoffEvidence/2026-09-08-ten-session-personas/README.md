# Dix séances par profil — audit produit natif, 8 septembre 2026

## Verdict

**Cohérence technique vérifiée sur 18 trajectoires de 10 séances ; proposition de valeur NON validée globalement.**

180 séances synthétiques reliées, 1 495 séries enregistrées et 11 séances interrompues.
Aucun historique personnel utilisé. Un défaut de conservation du choix est reproduit (TEN-01), et deux limites produit sont rendues visibles (TEN-02/03). Aucun correctif moteur ou écran effectué dans cet audit.

Le banc antérieur `CadenceSimulator` utilise `decideV2` / `decideAutomaticExperiment`. Ses résultats ne valident pas le chemin personnalisé. Ce nouveau test passe par `WorkoutEngineBridge.prepareWorkout` avec `person`, `NativePersonalization.adjust`, `ActiveSessionCoordinator`, `WorkoutHistoryBuilder` et les modèles SwiftData iOS. Les séances suivantes relisent les enregistrements produits par les précédentes. Le stockage du banc est exclusivement en mémoire ; chaque confirmation est sauvegardée puis restaurée.

Catalogue testé : **previewV2**, comme le parcours DEBUG actuel. Ce n'est pas une validation du catalogue de publication, encore soumis au gate des médias. Les outils n'ont pas cliqué 180 fois dans les écrans : ce sont les services natifs utilisés par les écrans qui sont exercés. On ne déduit ni faisabilité physique individuelle, ni compréhension de l'interface, ni rétention/conversion de ces résultats.

## Protocole et couverture

Les huit situations de `referencePersonas()` sont reprises : débutant régulier, rythme irrégulier, élan puis décrochage, personne lente, poids du corps, charge unique, matériel temporairement indisponible, arrêt explicite. Les quatre contrastes sont stagnation, interruptions inexpliquées, retour après 90 jours, changement durable de matériel. Six profils ajoutent pratique régulière, barre sans capacité connue, traction connue, réponse locale de capacité, baisse réelle de capacité, correction de charge.

Les calendriers sont scénarisés et reproductibles, sans probabilités de fidélité ajustées pour obtenir un résultat. Ils reprennent les situations de l'ancienne cohorte, pas ses tirages stochastiques ni ses quotas de durée. Les confirmations portent des identifiants uniques générés par le service natif : leurs UUID changent entre exécutions.

Plusieurs profils exécutent la prescription pour tester la continuité. Les contre-cas ont des capacités indépendantes : stagnation à huit répétitions ; cinq tractions puis deux ; huit répétitions à 6 kg mais seulement quatre à 8 kg. Ce ne sont pas des modèles physiologiques.

Assertions : matériel/charges/supports compatibles, provenance exacte des confirmations, anciens payloads inchangés, sauvegarde/restauration, pas de démarrage implicite, repos long sans suppression de travail, pas de dette, dose non réduite par la seule interruption, retour explicite temporaire à deux séries sans effacer l'habitude de trois, nouveau contexte matériel sans transfert de référence, correction effective de charge et mémoire à la séance suivante, capacité résolue sans question répétée, capacité insuffisante non remontée au minimum, douleur pendant l'effort sans confirmation supplémentaire et réglage bloqué tant que le signal n'est pas résolu.

Le test de non-régression TEN-01 utilise `withKnownIssue` : **ce n'est pas une exigence satisfaite**. Le succès de la commande Xcode ne rend pas ce défaut acceptable.

## Ce que vivent les profils

### Charge corrigée : apprentissage présent

La personne choisit 6 kg à la première séance et réalise huit répétitions. La deuxième repart de cette charge. À la troisième, elle essaie 8 kg, n'en fait que quatre, puis corrige à 6 kg pendant le repos. La première série et l'échéance de repos restent intactes. La quatrième propose 6 kg et huit répétitions, sans transformer le choix ponctuel en déclaration durable. Les séances suivantes conservent 6 kg dans ce scénario.

### Tractions : bonne séparation entre équipement et capacité

Avec une barre sans repère, aucune traction stricte ou excentrique n'est imposée. Quand un autre profil renseigne une série confortable de cinq, le mouvement rejoint le plan ; les séances 2 à 10 ne redemandent pas cette capacité. Un troisième profil passe de cinq à deux répétitions réelles à S4 : les strictes sont retirées à partir de S5, avec une précision à résoudre. La performance n'est pas artificiellement remontée au minimum.

### Trois séries et reprise : choix respecté, convention encore discutable

L'habitude explicite de trois séries tient sur dix séances. Après une absence de 90 jours, le profil qui choisit « reprise » reçoit deux séries à S6, conserve son habitude de trois, puis revient à trois à S7. C'est cohérent avec la portée « aujourd'hui » actuelle ; ce n'est pas une preuve que la reprise doit durer une seule séance. Toute évolution doit distinguer préférence, état du jour et observations suivantes.

## Trous ouverts

### TEN-01 — IMPORTANT : une correction disparaît avant le premier effort

Reproduction native : choisir 6 kg sur le rowing, appliquer les réglages généraux, puis regarder la proposition : **4 kg**. La reconstruction utilise un nouveau contexte sans reprendre la charge confirmée de la séance. L'assertion attend 6 et échoue effectivement.

Conséquence : « Tu viens de me demander et tu m'as oublié. » Cela contredit directement la promesse d'adaptation. Correction prioritaire : préserver les choix explicites encore compatibles lorsqu'on recalcule avant l'effort ; rendre explicite un conflit réel avec le nouveau matériel. Tester ensuite charge, variante et nombre de séries, sans réappliquer aveuglément un choix devenu impossible.

### TEN-02 — IMPORTANT pour la promesse de couverture : dix séances partielles peuvent rester le régime normal

Au poids du corps, les dix plans ont six séries et `missingPrimary = [back, hamstrings]`. Avec un haltère unique dans le profil donné, quatre ancrages sont présents mais `hamstrings` reste manquant. Avec une barre non maîtrisée, le dos ne devient pas couvert parce que l'utilisateur possède une barre.

`missingPrimary` désigne notre couverture principale cataloguée, pas l'absence totale de sollicitation de ces muscles et encore moins une mesure physiologique. Mais le test montre que cocher les ancrages ne prouve pas la couverture recherchée.

Dans `ActiveWorkoutView`, cette limite est actuellement signalée dans le détail facultatif de la séance. Dix séances ne la résolvent pas spontanément. Il faut rendre la limite perceptible sans afficher toute la montagne, puis offrir une possibilité réelle de la résoudre lorsque le catalogue et l'installation le permettent. Une nouvelle variante ne peut être inventée ou déclarée sûre pour faire passer ce test.

### TEN-03 — IMPORTANT : la stagnation est mémorisée mais peu traitée

Le profil réalise huit répétitions fixes. À partir de S2, le rowing propose neuf ; S3 à S10 proposent encore neuf malgré les huit réalisées. Même phénomène pour les cinq tractions réalisées et les six demandées. La charge n'est pas gonflée indéfiniment, mais aucun nouvel échange ne vient distinguer une série confortable volontairement arrêtée d'une cible réellement inaccessible.

C'est une limite produit observée, pas une conclusion scientifique qu'il faudrait automatiquement baisser le travail. Proposition à essayer : après plusieurs écarts comparables, une seule question locale qui change la décision (« Tu t'es arrêté volontairement ou c'était déjà difficile ? »), en conservant séparément cible et réalisé. Ne pas promettre que le moteur connaît l'effort à partir du nombre de répétitions.

## Preuves et reproduction

- `trajectories.json` : les 180 traces. `plan` est la prescription après les réglages avant séance et **avant** les corrections pendant le repos. `checks` et `missingPrimary` décrivent le contexte final. S3 du profil de charge montre donc 8 kg dans `plan`, même si la correction à 6 kg au repos est vérifiée par les assertions et la préparation S4.
- `cohort.md` : résumé par profil.
- `test-results.txt` : résultats Xcode, anomalie connue affichée sans la masquer.
- `source-hashes.json` : empreintes des sources utilisées.
- Source : `ios/OpenCadence/OpenCadenceTests/TenSessionPersonaTests.swift`.

Exécution complète native : **110 tests, 12 suites, dont 1 anomalie connue TEN-01**. Puis recontrôle ciblé de la version finale du banc : 18 cas × 10 séances + reproduction TEN-01. Le test StoreKit `LifetimePurchaseTests`, précédemment inconclusif dans ce simulateur, est exclu ; aucun verdict paiement nouveau.

Build web webpack et typecheck : PASS, aucun code web modifié. Revue indépendante `anti_overengineering` : PASS limité au banc renforcé et à ses preuves, pas à la proposition de valeur ni à l'UX humaine.

```sh
xcodebuild -project ios/OpenCadence/OpenCadence.xcodeproj -scheme OpenCadence \
  -destination 'platform=iOS Simulator,id=0A3268F6-E69E-4150-88A6-9EBD0428B6B5' \
  -parallel-testing-enabled NO -only-testing:OpenCadenceTests/TenSessionPersonaTests \
  -derivedDataPath /tmp/lbs-personalization-native test
```

**Prochaine action prioritaire : corriger TEN-01 avec les mêmes trajectoires en régression.** TEN-02 et TEN-03 demandent ensuite une réponse produit ciblée, pas une refonte générale ni une nouvelle campagne scientifique.
