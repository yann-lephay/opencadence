# Contrat canonique de décision 80/20 V2

Statut : `DRAFT EXÉCUTABLE — À VALIDER AVANT MIGRATION`

Expérience locale du 7 septembre : [contrat de dose automatique](80-20-DOSE-EXPERIMENT.md).
Dans cette expérience uniquement, la durée est estimée après construction, sans
choix obligatoire de temps ni réduction au dépassement ; les anciennes règles
de budget ci-dessous restent la baseline, pas une nouvelle instruction produit.
Le dispatcher de l’app et ses snapshots ne sont pas migrés par cette expérience.

Ce document transforme la doctrine 80/20 en décisions observables. Il ne fixe
ni l’interface, ni l’architecture Swift, ni une vérité physiologique.

Après validation des scénarios et des tables versionnées, ce contrat remplace
`IOS-ENGINE-BEHAVIOR-CONTRACT.md` comme autorité comportementale. Le contrat V1
et ses 45 fixtures deviennent alors une baseline de migration : les cas qui
encodent une règle rejetée doivent changer.

## 1. Frontière et versions

Le moteur principal reste une fonction pure :

```text
decideNextSession(input, now, policies) -> decision
```

La séance active reste un reducer pur :

```text
reduceActiveSession(snapshot, event, now, policies) -> transition
```

Mêmes entrées, même instant et mêmes versions de politique produisent la même
sortie ordonnée.

Chaque décision expose les deux versions utilisées :

- `catalogVersion` ;
- `decisionPolicyVersion`.

La politique de décision regroupe modes, assemblage, prescription et
progression. Elle ne sera scindée que si une migration indépendante le rend
nécessaire.

Une valeur exacte peut être déterministe dans une table sans être présentée
comme scientifique. Changer une table change sa version et les fixtures qui la
visent.

## 2. Entrées minimales

### 2.1 Persistantes

- inventaire réellement utilisable et configurations autorisées ;
- repères initiaux haut et bas ;
- refus persistants avec deux axes : `movement|configuration` et portée
  `persistent` ;
- familiarité motrice par `progression_context` ;
- historique des séries confirmées ;
- contexte grossesse ou post-partum explicitement déclaré, actif ou inactif ;
- versions des données et politiques ayant produit l’historique.

Le moteur ne déduit jamais grossesse, post-partum, douleur, pathologie ou phase
menstruelle depuis le sexe, une absence de réponse ou l’historique.

### 2.2 Requête du jour

- budget demandé : `20`, `30` ou `45` minutes ;
- inventaire utilisable aujourd’hui ;
- espace, bruit, sol ou installation à éviter ;
- mode demandé : `normal`, `light` ou `recalibration`, avec `normal` comme
  fallback sans question quotidienne ;
- refus du jour avec portée `movement|configuration` ;
- éventuelle séance active ;
- déclaration factuelle affectant le périmètre ou la sécurité.

Une exception du jour expire à la fermeture de la séance. Elle ne modifie une
préférence persistante que sur confirmation explicite.

### 2.3 Questions facultatives

Une question facultative n’existe que si elle déclare :

1. son point de décision ;
2. la règle qui consomme la réponse ;
3. au moins deux branches possibles ;
4. le fallback en l’absence de réponse.

Questions autorisées dans le premier contrat :

- choisir de reprendre ou fermer une séance active ;
- choisir `light` ou `recalibration` ;
- préciser le motif et la portée d’un refus ;
- choisir de prolonger ou terminer à l’heure.

L’absence de réponse ne devient jamais fatigue, douleur, refus, échec ou preuve
de progression.

Le moteur V2 ne reçoit pas une chaîne générique `returnQuestionAnswer`. La
surface qui pose une question la traduit avant l'appel en entrée canonique :
mode `normal`, `light` ou `recalibration`, reprise/fermeture, portée du refus ou
action `continue|finish_on_time`.

## 3. Sorties minimales

La décision est exactement l’une de :

- `request_valid_input` ;
- `block_standard_mode` ;
- `stop_standard_session` ;
- `resume_or_adapt_active_session` ;
- `generate_session` ;
- `no_clean_session`.

Une séance générée contient :

