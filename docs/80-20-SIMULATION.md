# Simulation accélérée du moteur 80/20

## Objectif

Cette simulation projette plusieurs semaines en quelques secondes. Elle exécute
le vrai moteur Swift V2 avec une horloge virtuelle ; elle ne remplace pas le
temps réel par des attentes ou des `sleep`.

Elle sert à détecter avant une bêta :

- une charge ou un matériel inventé ;
- une progression non atomique ;
- une dette après interruption ;
- une durée systématiquement dépassée ;
- des départs de séries imposés trop tôt ;
- du travail confirmé puis supprimé ;
- une stabilité ou une progression manifestement incohérente dans le modèle.

Elle ne valide ni la technique d’un mouvement, ni sa sécurité biomécanique, ni
la durée réellement nécessaire à une personne. Les probabilités des profils et
leurs multiplicateurs de rythme sont des hypothèses produit versionnées, pas des
constantes scientifiques.

## Trois politiques historiques conservées (baseline)

### `strict_timer`

Le repos est plafonné au temps prescrit et la série suivante ne commence pas
si son exécution dépasserait le budget. Chaque repos naturellement plus long
est compté comme un départ pressé. Le simulateur ne coupe jamais une série déjà
commencée : les métriques comptent uniquement les séries abandonnées avant leur
démarrage.

### `fully_free`

La personne lance chaque série lorsqu’elle le souhaite. Aucun travail n’est
retiré pour finir à l’heure ; le dépassement du budget est mesuré.

### `guided_user_controlled`

La personne lance elle-même chaque série. Le repos conseillé démarre après la
confirmation, mais ne force pas le départ suivant. Chaque série et chaque repos
sont simulés séparément. Après chaque mouvement, la projection est recalculée à
partir du coût catalogue nominal restant et du seul rythme déjà observé ; le
simulateur ne consulte jamais le rythme futur. Si le reste ne tient plus, il
appelle la vraie transition V2 `finish_on_time`, qui retire uniquement du
travail non commencé.

C’était la politique candidate de la comparaison du 2 septembre. Elle reste une baseline : ce budget ne gouverne pas les expériences automatiques décrites ci-dessous.

## Profils synthétiques

Le lot de référence contient huit attitudes non cliniques :

1. débutant régulier ;
2. emploi du temps irrégulier et séances courtes ;
3. élan initial puis décrochage partiel ;
4. personne prudente avec exécution et repos plus lents ;
5. poids du corps uniquement ;
6. une seule charge disponible ;
7. matériel souvent indisponible ;
8. arrêts explicites occasionnels.

Chaque événement dépend d’une graine déterministe : séance commencée, durée,
matériel du jour, sol indisponible, mode allégé, interruption, réussite des
séries et signal d’arrêt explicite. Une même commande produit donc toujours le
même résultat. La recalibration n’utilise aucun seuil parallèle : le simulateur
attend que le vrai moteur marque une référence `reconfirmation_pending`, puis
simule le choix explicite de la personne.

## Exécution

Run de référence :

```bash
npm run simulate:v2
```

Projection personnalisée :

```bash
npm run simulate:v2 -- --weeks 24 --seeds 50
```

Le processus termine avec un code non nul lorsqu’un invariant moteur échoue.

## Baseline produit du 2 septembre 2026

Commande de contrôle : huit profils, cinq graines, douze semaines et trois
politiques, exécutées sur `V2EngineConfiguration.productPreview` et non plus sur
le petit catalogue de fixtures. Elle représente 27,69
années-personnes-politiques en 7,39 secondes sur la machine de développement.

| Politique | Séries réalisées | Dépassement moyen | Départs pressés | Retraits V2 | Séries abandonnées par limite stricte |
|---|---:|---:|---:|---:|---:|
| Chronomètre strict | 91,5 % | 0,00 min | 5,58 par séance | 0 | 0,49 série par séance |
| Rythme libre | 95,9 % | 1,56 min | 0 | 0 | 0 |
| Guidé, contrôlé par l’utilisateur | 87,1 % | 0,00 min | 0 | 1,04 série non commencée par séance | 0 |

