# Doctrine 80/20 V2 de La Bonne Séance

Statut : `DRAFT RÉVISÉ — CONTRAT V2 À VALIDER`

Portée : décision de séance, dose, progression, variation, substitution et
limites V1.

Autorité : après validation, cette V2 remplace la doctrine V1 sur toute règle
contradictoire. Le moteur Swift actuellement implémenté devient alors une
baseline à réaligner, pas la source canonique.

## 1. Mission et ordre des objectifs

La Bonne Séance transforme le temps, le matériel et l’historique réels d’un
adulte débutant ou intermédiaire en une séance de force domestique faisable et
explicable.

Les objectifs sont arbitrés dans cet ordre :

1. santé et capacité fonctionnelle ;
2. force générale ;
3. régularité et envie de continuer ;
4. hypertrophie raisonnable ;
5. aucune optimisation bodybuilding, powerlifting ou sportive spécialisée.

Une simplification est acceptable seulement si elle sert suffisamment les
quatre premiers objectifs. « Quelques exercices suffisent » ne peut donc pas
devenir une vérité générale sans préciser le résultat recherché.

En V1, santé et capacité fonctionnelle sont des finalités de conception et des
garde-fous. Le moteur ne mesure ni ne prétend optimiser un état de santé
individuel.

> Devenir plus fort sans se mettre à bout, avec la bonne séance pour aujourd’hui.

## 2. Registre et statut d’une règle

Chaque règle possède deux métadonnées indépendantes.

| Dimension | Valeurs |
|---|---|
| Registre | `SCIENCE`, `INSTITUTION`, `COACHING`, `PRODUIT`, `CLINIQUE`, `JURIDIQUE` |
| Statut | `FIGÉ`, `PARAMÈTRE_À_TESTER`, `VALIDATION_EXTERNE_REQUISE` |

Un paramètre `PRODUIT` peut être précis dans le code sans devenir une constante
physiologique. Il est versionné, expliqué et révisable. La confiance dans le
verdict global ne vaut pas preuve forte pour chaque nombre pris isolément.
Une règle peut relever de plusieurs registres, mais la portée de chaque source
ou validation est précisée par sous-proposition.

## 3. Invariants figés

### INV-001 — Travail réel uniquement

Statut : `FIGÉ`
Registre : `PRODUIT`

Une série existe seulement après confirmation. Une série non réalisée n’est ni
un zéro, ni une dette, ni un signal d’échec.

### INV-002 — Matériel réel uniquement

Statut : `FIGÉ`
Registre : `PRODUIT`

Aucun mouvement, montage ou palier de charge n’est proposé s’il n’est pas
réellement disponible et autorisé dans l’inventaire.

### INV-003 — Moteur central commun

Statut : `FIGÉ`
Registre : `PRODUIT`, aligné avec `SCIENCE`
Sources : `REFALO-2025`, `MCNULTY-2020`, `NOLAN-2024`

Le moteur apprend des réponses observées. Il ne réduit pas automatiquement les
ambitions selon le sexe et ne déduit aucune phase menstruelle.

### INV-004 — Effort utile, pas d’échec recherché

Statut : `FIGÉ`
Registre : `SCIENCE`, `COACHING`
Sources : `ACSM-2026`, `ROBINSON-2024`

L’échec musculaire n’est ni une cible ordinaire ni un indicateur de qualité. Une
série menée accidentellement à l’échec n’est pas moralement sanctionnée.

### INV-005 — Pas de dette

Statut : `FIGÉ`
Registre : `PRODUIT`

La séance suivante part de l’état actuel et du travail accompli, jamais d’une
semaine idéale à rattraper.

### INV-006 — Explication et limite honnêtes

Statut : `FIGÉ`
Registre : `PRODUIT`, `JURIDIQUE`

Toute adaptation importante produit une raison factuelle en une phrase. Le
produit ne pose aucun diagnostic et assume l’absence de solution propre.

## 4. Modèle utilisateur minimal

### Persistant

- inventaire exact, quantités, charges composables et incréments ;
- usages autorisés des supports : appui, assise ou montée ;
- configurations possibles : paire, unité, charge centrale, gilet, bande,
  barre, porté avec déplacement ou sur place ;
- repères initiaux distincts haut et bas lorsqu’ils changent la variante ;
- familiarité générale pour l’interface et familiarité motrice attachée au
  `progression_context` ;
- refus durables, avec portée `mouvement` ou `configuration` ;
- limitations volontairement déclarées, sans inférence médicale ;
- contexte grossesse ou post-partum explicitement déclaré, actif ou inactif et
  contrôlé par l’utilisateur, uniquement pour délimiter le moteur standard.

