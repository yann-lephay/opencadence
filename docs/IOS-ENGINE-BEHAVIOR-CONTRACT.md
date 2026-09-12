# Contrat comportemental du moteur iOS V1

Statut : `V1 FROZEN AND IMPLEMENTED IN SWIFT`

Ce document fige le comportement observable du futur moteur Swift. Il ne
prescrit ni une architecture interne ni une interface. Une implémentation est
acceptable seulement si elle passe les fixtures communes sans inventer de
charge, masquer une interruption ou déduire un état physiologique.

## 1. Frontière du moteur

Le cœur est une fonction pure :

```text
generateNextWorkout(input, now) -> decision
```

La séance active possède une seconde frontière pure :

```text
reduceActiveSession(snapshot, event, now) -> transition
```

- `now` est injecté ; aucune règle ne lit directement l’horloge système.
- mêmes entrées + même `now` = même sortie ordonnée ;
- les identifiants aléatoires et la présentation restent hors du moteur ;
- le stockage, HealthKit, les notifications, les timers et SwiftUI restent hors
  de cette frontière ;
- l’historique reçu est déjà validé et trié, mais le moteur refuse une donnée
  incohérente plutôt que de la corriger silencieusement.

Un historique est un tableau de **séances**, chacune identifiée par `sessionId`.
Les résultats de mouvements sont imbriqués dans `exerciseRecords`. Les règles de
préparation prennent les trois dernières séances distinctes ; les règles de
progression filtrent ensuite leurs résultats comparables. Un résultat d’exercice
n’est jamais interprété comme une séance supplémentaire.

Le moteur TypeScript actuel est un témoin de comportements utiles, pas la
source canonique de la version iOS. Les fixtures de ce dossier deviennent
l’oracle commun pendant la migration Swift.

## 2. Entrées minimales

### Demande de séance

- durée : `20`, `30` ou `45` minutes ;
- inventaire courant ;
- calibrations distinctes pour le haut et le bas du corps ;
- historique des séries réellement enregistrées ;
- éventuelle séance active interrompue ;
- limitations déclarées, sans diagnostic ;
- contexte grossesse ou post-partum uniquement pour bloquer le moteur standard ;
- symptômes du jour uniquement si le suivi a été activé.

Les calibrations choisissent une variante faisable par famille ; elles ne créent
aucun niveau global. Une limitation explicitement déclarée retire ou remplace
seulement les variantes concernées et produit un code de raison. Le moteur ne
déduit ni pathologie ni contre-indication depuis un texte libre.

### Inventaire structuré

Une catégorie ne vaut jamais autorisation générale. Chaque entrée décrit ce qui
est réellement utilisable :

```json
{
  "category": "adjustable_dumbbell",
  "units": 2,
  "perUnitWeightsKg": [6, 8, 10],
  "supportedConfigurations": ["pair", "single", "central"]
}
```

- une charge fixe déclare `weightKg`, `units` et ses configurations ;
- une charge réglable déclare la liste atteignable `perUnitWeightsKg` ;
- la recommandation exprime toujours la charge **par unité** et la
  configuration (`pair`, `single`, `central` ou `unilateral`) ;
- `bodyweight` est un inventaire valide ;
- un texte libre reste une note utilisateur, jamais une preuve de compatibilité ;
- une configuration d’une catégorie n’est publiable que si son modèle, au moins
  un mouvement, son illustration et une fixture dédiée ont passé le gate ;
- changer l’inventaire modifie les recommandations futures, jamais les séances
  historiques.

### Configurations publiables par le premier lot de fixtures

Le manifeste des fixtures liste les configurations réellement validées pour
`bodyweight`, `fixed_dumbbell`, `adjustable_dumbbell`, `pullup_bar` et `rower`.
Une catégorie peut donc être visible sans que toutes ses configurations soient
promises. Par exemple, `pair` exige au moins deux unités.

Les autres catégories restent dans le périmètre produit cible, mais sont
masquées jusqu’à validation complète. Cette retenue évite de promettre une
compatibilité seulement nominale.

## 3. Sortie minimale

La décision est l’une de :

- `generate_workout` ;
- `generate_makeup` pour une proposition non punitive issue d’une interruption ;
- `resume_active_session` lorsqu’une séance persistée est encore active ;
- `block_standard_mode` pour grossesse ou post-partum ;
- `request_valid_input` si une entrée critique est incohérente.

Une séance générée contient :

- la durée demandée et le budget de séries principales ;
- l’état de préparation, son facteur et la cible de RIR ;
- une liste ordonnée de mouvements avec variante, séries, cible, repos et charge
  proposée lorsqu’elle existe ;
