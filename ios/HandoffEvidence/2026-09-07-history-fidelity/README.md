# Historique fidèle et durée automatique expérimentale

7 septembre 2026. Travail local, données exclusivement synthétiques. Aucun volume automatique activé par défaut.

## Résultat

Le bridge transmet désormais le volume réellement confirmé au moteur, avec sa provenance, ses dates, son unité et son contexte. Une série et trois séries ne produisent plus le même historique. Leur prescription suivante peut rester identique : conserver des faits ne prouve pas la tolérance à une dose supérieure.

Ce rapport complète le [parcours natif corrigé](../2026-09-07-followup/README.md) et remplace, sur la fidélité de l’historique, le constat du [premier banc automatique](../2026-09-07-automatic-policy-bench/README.md). Il ne transforme pas la proposition antérieure de deux séries en décision produit.

## Défauts reproduits et corrections

- Volume : les séries restaient dans le snapshot natif mais disparaissaient de la projection. Le champ optionnel `confirmedWorkEvidence` conserve chaque confirmation réelle, répétitions, charge ou option, date et identifiant disponibles. `nil` signifie preuve absente, pas zéro réalisé. `plannedSets` désigne la prescription finale présente dans le snapshot ; aucune prescription initiale absente n’est reconstruite.
- Séance partielle : une entrée sans mouvement entièrement terminé pouvait disparaître. Les faits partiels et repos réellement enregistrés sont maintenant conservés, sans référence de capacité fabriquée et sans cause d’interruption supposée.
- Comparabilité : les mouvements sautés, interrompus par sécurité ou exécutés avec une charge non comparable ne rétablissent plus une référence à la charge prescrite. Les confirmations restent présentes.
- Versions : une ancienne entrée V2 ne retombe plus dans la migration V1 sous des versions actuelles. Les preuves et repos conservent les versions originales, sans transfert de références admissibles.
- Chronologie : la projection trie les séances avant de reconstruire les expositions. Pour l’ordre des repères, une entrée sans identifiant terminé ni référence ne consomme pas la fenêtre des séances complétées.
- Durée : le coordinateur natif applique la voie sans réduction temporelle seulement à un snapshot explicitement marqué expérimental. Champ absent ou faux : comportement historique. Sauvegarde/relecture, confirmations et incompatibilité de version sont vérifiées. L’interface ne pose pas ce marqueur.

## Vérification de la vraie chaîne native

Tests exécutés sur coordinateur → snapshot → SwiftData en mémoire → payload → bridge → décision moteur. Aucune donnée personnelle utilisée.

Une et trois séries : projections différentes, préparation suivante identique. Trois repos partiels récupérés font passer le repos prescrit de 90 à 180 secondes via la règle existante ; le nombre de séries reste trois. C’est une conséquence observable de données redevenues disponibles, pas une nouvelle règle de dose.

Le questionnaire de calibration reste sans effet sur les préparations V2 comparées, avec et sans historique. Les distinctions et protections V1 restent vérifiées. Sa suppression dans le parcours V2 demeure une proposition, distincte de la recalibration après interruption de pratique et sans effacement des anciennes réponses.

## Simulation longitudinale

Le simulateur existant est étendu, pas remplacé. Douze profils, 24 semaines, graines 1–5 d’exploration et 6–10 de contrôle fixées avant lecture des résultats. Chaque groupe exécute trois volumes expérimentaux et deux projections comparées : faits présents ou omis. Aucun réglage n’a été ajusté sur les graines de contrôle.

Les 180 métriques de runs de chaque groupe sont strictement identiques entre projections, champ par champ. Cette comparaison isole l’ajout des preuves dans le simulateur ; elle ne prétend pas reproduire tous les défauts du vieux bridge natif, établis séparément par les régressions ci-dessus. Les 15 lignes de tableaux de l’ancienne baseline restent identiques à celles du runner courant, à la précision imprimée ; l’ancien runner ne produisait pas de JSON brut.

Contrôle graines 6–10 :