### Exception du jour

- durée disponible ;
- matériel temporairement absent ;
- manque d’espace, besoin de silence ou souhait d’éviter le sol ;
- choix ponctuel d’alléger ou de retrouver ses repères ;
- refus du jour, avec portée `mouvement` ou `configuration` ;
- gêne ou signal actuel lorsque cela modifie la décision.

Les exceptions expirent après la séance, sauf sauvegarde explicite.

### Déduit du travail réel

- séries, répétitions, charges et configurations réalisées ;
- historique comparable et expositions utiles ;
- contributions principales et secondaires ;
- interruptions ;
- substitutions acceptées ou refusées ;
- familiarité construite dans un `progression_context`.

### Facultatif

Un signal facultatif est demandé uniquement à un point de décision prédéfini où
au moins une réponse possible ouvre une branche différente. Chaque question
déclare son moment, la règle qui la consomme, ses conséquences possibles et le
fallback appliqué en son absence.

Effort, RIR, énergie, symptômes ou préférence de variété restent facultatifs.
Une réponse absente ne devient jamais un signal négatif et n’efface jamais la
séance de l’historique. Seul le signal facultatif absent est ignoré.

### Non collecté par défaut

Phase menstruelle supposée, photos, mensurations détaillées, niveau global,
questionnaire quotidien long ou donnée sans règle décisionnelle.

## 5. Décision de la séance du jour

### SES-001 — Flux normatif

Statut : `FIGÉ`
Registre : `PRODUIT`

Le gate de périmètre ou de sécurité précède la reprise et la génération. Le mode
`normale` est le fallback ; `allégée` produit une réduction observable par
rapport au même plan normal ; `recalibration` suspend toute progression
automatique pour retrouver des repères. Ces deux derniers modes sont choisis
explicitement et ne reposent sur aucun coefficient biologique caché.

Une nouvelle configuration ou une substitution partielle reconstruit sa
référence localement sans changer seule le mode global. Le contexte actuel est
revalidé avant toute reprise de séance active.

La précédence, le contrefactuel allégé et les sorties exactes sont définis dans
les §4 à §6 du contrat canonique.

### SES-002 — Full-body souple

Statut : `FIGÉ`
Registre : `PRODUIT`, aligné avec `SCIENCE`
Sources : `RAMOS-2024`

Le full-body est l’architecture produit par défaut parce qu’elle tolère les
semaines irrégulières. Il n’est pas présenté comme supérieur à un split de
volume comparable.

Poussée, tirage, dominante genou et charnière sont des ancrages de planification,
pas quatre cases scientifiques obligatoires. Une omission explicite vaut mieux
qu’une fausse équivalence.

### SES-003 — Une durée, un budget honnête

Statut : `FIGÉ`
Registre : `PRODUIT`, aligné avec `SCIENCE`
Sources : `ZHANG-2025`, `SINGER-2024`

Les formats 20, 30 et 45 minutes sont des budgets de planification visant une
séance utile à leur échelle. Une durée supérieure ajoute d’abord du travail aux
mêmes ancrages ou un complément utile ; elle ne remplace pas automatiquement les
mouvements.

Le coût planifié intègre installation, exécution, second côté, repos et
transition. Le repos n’est pas raccourci pour sauver le chronomètre. Le contrat
§8 définit comment prolonger ou retirer seulement du travail non commencé, sans
dette.

### SES-004 — Historique roulant sans dette

Statut : `FIGÉ` pour le principe, `PARAMÈTRE_À_TESTER` pour sa profondeur
Registre : `PRODUIT`
Sources : `PELLAND-2026`

Le moteur utilise l’exposition récente réellement accomplie pour répartir le
travail sans créer de dette. La profondeur exacte de l’historique est un
paramètre produit versionné, pas un cycle biologique.

Les contributions restent catégorielles, principales ou secondaires. Aucune
pondération numérique n’est nécessaire en V1 tant qu’elle ne change pas une
décision démontrée.

## 6. Mouvement, configuration et catalogue

### CAT-001 — Identités séparées

Statut : `FIGÉ`
Registre : `PRODUIT`

Le catalogue sépare :

1. le mouvement ;
2. sa configuration réelle ;
3. le `progression_context` qui rend deux performances comparables ;
4. ses relations motivées vers d’autres configurations.

`SOCLE`, `RÉGRESSION`, `PROGRESSION`, `SUBSTITUTION` et `ROTATION` sont des rôles
contextuels ou des relations, jamais un statut exclusif du mouvement.