- les familles couvertes et celles omises ;
- des `reasonCodes` stables pour toute adaptation notable ;
- les contraintes de sécurité pertinentes sans diagnostic.

L’oracle décrit pour chaque séance générée un plan ordonné. Chaque ligne fixe la
variante, le pattern, le nombre de séries, la cible, le repos et la configuration
de charge ; la somme des séries correspond au budget final. Ce plan sert à
détecter une variante inadéquate, pas à figer la mise en page SwiftUI.

Les textes d’interface sont dérivés des codes de raison. Ils ne font pas partie
du calcul et peuvent évoluer sans casser l’oracle.

## 4. Règles normatives

### `ENG-DETERMINISM-001` — déterminisme

Le moteur n’utilise ni date implicite, ni hasard, ni ordre instable. Les fixtures
injectent `now` et comparent les assertions métier, pas un snapshot d’UI.

### `ENG-TIME-001` — budget par durée

Budgets nominaux : 8 séries principales à 20 minutes, 12 à 30 minutes et 16 à
45 minutes. Le budget final est :

```text
min(max(4, round(budgetNominal * facteurDePreparation)),
    4 * nombreDePatternsPrincipauxCompatibles)
```

Échauffement facile, retour au calme et rameur ne consomment pas ce budget. Le
budget est un plafond, pas une obligation de concentrer 16 séries sur trois
patterns lorsqu’un ancrage manque. Le cap de quatre séries principales par
pattern et par séance produit alors une raison explicite.

### `ENG-EQUIP-001` — vérité du matériel

Aucun mouvement, aucune configuration et aucune charge ne peuvent dépasser
l’inventaire déclaré. Si la charge suivante n’existe pas, le moteur consolide
les répétitions ou la maîtrise ; il n’invente pas un palier.

### `ENG-EQUIP-002` — gate de publication

Chaque configuration visible doit avoir un schéma, un mouvement **ou une
capacité de conditionnement** supporté, une illustration validée et au moins une
fixture positive dédiée. Le manifeste rend ces quatre preuves explicites. Une
configuration incomplète reste masquée même si le produit vise à la supporter
plus tard.

### `ENG-ANCHOR-001` — séance utile

La séance couvre autant que possible tirage, poussée, dominante genou et
charnière. Toute omission due au matériel ou à une limitation reçoit un code de
raison. L’absence d’un ancrage n’est jamais compensée par une variante non
supportée.

### `ENG-ROLLING-001` — plan roulant 7/21 jours

Après deux séries de base par ancrage compatible, chaque série restante va au
pattern classé premier selon ce tuple lexicographique, recalculé après chaque
allocation :

1. déficit normalisé à 7 jours : `max(0, cible7 - crédits7) / cible7` ;
2. déficit normalisé à 21 jours : `max(0, cible21 - crédits21) / cible21` ;
3. priorité de profil explicitement choisie ;
4. jours depuis la dernière exposition ;
5. ordre stable de départage : tirage, poussée, genou, charnière.

Une série ajoute un crédit à ses fenêtres 7 et 21 jours avant le recalcul. Les
cibles initiales, explicites dans l’entrée, valent 4 crédits à 7 jours et 12 à
21 jours par pattern. À signal stable, le moteur conserve la même variante
comparable ; il ne crée pas de variété aléatoire. Un remplacement exige
matériel, limitation, calibration ou palier explicitement différent et expose
un code de raison.

### `ENG-CALIBRATION-001` — calibration locale et limitations

Le haut et le bas du corps sont calibrés séparément. Chaque variante du
catalogue déclare sa bande `foundation` ou `established` ; un repère bas pour
une famille ne déclasse pas les autres. Une limitation déclarée retire une
variante qui aurait sinon été prescrite, conserve les autres et choisit une
substitution compatible avec le matériel. La paire de fixtures avec et sans
limitation rend ce remplacement observable. Une limitation n’est jamais
transformée en diagnostic ni en niveau global.

Lorsqu'une exclusion ponctuelle vise un mouvement avant la séance, le moteur
retire aussi toute clé qui porte exactement la même `variant`. Changer seulement
l'identifiant interne tout en réaffichant le même mouvement constituerait un
faux remplacement. Les clés explicitement choisies restent dans la décision de
séance pour expliquer le plan, mais ne deviennent pas une règle permanente du
profil.

### `ENG-READINESS-001` — préparation et précédence

Les seuils et facteurs ci-dessous sont des heuristiques produit conservatrices,
deterministes et a valider en beta. Ils ne constituent ni un score medical ni
des temps de recuperation universels.

La première condition applicable dans cet ordre fixe le facteur :