Les trois politiques passent les invariants : aucune dette, charge, support,
matériel ou progression inventée n’a été détectée. La projection alimente aussi
le moteur avec les temps de repos simulés : une seule valeur longue ne change
rien ; trois observations comparables concordantes peuvent seulement augmenter
le repos planifié et son coût temporel, jamais la charge ou la capacité estimée.

## Lecture historique du 2 septembre — pas une nouvelle décision produit

Le modèle soutient le rythme guidé mais contrôlé par l’utilisateur :

- `20/30/45 minutes` reste un budget de planification ;
- l’utilisateur lance chaque série ;
- le repos est conseillé et modifiable ;
- aucune série commencée n’est interrompue pour respecter l’heure ;
- le moteur peut retirer du travail non commencé ou proposer de prolonger.

Le résultat ne dit pas que le guidage maximise le volume : le rythme libre
réalise davantage de séries, au prix d’un dépassement moyen. Il indique que le
guidage est le meilleur compromis testé si le produit veut à la fois respecter
le contrôle de la personne et tenir la promesse temporelle.

La simulation ne prouve pas encore que les estimations temporelles du catalogue
sont réalistes. Une petite validation humaine chronométrée devra ensuite
remplacer progressivement les multiplicateurs hypothétiques par des mesures.


## Extension du 7 septembre : faits confirmés et volumes automatiques

Le simulateur existant contient toujours les huit profils, leurs probabilités,
les canaux aléatoires et les trois politiques historiques. Aucune graine ni
probabilité historique n’a été ajustée pour améliorer un résultat. Les nouveaux
contrastes ne sont activés qu’avec `--contrasts` :

- `stagnation` : les séries finies restent sous la cible simulée ;
- `unknown_interruptions` : interruptions plus fréquentes, sans diagnostic de cause ;
- `return_after_90_days` : aucune séance simulée pendant les jours 28 à 117 inclus,
  puis reprise aux opportunités habituelles ;
- `equipment_change` : remplacement durable des haltères par des kettlebells au jour 56.

Le régulier est le profil historique `steady_beginner`. Ces profils contrastent
avec lui ; ils ne constituent ni catégories de personnes ni preuves physiologiques.

`--automatic` remplace, pour ce run seulement, les trois rythmes historiques par
`auto_max`, `auto_min` et `auto_two`. Chaque politique appelle le SPI expérimental
`CadenceEngine.decideAutomaticExperiment` et son vrai chemin interne automatique.
Les volumes correspondent respectivement au maximum du catalogue, à son minimum,
et à un plafond de deux séries. Aucun n’est retenu comme défaut produit par ce
comparateur. La durée estimée vient du plan généré : le dépassement compare ensuite
le temps simulé à cette estimation. Il ne déclenche aucun retrait de travail.
Les départs restent explicites dans la simulation ; les confirmations et les
signaux de sécurité empruntent les transitions natives. Les politiques historiques
conservent leurs règles temporelles pour permettre la comparaison avant/après.

Chaque série effectivement simulée et confirmée transmet désormais une preuve
`syntheticScenario` : identifiant déterministe, répétitions ou unité catalogue,
charge/élastique, instant virtuel de confirmation. Le mouvement conserve son nombre
de séries prévu et ses confirmations exactes. Une série absente après interruption
n’est pas déclarée « passée » sans action simulée correspondante. Les références
calculées pour la prochaine exposition restent séparées de ces faits. Les repos
réellement simulés, y compris ceux d’une séance partielle, restent transmis.
`withSets` conserve maintenant aussi `targetUnit` lorsqu’il réduit du travail non
commencé ; il ne requalifie plus implicitement des secondes en répétitions.

### Commandes reproductibles et contrôle distinct

Depuis le dépôt produit, compiler une seule fois :