Chaque mouvement décrit au minimum : contributions, matériel, chargeabilité,
installation, apprentissage, amplitude contrôlée, arrêt technique, répétitions,
coût temporel et substitutions autorisées.

Les mouvements de force, drills d’apprentissage et blocs de conditionnement
restent trois bibliothèques logiques. Un drill ne reçoit pas automatiquement du
volume musculaire ; le rameur n’est pas un tirage de musculation.

### CAT-002 — Publication validée

Statut : `FIGÉ`
Registre : `PRODUIT`

Le catalogue publie progressivement les mouvements dont le matériel, la
configuration, la démonstration et les relations ont été validés. Les tailles de
lots et objectifs de couverture vivent dans la spécification du catalogue, pas
dans la doctrine moteur.

## 7. Effort et progression

### PRO-001 — Effort ordinaire

Statut : `PARAMÈTRE_À_TESTER`
Registre : `COACHING`, `PRODUIT`, aligné avec `SCIENCE`
Sources : `ACSM-2026`, `ROBINSON-2024`, `WIEDENMANN-2026`

La cible ordinaire est une intention souple de 2 à 3 répétitions en réserve,
après familiarisation. Le RIR n’est ni un seuil de sécurité ni une vérité
immédiatement fiable chez un débutant.

Le RIR n’est jamais requis pour générer ou valider une séance, ni pour faire
progresser automatiquement un mouvement dans la V2 initiale. Une formulation
qualitative peut précéder l’échelle
numérique ; l’arrêt technique prime toujours sur la cible. Un RIR éventuellement
enregistré reste rattaché au mouvement, jamais redistribué depuis une valeur
globale de fin de séance.

Le point d’arrêt technique doit être compréhensible sans RIR : la répétition
suivante ne pourrait probablement pas conserver la trajectoire, le contrôle et
l’amplitude prévus.

Chaque mouvement possède sa propre plage réaliste. Une charge très légère
arrêtée loin de l’échec n’est pas automatiquement assimilée à une charge
modérée.

### PRO-002 — Progression multi-signaux

Statut : `FIGÉ` pour le principe, `PARAMÈTRE_À_TESTER` pour les seuils
Registre : `COACHING`, `PRODUIT`, aligné avec `SCIENCE`
Sources : `CHAVES-2024`, `ROBINSON-2024`, `WIEDENMANN-2026`

Seules les répétitions et charges confirmées dans des expositions comparables
peuvent autoriser une progression. Effort global, refus et interruption ne sont
pas des preuves positives ; gêne et douleur sortent du contrat de progression.

Dans un contexte inchangé, le moteur ne modifie qu’une variable de surcharge à
la fois et ne propose qu’un palier réel. La table exacte vit dans le §9 du
contrat canonique.

Le moteur n’invente jamais une amélioration d’amplitude, de technique ou
d’assurance qu’il ne mesure pas.

## 8. Stabilité et variation

### VAR-001 — Stabilité motivée

Statut : `FIGÉ`
Registre : `COACHING`, `PRODUIT`, aligné avec `SCIENCE`
Sources : `KASSIANO-2022`

Un mouvement reste stable tant qu’il est faisable, toléré, progressable,
familier dans sa configuration et accepté.

Une variation nécessite un motif matérialisé : matériel, refus, lassitude
exprimée, difficulté d’apprentissage, installation ou choix explicite d’un mode
plus simple aujourd’hui. Le moteur ne déduit ni plateau ni charge mentale en V1.
Il n’existe aucune rotation aléatoire ou calendaire. Depuis la décision produit du
8 septembre 2026, le parcours personnalisé iOS varie cependant l’ordre après du
travail confirmé : un mouvement entièrement réalisé sur au moins deux séries
fait avancer la rotation une fois par séance distincte. Les variantes ne tournent
que parmi celles disposant chacune de deux expositions complètes récentes,
toutes les trois séances qualifiantes. Les capacités restent propres à chaque
configuration. Cette convention produit vise la monotonie anticipée ; elle ne
constitue pas une preuve de motivation ou d’efficacité.

Les nouvelles séances peuvent alterner deux mouvements haut/bas sans contribution
principale commune et sans changement de charge entre partenaires chargés. Les
repos prescrits restent entiers. Une correction qui rend les charges incompatibles
fait terminer les séries restantes du premier partenaire avant le second.