- son mode global ;
- son budget de planification ;
- les mouvements ordonnés et leur `progression_context` ;
- séries, plage ou cible, repos prévu et charge réelle lorsqu’elle existe ;
- l’état local de référence de chaque mouvement ;
- les ancrages couverts et omis ;
- les codes de raison et versions de politique.

## 4. Périmètre et précédence

Avant la génération, le moteur applique cet ordre sans exception :

1. entrée critique illisible ou incohérente : `request_valid_input` ou dernier
   snapshot valide pour la reprise ;
2. signal de santé actuel explicitement déclaré : `stop_standard_session`, sans
   proposition chargée ;
3. grossesse ou post-partum explicitement déclaré : `block_standard_mode` ;
4. séance active : revalider le travail restant et retourner
   `resume_or_adapt_active_session` ;
5. nouvelle séance : filtrer, choisir le mode puis assembler ;
6. aucune configuration de force publiée, compatible et logeable :
   `no_clean_session`.

Une limitation du produit est assumée. Aucun mouvement, charge ou montage n’est
inventé pour éviter `no_clean_session` ou remplir un ancrage.

## 5. Mode global et références locales

Le mode est un enum unique fourni par la requête ; en son absence, le moteur
utilise `normal`. `light` et `recalibration` sont donc mutuellement exclusifs.
Une substitution ou une référence locale à reconstruire ne change pas seule le
mode global.

### 5.1 `normal`

Mode par défaut. Aucun délai depuis la dernière séance, sexe, score global ou
coefficient historique ne le réduit automatiquement.

Un débutant sans historique reste en mode normal. Les configurations d’entrée
validées créent ses premières références.

### 5.2 `light`

Le moteur calcule d’abord le plan normal contrefactuel avec les mêmes profil,
historique, durée, inventaire, exceptions, instant et versions de politique.

Le plan allégé respecte tous ces invariants :

- aucune ligne ne reçoit plus de séries ;
- aucune charge ni variante n’est plus difficile ;
- la cible n’est pas plus proche de l’arrêt technique ;
- la durée planifiée n’est pas supérieure ;
- aucun conditionnement n’est ajouté pour compenser ;
- au moins une de ces dimensions est strictement réduite.

La V2.0 fixe l’ordre des réductions autorisées dans le code et ses fixtures.
Toute modification de cet ordre exige une nouvelle version de politique et de
nouveaux cas attendus ; elle n'est pas présentée comme un réglage dynamique. Si
aucune réduction utile et sûre n’existe, le moteur retourne
`no_clean_session` avec `light_plan_unavailable`, plutôt que de changer seulement
le libellé.

### 5.3 `recalibration`

Ce mode est choisi explicitement pour retrouver des repères. L’ancienneté d’une
référence peut déclencher la question, jamais une réduction automatique.

Garanties :

- aucune progression automatique ;
- aucune charge supérieure à la dernière référence comparable ;
- une nouvelle configuration crée sa propre référence ;
- seuls les retours nécessaires sont demandés ;
- les nouvelles séries complètent l’historique sans effacer les anciennes ;
- le mode expire à la fermeture de la séance.

### 5.4 Référence exploitable

Le `progression_context` contient l’identifiant du mouvement et uniquement les
dimensions que le catalogue marque comme pertinentes pour comparer une
performance : outil, mode de charge, latéralité, support ou hauteur, ancrage,
prise et variante d’amplitude selon le mouvement. Un changement décoratif ou un
support géométriquement équivalent ne fragmente pas l’historique.

Une référence est exploitable lorsque :

- le `progression_context` est identique ;
- au moins une exposition admissible existe ;
- la configuration reste disponible ;
- les versions de prescription sont compatibles ou disposent d’une migration
  explicite ;
- l’utilisateur n’a pas choisi de retrouver ses repères.

Le temps écoulé seul n’invalide pas la référence. Un seuil produit peut proposer
une question de recalibration ; si elle reste sans réponse, le fallback est
`normal` avec progression automatique suspendue pour les contextes concernés.

## 6. Assemblage déterministe

### 6.1 Filtrage

Le moteur retire d’abord :

- les configurations non publiées ;
- le matériel et les supports absents ou non autorisés ;
- les refus applicables ;
- les configurations incompatibles avec espace, bruit, sol ou installation ;
- les relations interdites du catalogue.

### 6.2 Ordre de sélection

Sur les configurations restantes :