1. douleur précédente `>= 5` : `0,55`, technique, RIR `3–4` ;
2. effort `>= 9` dans au moins deux des trois dernières séances : `0,65`, RIR
   `3–4` ;
3. moins de 24 h depuis la dernière séance : `0,55`, RIR `3–4` ;
4. moins de 48 h et dernier effort `>= 8` : `0,75`, RIR `3–4` ;
5. plus de 14 jours : `0,60`, recalibration, RIR `3–4` ;
6. de 8 à 14 jours inclus : `0,75`, reprise, RIR `3–4` ;
7. dernier effort `>= 9` ou douleur `>= 3` : `0,75`, RIR `3–4` ;
8. sinon : `1,00`, état vert, RIR `2–3`.

Les symptômes du jour peuvent ensuite plafonner le facteur à `0,65`, mais ne
peuvent jamais annuler une réduction plus forte.

### `ENG-PROGRESS-001` — progression d’abord par les répétitions

À variante comparable et dans la fourchette prévue, une seule variable change.
Avec effort `<= 8`, douleur `<= 2` et dernière série à RIR `>= 2`, le moteur
propose d’abord une répétition de plus. Il ne change pas simultanément charge,
répétitions, variante et nombre de séries.

Le passage de charge est une transition atomique explicitement exceptée : le
palier augmente et la cible de répétitions revient au bas de **la même**
fourchette. Ce retour n’est pas une seconde décision de progression ; variante,
nombre de séries et fourchette restent inchangés.

### `ENG-PROGRESS-002` — prochain palier réellement disponible

La charge n’augmente qu’après deux validations propres du haut de fourchette,
avec effort `<= 8`, douleur `<= 2` et RIR final `>= 2`. Seul le palier disponible
immédiatement supérieur est proposé, puis les répétitions repartent dans le bas
de la fourchette. Sans palier supérieur, la charge reste stable.

### `ENG-SESSION-001` — interruption vraie et non punitive

Une série existe seulement après confirmation explicite. Un exercice passé ou
une fin anticipée est enregistré comme non réalisé, jamais comme zéro. Dans les
deux jours et si la douleur précédente est `< 3`, le moteur peut proposer un
rattrapage limité aux mouvements sautés ; il exclut les mouvements terminés et
le conditionnement. L’utilisateur peut l’ignorer sans dette ni malus.

Le timer de repos stocke une échéance absolue. Après arrière-plan, fermeture ou
redémarrage, le temps restant est recalculé depuis `now` ; il n’est ni réinitialisé
ni prolongé par la pause technique de l’app.

Les actions ont des sens distincts :

- arrière-plan : l’échéance continue ;
- `pause_rest` : le reducer persiste le temps restant et retire l’échéance ;
- `resume_rest` : une nouvelle échéance vaut `now + tempsRestant` ;
- `skip_rest` : le repos est terminé ;
- `restart_rest` : une nouvelle échéance vaut `now + duréePrescrite`.

La série confirmée porte aussi la durée de repos prescrite. Son `completedAt`
est le début factuel du repos et le clic explicite qui permet de continuer
enregistre `restEndedAt`. La durée réelle est dérivée de ces deux dates, y
compris après arrière-plan, pause ou redémarrage du timer. Cette mesure reste
locale et silencieuse dans le parcours ; elle sert d’abord à étalonner le coût
temporel. Une observation isolée ne modifie jamais la progression. Toute future
personnalisation exige une tendance répétée sur plusieurs séances comparables.

Chaque événement de validation porte un `eventId`. Rejouer le même événement
est idempotent et ne crée jamais deux séries.

### `ENG-SAFETY-001` — douleur et signaux d’arrêt

Les seuils de cette echelle sont une politique de securite produit prudente,
pas un outil de triage medical valide. Les textes d'orientation devront etre
relus par une personne competente avant diffusion publique.

Une douleur `>= 5` interdit progression et rameur intense. Le produit demande
d’arrêter l’exercice et propose une orientation adaptée ; il ne qualifie jamais
la douleur de normale et ne pose aucun diagnostic. Les signaux d’alerte arrêtent
la séance standard.

Pendant une séance, une douleur déclarée `3–4` produit `stop_current_set` et
offre réduction d’amplitude, substitution ou arrêt du mouvement. Une douleur
`>= 5`, vive, électrique, croissante, accompagnée d’une perte de force,
d’instabilité ou de compensation produit `stop_current_exercise`. Un signal
d’alerte systémique produit `stop_session_and_orient`. Ces transitions
conservent les séries déjà réalisées et ne créent aucune série à zéro.

### `ENG-LIFESTAGE-001` — grossesse et post-partum