Deux séances distinctes, dans les 48 heures, avec au moins deux séries entièrement
confirmées sur un même muscle principal autorisent une série de moins localement
(dans les limites du catalogue), sans progression simultanée. Ce seuil est une
convention de programmation, pas un diagnostic de récupération. Une saisie explicite
de séries reste prioritaire ; les séances incomplètes ne créent aucune dette.

## 9. Substitution motivée

### SUB-001 — Même muscle ne suffit pas

Statut : `FIGÉ`
Registre : `PRODUIT`, aligné avec `SCIENCE`
Sources : `ACSM-2026`

Une relation éditoriale et validée est :

- **forte** si fonction, contribution, chargeabilité, stabilité, amplitude,
  apprentissage, installation et durée restent suffisamment proches ;
- **partielle** si la séance reste utile mais exige une nouvelle référence ;
- **interdite** si elle créerait une fausse équivalence ou une installation non
  validée.

Le moteur ne calcule aucun score automatique de similarité. Charge et objectifs
chiffrés ne sont transférés que dans un contexte réellement comparable. Motif,
rang éditorial et portée du refus sont définis dans le §7 du contrat canonique.

## 10. Interruption et absence de dette

### HIS-001 — Partiel signifie partiel

Statut : `FIGÉ`
Registre : `PRODUIT`

Une séance fermée conserve les séries confirmées et laisse les autres absentes.
Aucun rattrapage automatique n’est créé. Avant une reprise explicite, seul le
travail non commencé est revalidé avec le contexte actuel, selon le §8 du
contrat canonique.

## 11. Gêne, douleur et limites de capacité

### SAFE-001 — Arrêter sans diagnostiquer

Statut : `VALIDATION_EXTERNE_REQUISE`
Registre : `CLINIQUE`, `JURIDIQUE`

Le produit recueille des faits sans demander de diagnostic. Avant validation
clinique, un signal de douleur ou de santé ne déclenche ni contournement chargé
ni orientation différenciée. L’arrêt reste accessible, le signal n’est jamais
minimisé et le travail déjà réalisé reste conservé. La branche exécutable
conservatrice vit dans le §10 du contrat canonique.

Les seuils, textes et actions doivent être relus par un médecin du sport ou un
kinésithérapeute compétent avant bêta externe. Les séries déjà réalisées restent
conservées après un arrêt.

### SAFE-002 — Périmètres spécifiques

Statut : `FIGÉ` pour la limite V1, `VALIDATION_EXTERNE_REQUISE` pour un futur mode
Registre : `PRODUIT`, `CLINIQUE`, `JURIDIQUE`, informé par `INSTITUTION`
Sources : `ACOG-2020`, `MCNULTY-2020`, `NOLAN-2024`

Le moteur standard n’est pas proposé lorsqu’une grossesse ou une situation de
post-partum est explicitement déclarée. Le produit n’infère jamais cet état et
présente l’exclusion comme une limite de périmètre V1, non comme une interdiction
d’exercice.

Les symptômes menstruels éventuellement déclarés conduisent à un choix selon
leur impact fonctionnel. Il n’existe ni seuil universel de 6/10, ni coefficient
automatique, ni interdiction spécifique du rameur.

## 12. Explication et ton

### EXP-001 — Enthousiasme fondé sur des faits

Statut : `FIGÉ`
Registre : `PRODUIT`

Chaque décision notable produit un code stable, une raison factuelle et une
phrase courte. Le coach est direct, enthousiaste et précis, jamais mollement
rassurant ou culpabilisant.

Il peut célébrer une progression de répétitions à charge comparable, un effort
déclaré inférieur dans un `progression_context`, une charge, une plage et une
échelle comparables, une adaptation pertinente ou une séance réduite réellement
accomplie. Sinon, il formule un constat neutre. Il ne crée ni streak moral, ni
faux constat biomécanique.

## 13. Paramètres encore ouverts

| Paramètre | Statut V2 |
|---|---|
| Répétitions par configuration | Bloquant avant catalogue final. |
| Repos et coûts temporels | Bloquant pour la promesse de durée. |
| Dose minimale par configuration | À versionner et chronométrer. |
| Confirmation avant charge | Convention prudente à tester. |
| Profondeur de l’historique roulant | À comparer dans le simulateur. |
| Déclencheur d’une question de recalibration | À versionner sans le présenter comme physiologique. |

Sont retirés comme règles physiologiques : coefficients `0,55–0,75`, ruptures
`24 h/48 h/8–14 jours`, seuil menstruel `6/10`, interdiction spécifique du
rameur et rattrapage automatique après interruption.

## 14. Contrats à compléter

Avant de réaligner le moteur :