1. conserver les mouvements stables encore réalisables ;
2. retenir au maximum un premier mouvement par ancrage compatible ;
3. ordonner les ancrages par exposition principale réelle la moins récente ;
4. dans un même ancrage, choisir le mouvement stable puis le rang éditorial de
   sélection le plus bas, et enfin l’identifiant stable ;
5. parcourir les ancrages dans cet ordre et ajouter leur bloc minimal seulement
   s’il loge entièrement dans le budget ;
6. ajouter des séries aux mêmes ancrages dans le même ordre tant qu’elles
   logent dans le budget et sous leur plafond ;
7. ajouter ensuite les compléments publiés par rang éditorial puis identifiant,
   seulement si leur bloc minimal loge entièrement ;
8. ajouter au plus un conditionnement, classé par rang éditorial puis
   identifiant, seulement si son bloc complet loge ; il ne compte ni comme
   tirage ni comme volume de force ;
9. exposer toute omission.

L’historique roulant utilise les contributions principales réellement
accomplies. Sa profondeur est un paramètre produit versionné. Les contributions
secondaires servent à l’explication et à l’audit, sans pondération numérique V1.

Une séance peut rester utile avec un ancrage omis si aucun mouvement propre
n’existe. `no_clean_session` n’apparaît que lorsqu’aucune configuration de force
compatible ne peut recevoir sa dose minimale dans le budget.

### 6.3 Tables nécessaires

Chaque configuration publiée fournit au minimum :

- plage de répétitions ou cible temporelle ;
- dose minimale et plafond de séries ;
- coût d’installation, d’exécution, de second côté, de repos et de transition ;
- rang de difficulté ;
- rang de sélection dans son ancrage et éventuel rang de complément ;
- contributions principales et secondaires ;
- paliers de charge explicitement autorisés ;
- relations de substitution.

Chaque bloc de conditionnement publié fournit de même son coût complet et son
rang éditorial stable.

Ces valeurs sont des paramètres de prescription à chronométrer et tester, pas
des constantes physiologiques.

## 7. Substitution et refus

Les relations du catalogue sont éditoriales et validées :

- `strong` : continuité chiffrée seulement si le `progression_context` reste
  comparable ;
- `partial` : la séance reste utile, mais une nouvelle référence est créée ;
- `forbidden` : aucune proposition.

Le moteur ne calcule aucun score de similarité. Chaque relation possède un rang
éditorial stable. Après un refus, il sélectionne automatiquement la première
relation compatible ; un nouveau refus relance le même ordre sans l’alternative
déjà écartée.

Un refus possède toujours deux axes :

- portée temporelle : `today|persistent` ;
- portée objet : `movement|configuration`.

Aucune permanence n’est déduite du nombre de refus. Un refus ne devient ni une
douleur, ni une incapacité, ni une baisse de niveau.

## 8. Temps, interruption et reprise

### 8.1 Budget de planification

Les 20, 30 et 45 minutes sont des budgets, pas des garanties à la seconde. Le
coût planifié additionne installation, exécution, second côté, repos et
transitions.

Le repos n’est jamais raccourci automatiquement pour sauver le chronomètre.

Lorsque l’exécution dépasse l’estimation, l’utilisateur choisit :

- `continue` ;
- `finish_on_time`.

Pour `finish_on_time`, le moteur retire uniquement du travail non commencé dans
cet ordre :

1. compléments facultatifs ;
2. séries ajoutées au-delà de la dose minimale ;
3. dernier ancrage non commencé, dans l’ordre inverse de priorité.

Une série commencée ou confirmée n’est jamais retirée. Le travail supprimé ne
crée aucune dette.

Chaque ligne non commencée conserve obligatoirement sa cible, son repos, sa
charge éventuelle, son statut de référence et son `progression_context`. Une
ligne incomplète est une entrée invalide ; le moteur ne reconstruit aucune de
ces valeurs depuis le catalogue courant.

### 8.2 Séance active

Avant de proposer la reprise :

- fusionner les exceptions actuelles ;
- revalider périmètre, matériel, refus et temps restant ;
- conserver toutes les séries confirmées ;
- recalculer uniquement le travail non commencé ;
- conserver l’identité de la séance ;
- ne reconduire aucune ancienne exception temporaire sans confirmation.