Tant qu’un mode dédié n’est pas validé, grossesse et post-partum produisent
`block_standard_mode`. Le moteur ne génère pas une version « allégée » de la
séance standard.

Ce blocage exprime une limite de capacite d'OpenCadence V1. Il ne signifie pas
que l'activite physique ou le renforcement sont interdits pendant la grossesse
ou le post-partum.

### `ENG-CYCLE-001` — symptômes déclarés uniquement

Le suivi est désactivé par défaut. Une phase de cycle n’est jamais inférée.

- `0–2` : aucune modification ;
- `3–5` : budget inchangé, premiers mouvements comme test, aucun rameur intense ;
- `6–10` : facteur plafonné à `0,65`, RIR `3–4`, aucun rameur intense.

La contraception ne déclenche aucune règle automatique.

### `ENG-ROWER-001` — rameur intense conditionnel

Le rameur intense n’est permis que si l’état final est vert, la durée est 45
minutes, un rameur est déclaré et aucun finisher intense n’a été enregistré
depuis 7 jours. « Permis » ne signifie pas « obligatoire ».

### `ENG-EXPLAIN-001` — explication stable

Chaque réduction, omission, blocage, rattrapage ou changement de charge expose
au moins un code de raison stable. Une phrase claire peut être produite sans
révéler un score opaque ni prétendre à une causalité médicale.

### `ENG-INPUT-001` — entrée incohérente explicite

Une paire avec moins de deux unités, une charge hors liste, un historique futur
ou une séance active illisible ne sont pas normalisés silencieusement. La
décision `request_valid_input` fournit un code stable et, lorsqu’il existe, le
dernier snapshot valide à restaurer.

### `ENG-PERSIST-001` — reprise atomique et idempotente

La persistance garde un snapshot complet versionné et son prédécesseur valide.
Une écriture partielle ou corrompue restaure le dernier snapshot valide ; un
échec d’écriture reste visible et ne détruit pas l’état en mémoire. L’échéance
déjà expirée reprend à zéro. Les fixtures de reducer couvrent double validation,
timer expiré, pause explicite et snapshot invalide.

## 5. Frontière des données personnelles

- inventaire, performances, douleur, symptômes et contexte physiologique sont
  conservés localement par défaut dans le conteneur protégé de l’app ;
- aucune valeur de santé, note libre ou résultat de séance ne part en log,
  télémétrie, crash report ou service tiers ;
- HealthKit reçoit seulement les données explicitement choisies lors de la
  validation d’une séance et avec autorisation système ;
- iCloud reste un opt-in séparé après le spike prévu dans le brief ;
- export et suppression sont des actions explicites, réversibles avant
  confirmation destructive ;
- les fixtures sont synthétiques et excluent nom, email, note libre,
  mensurations et localisation de douleur.

## 6. Fixtures et interprétation

[`../fixtures/ios-engine-v1/cases.json`](../fixtures/ios-engine-v1/cases.json)
contient des personnes synthétiques sans nom, email, note libre ni mesure
corporelle. Chaque cas décrit :

- les règles couvertes ;
- une horloge fixe ;
- les entrées minimales ;
- les assertions obligatoires et les incompatibilités interdites.

Les fixtures ne figent pas l’ordre visuel. Elles figent en revanche le plan
métier attendu et les frontières de vérité : budget, variantes, matériel,
charge, progression, ancrages, adaptation, sécurité et justification. Le
validateur structurel vérifie la cohérence du manifeste et des calculs qu’il
réimplémente explicitement. Il ne prouve ni la qualité biomécanique d’un
mouvement, ni l’existence visuelle d’un asset, ni la conformité du futur code
Swift : ces preuves restent des gates distincts.

## 7. Sources et arbitrages

- [`80-20-DOCTRINE.md`](80-20-DOCTRINE.md) reste la base de volume,
  progression, autorégulation, rameur et sécurité.
- [`FEMALE-ADAPTATION.md`](FEMALE-ADAPTATION.md) reste la base des symptômes
  déclarés et du blocage grossesse/post-partum.
- [`IOS-PRODUCT-BRIEF.md`](IOS-PRODUCT-BRIEF.md) tranche pour la cible iOS les
  durées 20/30/45 et leurs budgets 8/12/16.

Deux différences par rapport au moteur web actuel sont intentionnelles : le
budget 20 minutes est explicite et le rameur intense est réservé à 45 minutes.
Ce sont des décisions produit à valider en bêta, pas des affirmations
scientifiques universelles.

La classification preuve par preuve et les limites de formulation sont figees
dans [`IOS-ENGINE-EVIDENCE-MATRIX.md`](IOS-ENGINE-EVIDENCE-MATRIX.md).