```bash
swift build --package-path ios/CadenceEngine --scratch-path /tmp/lbs-volume-simulator -c release
```

Baseline historique sur graines d’ajustement 1 à 5, puis contrôle 6 à 10 :

```bash
/tmp/lbs-volume-simulator/release/CadenceSimulator --weeks 24 --seeds 5 --seed-start 1 --output-json /tmp/lbs-legacy-adjustment.json
/tmp/lbs-volume-simulator/release/CadenceSimulator --weeks 24 --seeds 5 --seed-start 6 --output-json /tmp/lbs-legacy-control.json
```

Même découpage pour les contrastes et les trois volumes expérimentaux :

```bash
/tmp/lbs-volume-simulator/release/CadenceSimulator --weeks 24 --seeds 5 --seed-start 1 --contrasts --automatic --trace-personas steady_beginner,stagnation,return_after_90_days --output-json /tmp/lbs-auto-adjustment.json
/tmp/lbs-volume-simulator/release/CadenceSimulator --weeks 24 --seeds 5 --seed-start 6 --contrasts --automatic --trace-personas steady_beginner,stagnation,return_after_90_days --output-json /tmp/lbs-auto-control.json
```

Pour isoler la conservation des faits de toute modification de dose, rejouer une
commande avec `--legacy-history-projection` : le même runner, les mêmes événements
et les mêmes politiques ne transmettent alors que les champs historiques, sans
`confirmedWorkEvidence`. Cette option n’efface pas les repos ou les références.
Tant qu’aucune politique n’utilise ces nouvelles preuves pour choisir la dose,
les métriques de prescription sont attendues identiques entre ces deux projections.
Une différence demande une explication ; elle ne doit pas être masquée par un
changement de graine. La copie de l’ancien package reste une baseline séparée.

Le JSON contient les métriques par politique/profil/graine, les versions moteur,
les paramètres de run, puis les traces de décisions : raisons de séance et de
progression, plan, historique fourni, historique écrit, matériel et temps réels
simulés. Les mesures sont toutes synthétiques. Le temps de calcul mural est exclu
pour que deux exécutions identiques produisent un JSON identique.

Les traces concernent par défaut le premier profil et la première graine du run.
`--trace-personas id1,id2` choisit les profils et `--trace-seeds N` choisit les N
premières graines de la plage (1 à 10). `--trace-limit N` borne le nombre total de
traces (1 000 par défaut, 10 000 maximum) ; `traceLimitReached` signale que la borne
a été atteinte. Les métriques couvrent toujours tous les runs, même lorsque les
traces sont bornées. Une plage principale est limitée à 104 semaines et 1 000
graines. Ces bornes protègent l’exécution locale, elles ne sont pas des règles du
produit. Ne pas utiliser ces sorties comme validation scientifique ou clinique.

## Comparaison de dose locale `--dose-policy`

Le contrat et les critères d'acceptation ont été fixés dans
[80-20-DOSE-EXPERIMENT.md](80-20-DOSE-EXPERIMENT.md) avant lecture des résultats.
Cette option compare seulement `auto_two` et `dose_candidate`, pendant 24 semaines
par défaut, sur 21 profils dédiés. Elle n'active aucune politique dans l'app.
Les trois politiques de rythme et les trois tailles automatiques antérieures
restent disponibles avec leurs profils et comportements précédents.

```bash
swift run --package-path ios/CadenceEngine CadenceSimulator \
  --dose-policy --weeks 24 --seed-start 1 --seeds 5 \
  --trace-personas explicit_volume_excess,initial_too_hard,discovery,historical_three_explicit \
  --trace-seeds 1 --trace-limit 10000 --output-json /tmp/lbs-dose-exploration.json

swift run --package-path ios/CadenceEngine CadenceSimulator \
  --dose-policy --weeks 24 --seed-start 6 --seeds 5 \
  --trace-personas equipment_ceiling,return_chosen,return_external_unknown,unknown_interruptions \
  --trace-seeds 1 --trace-limit 10000 --output-json /tmp/lbs-dose-control.json
```