Le snapshot actif porte obligatoirement `catalogVersion` et
`decisionPolicyVersion`. Sans égalité avec la configuration courante ou
migration explicite, il n'est ni repris ni réduit avec les nouvelles tables.

L’utilisateur peut reprendre, adapter ou fermer. Fermer enregistre une séance
partielle réelle. Aucun rattrapage automatique n’est créé.

## 9. Progression

### 9.1 Exposition admissible

Une exposition d’un mouvement est admissible pour sa progression lorsque :

- le `progression_context` est comparable ;
- toutes les séries prescrites de ce mouvement ont été confirmées ;
- aucune série de ce mouvement n’a été interrompue par un signal de sécurité ;
- répétitions et charge réellement réalisées sont connues.

Une séance globalement interrompue peut donc fournir une exposition admissible
pour un mouvement terminé avant l’interruption.

### 9.2 Signaux autorisés

La progression automatique utilise seulement :

- répétitions confirmées ;
- charge confirmée ;
- position dans la plage versionnée ;
- nombre d’expositions comparables exigé par la table.

L’effort et le RIR peuvent être enregistrés pour apprentissage et évaluation,
mais ne modifient pas la progression automatique V2 initiale. Leur absence
n’efface pas l’exposition.

Effort global, refus, interruption, gêne et douleur ne sont jamais des preuves
positives. Refus et interruption signifient absence de preuve ; gêne et douleur
sortent du contrat de progression.

### 9.3 Table de décision

Pour chaque `progression_context` :

1. aucune référence comparable : utiliser la cible d’entrée et construire une
   référence ;
2. exposition non admissible : conserver la prescription précédente ;
3. toutes les séries atteignent la cible et la cible reste sous le haut de
   plage : proposer une répétition supplémentaire ;
4. le haut de plage est confirmé selon `decisionPolicyVersion` : proposer
   uniquement le prochain palier réel autorisé, puis revenir au bas de la même
   plage ;
5. aucun palier autorisé : conserver la charge ;
6. performance inférieure : conserver la prescription et permettre une
   recalibration explicite, sans baisse automatique de capacité ;
7. substitution partielle ou configuration différente : créer une nouvelle
   référence.

Dans un contexte inchangé, une seule variable de surcharge change à la fois.
La transition atomique « charge supérieure et retour au bas de plage » compte
comme un changement de charge, pas comme deux progressions.

## 10. Branche conservatrice de sécurité

Avant validation clinique, une déclaration pré-séance suit §4. Pendant une
séance, le reducer produit `stop_current_movement` et expose l’action
`end_session`. Il ne transforme pas cet événement local en nouvelle séance.

Dans les deux cas :

- le produit recueille un fait déclaré, pas un diagnostic ;
- un signal de douleur ou de santé arrête le mouvement concerné ;
- l’utilisateur peut terminer immédiatement la séance ;
- aucun contournement chargé n’est proposé automatiquement ;
- les séries confirmées restent enregistrées ;
- aucune orientation différenciée n’est générée par le moteur.

Un inconfort d’installation explicitement distingué d’un signal de santé peut
suivre le contrat ordinaire de substitution.

Les catégories cliniques, textes d’urgence et actions supplémentaires restent
désactivés jusqu’à validation clinique. Leur finalité et leurs formulations
nécessitent une validation juridique séparée.

## 11. Raisons

Chaque adaptation notable produit :

- un code stable ;
- une portée `session|movement|configuration` ;
- un fait source `user|equipment|history|time|product_scope|safety` ;
- la version de politique ;
- une phrase factuelle courte.

Codes minimaux :

- `equipment_temporarily_unavailable` ;
- `stable_movement_kept` ;
- `partial_substitution_new_reference` ;
- `anchor_omitted_no_compatible_movement` ;
- `all_compatible_configurations_refused` ;
- `time_budget_removed_unstarted_work` ;
- `light_mode_user_selected` ;
- `recalibration_user_selected` ;
- `progression_held_no_comparable_reference` ;
- `progression_held_reference_to_reconfirm` ;
- `progression_repetitions_increased` ;
- `progression_next_real_load` ;
- `refusal_today` ;
- `refusal_persistent` ;
- `active_session_revalidated` ;
- `safety_stop_session` ;
- `safety_stop_movement`.

