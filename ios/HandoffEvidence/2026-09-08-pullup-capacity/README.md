# Tractions : disponibilité, capacité et migration

8 septembre 2026. Audit ciblé sur sources et données synthétiques. Le démarrage personnalisé reste **NON VALIDÉ** pour les tractions. Aucun profil ni historique personnel consulté ou modifié.

## Important : le natif ne dispose pas de la capacité initiale

`V2SessionDecisionInput` consomme matériel, soutiens, historique, refus, séance active et périmètre/signal de santé. Aucun champ ne distingue capacité inconnue, zéro traction ou quelques répétitions déclarées. `EquipmentOnboardingView` recueille le dégagement et l’appui permettant d’atteindre la position haute ; ce sont des conditions matérielles, pas des performances. Aucun sexe n’est utilisé pour résoudre ce choix.

Reproduction du moteur Swift actuel, séance normale 30 minutes, barre et poids du corps, sans historique :

| Entrée | Tirage choisi |
|---|---|
| Barre sans dégagement déclaré | Aucun tirage |
| Barre + dégagement, capacité inconnue | Traction stricte, 3 × 3 |
| Même entrée avec appui pour atteindre le haut | Traction stricte, 3 × 3 |

`directCandidate` trie les mouvements disponibles par `selectionRank` : stricte 35, descente 45. L’appui haut ne fait donc pas préférer la descente. Avec bande et autorisation d’attache sur barre, l’assistée est classée 30 et devient disponible ; cela ne prouve pas davantage sa faisabilité pour la personne.

Injection de références strictes dans l’API moteur : références 0, 1, 2 ou 3 → cible 3, statut `kept` ; référence 5 → cible 5. Ces références sont des entrées synthétiques de frontière, pas des confirmations physiques ni la preuve que le bridge produit chacune d’elles. Le bornage au minimum du catalogue ne protège pas une capacité inférieure au minimum. Sans référence et sans champ dédié, les situations inconnue/zéro/quelques répétitions ne sont tout simplement pas distinguables par le natif.

## Important : le web n’est pas une solution déjà complète

`components/Onboarding.tsx` expose aucune / 1 à 3 / 4 ou plus. `buildDiagnosticWorkout` utilise `pullupLevel !== "none"`, avec cible fixe de 5. `variantSupported` dans les séances ordinaires ne vérifie que la barre.

Exécution des fonctions TypeScript compilées, profils en mémoire, barre seule :

| Capacité du profil | Diagnostic | Générateur ordinaire sans historique |
|---|---|---|
| Inconnue, champ absent | 1 × 5 strictes | 3 × 5 strictes |
| Aucune | Aucun tirage | 3 × 5 strictes |
| 1 à 3 | 1 × 5 strictes | 3 × 5 strictes |
| 4 ou plus | 1 × 5 strictes | 3 × 5 strictes |

Le générateur ordinaire est appelé directement ici pour isoler son contrat ; ce tableau n’affirme pas que l’UI contourne automatiquement le diagnostic. L’API l’utilise pour les séances suivantes. Le profil neuf initialise actuellement `none`, tandis que le type autorise un champ absent.

## Correction locale appliquée : ne pas convertir une assistance en stricte

V1 `assisted_pullup` désigne `foot_assisted_pullup`, avec appui des pieds. Le bridge le projetait en `pull_up`. Il ne copiait déjà aucune référence chiffrée, mais créait un identifiant de mouvement terminé qui pouvait orienter `stableExerciseIds` vers les strictes.

Le mapping retourne maintenant `nil`, faute de variante V2 équivalente. Pas de conversion en assistance par bande ni en descente. L’archive V1 et ses séries restent intactes ; les autres mouvements migrables restent projetés. Une séance ne contenant que ce mouvement ne contribue plus à cette projection V2. Aucune réécriture de séance active, de données persistées ou de référence native V2.

Fichiers : `Services/WorkoutEngineBridge.swift` et `OpenCadenceTests/PullupMigrationTests.swift`. Revue indépendante anti_overengineering : **PASS** sur ce changement ciblé.

## Proposition contextuelle, non implémentée

Déclencher un contrôle seulement si une traction est candidate et qu’aucune preuve comparable ne permet de retenir cette variante. Demander une capacité propre à la traction stricte, avec inconnu distinct de zéro, et une quantité suffisamment précise pour distinguer 1–2 répétitions du minimum actuel de 3. Une déclaration reste une déclaration, jamais une série confirmée.

- Inconnu, zéro ou capacité inférieure au minimum : ne pas lancer la stricte par défaut.
- Assistance ou descente : ne pas les déclarer faisables sur la seule présence d’une bande ou d’un appui ; demander une confirmation contextuelle de cette variante, ou choisir un autre tirage déjà faisable.
- Aucun autre tirage faisable : omettre le tirage et expliquer localement la raison, sans compenser par du volume.
- Capacité déclarée compatible : elle borne une première proposition, sans prouver la répétabilité de plusieurs séries. Les confirmations réelles alimentent ensuite le contexte exact du mouvement.
- Ne pas compter des séries assistées comme strictes, ne pas utiliser le sexe, ne pas transformer le socle ordinaire de deux séries en preuve de personnalisation.

Ce contrat et sa présentation doivent être validés avant de créer un contrôle UI. La calibration générale actuellement ignorée par V2 ne résout pas cette lacune ; son absence d’effet ne permet pas de conclure qu’aucune donnée de capacité n’est nécessaire. Les anciennes références/volumes de trois séries ne sont pas migrés automatiquement par cet audit.

## Vérifications

- Trace moteur Swift exécutée dans une copie temporaire du package : PASS d’exécution, sorties dans `engine-audit.log`. Ce résultat expose des défauts, ce n’est pas un PASS produit.
- Fonctions web exécutées sur profils synthétiques : `web-choices.log`.
- Typecheck : PASS.
- Build web Turbopack : échec d’environnement lors de l’ouverture d’un port PostCSS (`Operation not permitted`). Build webpack : PASS.
- Compilation native de l’app et des tests : réalisée après correction d’un argument manquant dans le nouveau test. Exécution Xcode ciblée : NON EXÉCUTÉE, arrêt après plus de cinq minutes bloquées avant le lancement des tests sur le nouveau simulateur isolé. Aucune assertion native n’est annoncée passée. Le test de régression de migration reste à exécuter.
- Aucun nouveau parcours, aucune activation durée/calibration, aucun commit/push/publication. La recette UI complète n’est pas revendiquée.