1. plages de répétitions et arrêt technique par configuration ;
2. coût temporel réel : installation, série, côté, repos et transition ;
3. contributions principales et secondaires catégorielles ;
4. graphe éditorial de substitutions fortes, partielles et interdites ;
5. arbitrage des modes et état des références ;
6. assemblage de séance et ordre d’omission ;
7. table de progression versionnée ;
8. dépassement temporel et reprise active ;
9. périmètre et sécurité avant validation externe.

Le flux exécutable canonique est documenté séparément dans
`80-20-DECISION-CONTRACT.md`. La doctrine fixe ce qui doit rester vrai ; le
contrat fixe comment produire une sortie déterministe.

## 15. Définition de fini

### Doctrine consolidée

- chaque règle porte registre et statut ;
- chaque contradiction avec la V1 est arbitrée ;
- aucune règle n’exige une donnée absente du modèle minimal ;
- chaque inconnue est déclarée ;
- le catalogue détaillé et la technologie média restent dans leurs
  spécifications dédiées.

### Moteur prêt à réaligner

- les neuf contrats ci-dessus sont définis ;
- le premier lot de mouvements est validé ;
- chaque invariant, mode, frontière d’entrée, récupération et ancienne règle
  rejetée possède au moins un cas pertinent ;
- chaque décision importante est explicable en une phrase ;
- les anciennes fixtures pseudo-précises sont remplacées, pas seulement
  renommées.

### Bêta externe autorisée

- séances chronométrées avec de vrais débutants ;
- supports, bandes, bancs, chaises et barres revus ;
- familiarisation au RIR testée ;
- douleur, arrêt et reprise relus professionnellement ;
- grossesse, post-partum et formulations réglementaires relus ;
- parcours critiques accessibles et démonstrations validées sur appareil.

## 16. Conséquence pour le moteur actuel

Après validation de cette V2, la migration devra :

1. remplacer les facteurs et seuils temporels pseudo-précis par les trois modes ;
2. retirer le rattrapage automatique ;
3. retirer le seuil menstruel et l’interdiction spécifique du rameur ;
4. introduire contributions, coût temporel et graphe de substitutions ;
5. conserver déterminisme, vérité du matériel, idempotence, reprise active et
   codes de raison stables.

Le TypeScript, le Swift et les fixtures évoluent ensemble. Un ancien test n’est
pas conservé seulement parce qu’il fige une règle désormais rejetée. La parité
exacte avec les 45 sorties actuelles n’est donc plus un objectif : les cas qui
encodent les anciennes règles doivent échouer puis être remplacés par les cas V2.

## Sources structurantes

- `ACSM-2026` — [prescription de l’entraînement en résistance](https://pubmed.ncbi.nlm.nih.gov/41843416/)
- [OMS — activité physique et renforcement](https://www.who.int/publications/i/item/9789240015128)
- `PELLAND-2026` — [volume et fréquence](https://pubmed.ncbi.nlm.nih.gov/41343037/)
- `ROBINSON-2024` — [proximité de l’échec](https://pubmed.ncbi.nlm.nih.gov/38970765/)
- `SINGER-2024` — [repos](https://pubmed.ncbi.nlm.nih.gov/39205815/)
- `CHAVES-2024` — [répétitions ou charge](https://pubmed.ncbi.nlm.nih.gov/38286426/)
- `KASSIANO-2022` — [variation](https://pubmed.ncbi.nlm.nih.gov/35438660/)
- `RAMOS-2024` — [full-body et split](https://pubmed.ncbi.nlm.nih.gov/38595233/)
- `ZHANG-2025` — [supersets et durée](https://pubmed.ncbi.nlm.nih.gov/39903375/)
- `WIEDENMANN-2026` — [apprentissage du RIR](https://pubmed.ncbi.nlm.nih.gov/42632893/)
- `REFALO-2025` — [différences relatives de croissance musculaire selon le sexe](https://pubmed.ncbi.nlm.nih.gov/40028215/)
- `MCNULTY-2020` — [cycle menstruel et performance](https://pubmed.ncbi.nlm.nih.gov/32661839/)
- `NOLAN-2024` — [contraception et adaptations](https://pubmed.ncbi.nlm.nih.gov/37755666/)
- `ACOG-2020` — [grossesse et post-partum](https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2020/04/physical-activity-and-exercise-during-pregnancy-and-the-postpartum-period)

Toute sophistication future doit améliorer la décision, l’adhésion, la mesure
ou la sécurité. Elle ne doit jamais seulement rendre l’algorithme plus
impressionnant.