Aucune raison ne mentionne un facteur biologique, une récupération supposée ou
un diagnostic.

## 12. Scénarios normatifs

### S1 — Débutant, 20 minutes, aucun matériel

Sortie attendue : `generate_session`, mode `normal`.

- uniquement des configurations d’entrée publiées au poids du corps ;
- aucune progression automatique ;
- premières références créées ;
- tirage omis avec `anchor_omitted_no_compatible_movement` si aucune solution
  publiée et propre n’existe ;
- aucune traction, table improvisée ou fausse équivalence inventée.

### S2 — Régulier, 30 minutes, matériel habituel absent

Sortie attendue : `generate_session`, mode `normal` en l’absence d’un mode
explicitement demandé.

- exception limitée à la séance ;
- mouvements stables non affectés conservés ;
- relation `strong`, `partial` ou omission ;
- transfert chiffré seulement si le contexte reste comparable ;
- inventaire persistant inchangé.

### S3 — Retour avec anciennes références

L’ancienneté déclenche au plus une question. Si l’utilisateur choisit de
retrouver ses repères : `generate_session`, mode `recalibration`.

- aucun coefficient dérivé du nombre de jours ;
- anciennes charges utilisées comme contexte et plafond ;
- aucune progression automatique ;
- nouvelles séries ajoutées à l’historique ;
- prochaine séance à nouveau `normal`, sauf nouveau choix explicite.

Sans réponse à la question : mode `normal`, progression suspendue localement
pour les références signalées à reconfirmer.

### S4 — Reprise interrompue avec contexte changé

Sortie attendue : `resume_or_adapt_active_session`.

- périmètre et exceptions revérifiés ;
- séries confirmées immuables ;
- uniquement le reste recalculé ;
- matériel absent : substitution ou omission ;
- temps réduit : retrait du non-commencé selon §8 ;
- mode original conservé ; pour changer de mode, l’utilisateur ferme la séance
  partielle puis demande une nouvelle séance ;
- aucun rattrapage ultérieur.

### S5 — Refus récurrent sans douleur

Sortie attendue : `generate_session` avec omission si aucune relation propre
n’existe. `no_clean_session` apparaît seulement si le filtrage ne laisse aucune
configuration de force capable de recevoir sa dose minimale.

- choix explicite `today|persistent` et `movement|configuration` ;
- aucune permanence déduite de la répétition ;
- substitution éditoriale ou omission ;
- aucune conséquence sur le mode ou la progression des autres mouvements ;
- aucune interprétation de santé ou de capacité.

## 13. Table versionnée de référence et seuil de migration

Le premier jeu de paramètres exacts est versionné dans
`fixtures/ios-engine-v2/cases.json` :

- catalogue de fixture : `fixture-v2.0.0` ;
- politique de décision : `2.0.0` ;
- sept mouvements de test ;
- trois substitutions partielles éditoriales ;
- treize cas exacts : S1 à S5 et huit variantes limites.

Le fichier `scripts/validate-ios-engine-v2-fixtures.mjs` vérifie notamment les
durées calculées, le matériel et les supports réels, les paliers de charge,
l'allègement composante par composante, l'absence de dette, la branche de
sécurité et l'absence des anciennes clés pseudo-précises.

Cette table reste une hypothèse produit, pas un moteur migré. Avant modification
du Swift ou du TypeScript, il faut encore :

1. chronométrer les coûts d'installation, d'exécution et de transition avec de
   vrais débutants ;
2. valider les supports domestiques autorisés ;
3. confirmer les plages et points d'arrêt des fiches de mouvements ;
4. remplacer ou valider `bodyweight_hinge` avant publication produit ;
5. figer une révision de la politique après ces corrections, puis faire passer
   les mêmes fixtures exactes.

## 14. Hors V2 initiale

- coefficients de préparation ;
- seuils biologiques supposés à 24 h, 48 h, 8, 14 ou 21 jours ;
- budgets universels 8, 12 ou 16 séries ;
- pondération numérique directe ou indirecte ;
- rattrapage après interruption ;
- détection automatique de plateau ;
- rotation calendaire ;
- score mathématique de substitution ;
- RIR obligatoire ;
- orientation clinique différenciée avant validation ;
- optimisation bodybuilding, powerlifting ou sportive spécialisée.