Les graines 1–5 servent à explorer ; 6–10 constituent le contrôle distinct, sans
réglage après consultation. Chaque lot contient 210 trajectoires. Les métriques
restent descriptives : davantage de séries, une durée moindre ou un meilleur
taux de complétion ne désignent aucun gagnant physiologique.

### Événements et couverture

Les profils couvrent régularité, stagnation, interruption inconnue, cible atteinte
sans effort connu, difficulté faible, plafond matériel, fréquence variable,
reprise choisie, retour sans réponse, entraînement ailleurs déclaré ou inconnu,
faits de séries absents, référence ancienne, changement de contexte, volume
excessif, difficulté excessive initiale, découverte, historique de trois séries
avec ou sans choix explicite, question sans réponse et arrêt de sécurité explicite.

Les réponses sont synthétiques, datées de la décision et ciblent le contexte
fixe `supported_one_arm_row__adjustable`. Leur génération ne consulte jamais le
plan de la candidate. Le comparateur reçoit les mêmes événements dans ses traces
mais ignore les réponses locales. Un contexte indisponible ne fait pas router
la réponse vers un autre mouvement. Le mode global de reprise est choisi par
le scénario dans les deux branches ; sa réduction temporaire à une série est
une différence intentionnelle de la candidate. Le tirage historique de 75 % pour
recalibrer une référence ancienne n'est pas utilisé dans cette comparaison.

Les tirages de réussite par mouvement/série, rythme et repos sont communs aux
deux branches. L'interruption inconnue est placée à un ordinal de série tiré
parmi huit positions fixes, indépendamment du volume prescrit ; une séance
terminée avant cet événement ne le rencontre pas. Les autres voies gardent leur
ancien placement dépendant du nombre de séries planifiées.

Les historiques initiaux sont des scénarios explicites : deux séances avec dates,
charges, répétitions et séries confirmées synthétiques. L'historique de trois
séries est injecté à J−7 et J−3 ; le choix de trois séries est donné à J2 après
une première prescription mémorisée. Ces faits ne prouvent aucune tolérance.
Le profil ancien utilise J−127/J−123. Le cas de difficulté initiale excessive
possède deux expositions synthétiques antérieures à huit kilogrammes lorsque le
matériel le permet et à la cible haute du catalogue ; sa déclaration à J0 permet
d'observer une recalibration réelle plutôt qu'un appel déjà au plancher. Le profil plafond commence à la borne haute
des répétitions du catalogue avec un seul palier de charge disponible. Le profil
`missing_facts` conserve les références mais omet les preuves de séries ; il ne
transforme pas l'inconnu en zéro série. La fréquence variable passe d'une à six,
puis deux occasions hebdomadaires, sans dette.

### Lecture des traces

`exogenousFeedback` et `doseQuestionOffered` rendent visibles les réponses et les
non-réponses. `doseMemoryBefore`/`doseMemoryAfter` séparent la préférence des faits
confirmés contenus dans `historyWritten`. Les raisons `dose_*` explicitent la
branche prise. `questionsConsumed` compte les réponses acceptées, `doseChanges`
les mouvements dont la prescription de séries change depuis la séance précédente,
et `equipmentLimits` les signaux de plafond ; ces compteurs valent zéro dans les
voies qui n'exécutent pas ces branches. L'invariant supplémentaire détecte une
hausse simultanée des séries et un changement de cible/charge dans le même contexte.
Les données restent entièrement synthétiques.

Dans cette voie uniquement, le signal de sécurité des expositions concerne le
mouvement arrêté ; ce mouvement ne produit ni référence de progression ni
identifiant de mouvement entièrement terminé. Ses séries confirmées restent
conservées dans les faits. La baseline et la candidate utilisent cette même
projection ; les anciennes voies restent reproductibles.