| Volume expérimental | Séances générées | Séries confirmées / prévues | Refus de séance | Retraits temporels | Invariants violés |
|---|---:|---:|---:|---:|---:|
| auto_max | 2996 | 31328 / 33118 | 0 | 0 | 0 |
| auto_min | 2723 | 9919 / 10382 | 273 | 0 | 0 |
| auto_two | 2996 | 20630 / 21750 | 0 | 0 | 0 |

Les refus du minimum observés dans les traces portent sur `light_plan_unavailable` : une série ne peut plus être réduite en mode allégé tout en gardant le bloc minimal. Ce résultat reste visible.

Trajectoires de contrôle, graine 6, maximum, fichiers sélectionnés :

- Régulier : les références se construisent au fil des confirmations. Aucun statut de tolérance n’est déduit du nom du profil.
- Stagnation : jours 0 et 165, charges/cibles identiques ; aucune progression répétitions ou charge dans les 323 séances du profil par politique.
- Interruptions inconnues : 143 interruptions sur 314 séances par politique. Jour 7, trois séries de rowing confirmées et zéro sur les autres mouvements ; aucune cause de fatigue inventée.
- Retour long : dernière séance jour 25, reprise jour 119. Les références sont `reconfirmation_pending`, sans effacement arbitraire des charges.
- Changement de matériel : jours 53→56, passage haltère→kettlebell avec nouvelle référence et substitutions partielles explicites. La charge du nouveau matériel n’est pas présentée comme progression comparable.

## Limites et décisions restantes

La simulation vérifie la cohérence des règles avec des comportements synthétiques. Elle ne démontre ni efficacité, ni tolérance physiologique, ni acceptabilité réelle. Le simulateur reproduit sa propre chaîne d’exécution Swift ; les tests natifs couvrent séparément l’enregistrement et la persistance réels. Ce n’est pas un usage humain pendant six mois.

Les règles de prescription ne consomment pas encore le volume comme signal de dose. Ce choix est volontaire : l’avoir confirmé ne prouve pas qu’il faut le prescrire à nouveau ou l’augmenter. Une interruption sans cause ne justifie pas une baisse.

À décider : la règle de volume automatique et ses critères d’évolution, puis le retrait du questionnaire seulement en V2. Le principe de durée est acquis : programme d’abord, estimation ensuite, aucun retrait au seul motif que l’estimation est dépassée. Les trois volumes restent comparateurs expérimentaux. StoreKit, notifications et collecte restent séparés.

Le parcours visuel corrigé est documenté dans le rapport précédent. Ce lot moteur n’a pas fait de nouvelle validation visuelle et ne la remplace pas.

## Preuves et reproduction

- `summary.json` : agrégats vérifiés, groupes de graines et égalité brute.
- `selected-trajectories.json` : cas lisibles avec entrées et sorties.
- `*-factual.json.gz` et `*-legacy.json.gz` : traces complètes sélectionnées et métriques des runs, compressées sans perte ; provenance `syntheticScenario`, horloge virtuelle démarrant en janvier 2027.
- `native-tests.log`, `engine-tests.log` : vérifications Swift réussies ; nombres de tests utilisés comme couverture, pas comme critère produit.
- `typecheck.log`, `web-build.log` : TypeScript et build webpack réussis, sans publication.
- `safety-excerpt.json`, `safety-final.json.gz` : 12 arrêts avec travail enregistré, chacun attribué exactement à un mouvement ; dates, versions et repos vérifiés.
- Revue indépendante anti-overengineering : PASS après correction de l’attribution du signal de sécurité au seul mouvement concerné.

Commandes et bornes du runner : [80-20-SIMULATION.md](../../../docs/80-20-SIMULATION.md). Matrice : `CadenceSimulator --weeks 24 --seeds 5 --seed-start 1 --automatic --contrasts --output-json /tmp/result.json`, puis graines 6 et même commande avec `--legacy-history-projection`. Ajouter `--trace-personas` et `--trace-seeds` selon la couverture documentée ; les archives conservent ces options dans leurs métadonnées.
