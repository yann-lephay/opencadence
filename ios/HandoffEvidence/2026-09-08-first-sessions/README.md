# Personnalisation des premières séances — moteur livré localement

8 septembre 2026. **45 tests Swift / 7 suites PASS, dont 15 tests ciblés nouveaux.**
TypeScript PASS. Build web webpack PASS. Revue indépendante anti_overengineering : PASS après
correction de deux défauts de provenance/couverture repérés sur le premier diff.

## Livraison

Entrée publique : `CadenceEngine.decidePersonalizedSession`.
Contrat : [80-20-FIRST-SESSIONS.md](../../../docs/80-20-FIRST-SESSIONS.md).

- Pratique renforcement et reprise distinctes ; deux séries par défaut, trois localement sur
  configuration familière pour pratique régulière ; habitudes précises utilisables immédiatement.
- Capacité nécessaire indépendante du matériel ; inconnu/zéro/sous-minimum/maximum ne deviennent
  pas automatiquement des séries de tractions. Pas de transfert assistance → stricte.
- Choix de charge et variante, correction de difficulté distincte de quantité, mémoire datée et
  choix aujourd'hui/usuel. L'incapacité signalée est réévaluable, pas une série fictive ni une
  exclusion permanente implicite.
- Travail réel comme base, jamais une référence future non exécutée. Progression par conventions
  existantes ; augmentation de dose sans augmentation simultanée de difficulté.
- Plan construit avant estimation, sans remplissage ni retrait temporel ; alternatives et contrôles
  locaux exposés à l'appelant ; contributions musculaires explicites, lacunes signalées sans dette.
- Reprise active : séries confirmées intactes, seules séries restantes modifiables ; série en cours
  protégée par le contrat d'entrée ; total de séries choisi inclut les séries déjà confirmées.

## Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `PersonalizedSessionTests` | 15 tests PASS |
| Package moteur complet | 45 tests / 7 suites PASS, dont parité V1/V2 et expériences précédentes |
| `npm run typecheck` après build | PASS |
| `npm run build` (Turbopack) | Échec environnement : ouverture port PostCSS non autorisée |
| `npm run build -- --webpack` | PASS |
| `git diff --check` | PASS |
| Revue indépendante finale | PASS |

La première tentative Swift était bloquée par le cache clang hors sandbox. Les commandes finales
utilisent des caches temporaires et le package sans dépendances réseau :

```sh
CLANG_MODULE_CACHE_PATH=/tmp/lbs-personalization-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/lbs-personalization-swift \
swift test --disable-sandbox --package-path ios/CadenceEngine \
  --scratch-path /tmp/lbs-personalization-build
```

Ajouter `--filter PersonalizedSessionTests` pour les scénarios ciblés. Le premier contrôle
TypeScript concurrent au build n'était pas valide car `.next/types` était en reconstruction ;
le contrôle final a été exécuté séparément après le build webpack et a réussi.

Les 15 tests couvrent les séances 1→2→3, des capacités fixées indépendamment de la prescription,
la provenance des choix/historiques, les variantes sans transfert, les données mixtes/dupliquées,
la reprise, les quantités usuelles/ponctuelles, la difficulté, la couverture et les protections.
Deux régressions issues de la revue sont explicitement testées : changer une préférence de séries
ne rafraîchit pas une capacité ancienne ; une couverture active inclut les mouvements terminés.

## Frontière de livraison

**API moteur disponible, pas encore branchée à l'app.** Aucun contrôle SwiftUI, stockage de profil,
bridge iOS, générateur TypeScript ou dispatcher historique n'a été remplacé. Les anciens appelants
conservent leur comportement ; les problèmes de départ sur ces anciennes voies ne sont donc pas
annoncés corrigés en utilisation réelle. Le raccordement doit transporter les déclarations et leurs
dates, les choix locaux, les confirmations et la protection de la série en cours selon le contrat.

Aucune donnée personnelle lue ou modifiée ; aucun historique migré, aucun commit/push/publication.
Pas de recette UI ni de test humain effectué. Les conventions 2/3 séries et la couverture éditoriale
ne constituent pas une validation physiologique ou clinique. Les gates médias/Release existants
restent fermés tant que leurs propres preuves manquent.

## Fichiers du changement

- `ios/CadenceEngine/Sources/CadenceEngine/PersonalizationModels.swift` (nouveau)
- `ios/CadenceEngine/Sources/CadenceEngine/PersonalizedSession.swift` (nouveau)
- `ios/CadenceEngine/Sources/CadenceEngine/V2Models.swift` (métadonnée catalogue optionnelle)
- `ios/CadenceEngine/Sources/CadenceEngine/V2ProductConfiguration.swift` (contributions + contrôle capacité)
- `ios/CadenceEngine/Sources/CadenceEngine/CadenceEngineV2.swift` (helpers rendus internes au module)
- `ios/CadenceEngine/Tests/CadenceEngineTests/PersonalizedSessionTests.swift` (nouveau)
- `docs/80-20-FIRST-SESSIONS.md` et ce dossier de preuve
