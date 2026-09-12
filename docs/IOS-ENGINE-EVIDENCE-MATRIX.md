# Matrice de preuve du moteur iOS V1

Statut : `RESEARCHED AND CLASSIFIED`
Derniere verification : 30 aout 2026

## Preuve d'implementation actuelle

- package `ios/CadenceEngine` : 3 tests Swift passes, dont la parite exacte des
  45 fixtures canoniques et les combinaisons croisees generiques ;
- oracle Node : 45 fixtures structurelles, 18 regles referencees et 8
  configurations candidates validees ;
- projet `ios/OpenCadence` : compilation Swift 6 sur iPhone Simulator et 19
  tests d'integration passes ;
- parcours manuel sur iPhone 17 Pro Simulator : inventaire poids du corps,
  generation 30 minutes, demarrage, serie confirmee, repos mis en pause, app
  fermee puis relancee avec restauration exacte de `1 serie / 12` et des 84
  secondes restantes ;
- persistance de la coque : locale uniquement. La synchronisation iCloud reste
  hors du target principal tant que son schema et sa politique de conflit ne
  sont pas integres.

Cette preuve valide le raccordement moteur, la compilation et la reprise
locale. Elle ne vaut ni validation clinique, ni preuve de duree reelle, ni
validation de la direction visuelle finale.

### Extension bilan et historique

Verification du 30 aout 2026 :

- 19 tests iOS passent en Swift 6 strict : inventaire de charge, transitions de
  repos, double fallback de snapshot, correction de la derniere serie, bilan
  sans valeur subjective inventee, sauvegarde idempotente, reinjection dans
  readiness/progression/credits 7-21, heure de fin figee et refus du rattrapage
  facultatif sans alteration de l'historique ;
- les 3 tests du package moteur et les 45 fixtures canoniques restent verts ;
- parcours manuel Simulator valide avec halteres reglables : choix explicite de
  8 kg par haltere, serie enregistree, fin anticipee, bilan sans reponse
  subjective et historique `1 serie / 1 mouvement` ;
- les tests de regression confirment qu'une reponse absente ne declenche aucune
  reprise optionnelle ; une gene explicitement declaree entre 0 et 2 peut la
  proposer, et son refus genere une seance normale sans reecrire la fin anticipee ;
- l'historique reel modifie le plan normal observe : 2 series de tirage, 3 de
  genou, 4 de poussee et 3 de charniere apres un credit de tirage enregistre.

Les libelles de gene/douleur restent soumis a la relecture clinique prevue
avant beta externe. L'ecran historique actuel montre des faits recents, pas une
tendance ni un score de progression.

### Extension signalements pendant la seance

Verification du 30 aout 2026 :

- un signalement de gene est persiste separement des series avec heure,
  mouvement, transition moteur et choix de resolution ;
- les tests d'integration prouvent qu'une gene a 3 arrete la serie sans la
  compter, qu'une gene a 5 interdit la reprise du mouvement et qu'un signal
  inhabituel termine la seance avec `mustNotDiagnose` ;
- le maximum factuellement signale alimente le bilan meme si une valeur
  subjective plus basse est ensuite fournie ;
- les 19 tests iOS, les 3 tests package et les 45 fixtures canoniques restent
  verts apres l'integration ;
- la build corrigee demarre sur iPhone 17 Pro Simulator. Le nouveau parcours
  interactif reste a rejouer visuellement lorsque le Mac est deverrouille ; il
  n'est donc pas presente ici comme une preuve manuelle fraiche.

Le texte d'orientation urgent repose sur les recommandations publiques d'Ameli
sur la [douleur thoracique](https://www.ameli.fr/assure/sante/themes/douleur-thoracique/reconnaitre-agit-urgence)
et l'[essoufflement brutal](https://www.ameli.fr/assure/sante/themes/essoufflement-recent/je-suis-brutalement-essouffle-et-j-ai-du-mal-respirer-que-faire) :
en presence de douleur ou pression thoracique inquietante, d'essoufflement
brutal ou inhabituel, ou de malaise, appeler le 15 ou le 112 en France. L'app
ne classe pas la cause et ne remplace pas la regulation medicale.

### Extension calibration haut et bas du corps

Verification du 30 aout 2026 :

- un choix utilisateur explicite est distingue des valeurs techniques par
  defaut ; deux choix identiques ne sont donc plus ignores silencieusement ;
- une premiere calibration ne coche aucun repere par defaut et ne peut etre
  enregistree tant que les deux choix ne sont pas explicites ;
- les quatre combinaisons `foundation/foundation`,
  `foundation/established`, `established/foundation` et
  `established/established` sont couvertes par l'oracle ;
- les variantes generiques reglables ont une bande effective documentee sans
  ajouter de faux mouvement ni de nouvel asset : `established` pour tirage et
  poussee, `foundation` pour genou et charniere ;
- les repères sont conserves dans SwiftData, transmis au moteur et modifiables
  independamment depuis l'accueil ;
- si les halteres reglables sont retires, les valeurs restent conservees mais
  ne sont plus affichees ni transmises au moteur ;
- les 19 tests iOS, les 3 tests du package moteur et les 45 fixtures
  canoniques passent apres l'integration ;
- la build a ete installee par-dessus le stockage Simulator existant, relancee
  et l'ecran de calibration a ete capture en taille de texte standard puis en
  taille d'accessibilite. Le clic et le defilement interactifs restent a
  rejouer lorsque le Mac est deverrouille.

Cette surface est une implementation structurelle du contrat de decision, pas
une validation de la direction visuelle finale. Les bandes sont des repères de
depart propres au produit, pas une evaluation globale de la personne.

### Extension adaptation des mouvements avant la seance

Verification du 30 aout 2026 :

- le contrat `ios-pre-workout-movement-adjustment` passe le validateur et borne
  la decision a la seance en preparation, sans profil medical ni limitation
  permanente ;
- la personne peut ecarter un mouvement exact du plan initial, recalculer, puis
  le reintegrer avant de commencer ;
- le moteur exclut aussi les cles qui portent exactement la meme variante afin
  qu'un mouvement visuellement identique ne reapparaisse pas sous un autre
  identifiant interne ;
- les cles demandees sont exposees dans `EngineDecision` et restent donc dans
  le snapshot de la seance sans modifier `UserSetupRecord` ni l'historique ;
- si aucun plan compatible ne subsiste, le moteur conserve la saisie et renvoie
  une recovery explicite vers la liste des mouvements ;
- les 19 tests iOS, les 3 tests du package moteur et les 45 fixtures
  canoniques passent ; la build migree demarre sur le Home du Simulator ;
- la nouvelle feuille n'a pas ete cliquee visuellement, le Mac restant
  verrouille. Sa verification interactive et Dynamic Type sera rejouee plus
  tard sans presenter la compilation comme une preuve de parcours manuel.

La formulation de prudence suit le principe public d'Ameli : en cas de
douleur, de mal-etre ou de fatigue excessive pendant l'activite, arreter
l'exercice en cours. L'adaptation d'un mouvement reste une fonction produit et
ne remplace pas un avis medical.

## Verdict

Le moteur V1 peut etre implemente contre son oracle, a condition de ne pas
presenter tous ses seuils comme des lois scientifiques. La recherche soutient
la direction generale : entrainement de resistance regulier, travail de tous
les grands groupes musculaires, pratique a domicile, progression graduelle,
effort eleve sans obligation d'aller a l'echec, et personnalisation fondee sur
les reponses de la personne plutot que sur une phase de cycle estimee.

Les valeurs exactes de budget, de fenetre et de reduction restent des choix
produit prudents. Elles sont deterministes et testables, mais devront etre
recalibrees a partir de la beta sans revendication medicale.

## Classes utilisees

- **Invariant logiciel** : necessaire a la coherence, sans pretention
  scientifique.
- **Contrat produit** : choix explicite de V1 a mesurer en beta.
- **Heuristique alignee avec les preuves** : direction soutenue, seuil exact non
  etabli par la source.
- **Garde-fou de capacite** : limite volontaire du produit, pas diagnostic ni
  interdiction medicale universelle.
- **Politique de securite prudente** : transition conservatrice, a valider avec
  une relecture clinique avant diffusion publique.

## Classification des 18 regles

| Regle | Classe V1 | Ce que la preuve permet d'affirmer | Limite a conserver |
| --- | --- | --- | --- |
| `ENG-DETERMINISM-001` | Invariant logiciel | Une recommandation reproductible et testable exige une horloge injectee et un ordre stable. | Aucune causalite sante. |
| `ENG-TIME-001` | Contrat produit | Les formats courts et les supersets peuvent ameliorer l'efficience temporelle. | Les budgets 8/12/16 et le plafond de 4 par pattern ne sont pas des doses universelles. |
| `ENG-EQUIP-001` | Invariant logiciel et verite produit | Le travail au poids du corps et a domicile peut etre efficace ; la charge prescrite doit rester atteignable. | La compatibilite d'un mouvement exige encore une preuve visuelle et humaine. |
| `ENG-EQUIP-002` | Invariant logiciel | Le gate empeche de promettre une configuration nominale non prouvee. | Ce n'est pas une validation biomecanique. |
| `ENG-ANCHOR-001` | Heuristique alignee avec les preuves | Engager les grands groupes musculaires est coherent avec ACSM et OMS ; full-body et split produisent des resultats similaires a volume egal. | Les quatre patterns sont notre modele produit, pas l'unique decoupage valide. |
| `ENG-ROLLING-001` | Contrat produit informe par la dose-reponse | Le volume hebdomadaire est associe aux adaptations et les series indirectes peuvent etre fractionnees. | Les fenetres 7/21, cibles 4/12 et tuple de priorite sont une politique OpenCadence. |
| `ENG-CALIBRATION-001` | Heuristique alignee avec les preuves | Individualiser le point de depart et les variantes favorise une prescription praticable. | `foundation` et `established` sont des bandes produit, pas des niveaux cliniques. |
| `ENG-READINESS-001` | Heuristique alignee avec les preuves | S'eloigner de l'echec reduit fatigue et inconfort aigus ; la proximite de l'echec n'a pas un optimum unique. | 24/48 h, 8/14 jours et facteurs 0,55/0,65/0,75/0,60 sont a valider en beta. |
| `ENG-PROGRESS-001` | Heuristique alignee avec les preuves | La surcharge progressive est un principe de programmation ; changer une variable a la fois rend la recommandation explicable. | `reps-first` est notre strategie simple, pas la seule methode efficace. |
| `ENG-PROGRESS-002` | Invariant logiciel et contrat produit | Utiliser le prochain palier reel evite une prescription impossible. | Deux validations au plafond sont un seuil produit. |
| `ENG-SESSION-001` | Invariant logiciel et contrat d'experience | L'idempotence, les echeances absolues et l'absence de dette protegent la verite de la seance. | La fenetre de rattrapage de deux jours est un choix produit. |
| `ENG-SAFETY-001` | Politique de securite prudente | Une hausse dramatique de symptomes ou des signaux systemiques justifie l'arret et l'orientation ; le produit ne doit pas diagnostiquer. | Les seuils 3-4 et 5+ sont une echelle interne conservative, pas un triage medical valide. Relecture clinique requise avant diffusion. |
| `ENG-LIFESTAGE-001` | Garde-fou de capacite | L'exercice peut etre benefique pendant une grossesse non compliquee et en post-partum, avec evaluation et adaptations appropriees. | Le blocage dit uniquement que le mode standard n'implemente pas ces adaptations ; il ne dit jamais que l'exercice est interdit ou dangereux. |
| `ENG-CYCLE-001` | Heuristique alignee avec les preuves et contrat produit | Les effets moyens de phase sont faibles, variables et de faible certitude ; une approche individualisee est recommandee. Les contraceptifs oraux ne justifient pas une regle automatique d'adaptation. | Les bandes de symptomes 0-2/3-5/6-10 et le plafond 0,65 sont a tester ; aucune phase n'est inferee. |
| `ENG-ROWER-001` | Contrat produit prudent | Le conditionnement peut coexister avec la musculation ; l'option doit respecter la recuperation et l'objectif de seance. | 45 minutes et sept jours sont des seuils OpenCadence, non une prescription universelle. |
| `ENG-EXPLAIN-001` | Invariant logiciel et contrat d'experience | Des raisons stables rendent les adaptations auditables et compréhensibles. | Ne pas transformer un code en explication medicale. |
| `ENG-INPUT-001` | Invariant logiciel | Refuser explicitement une entree impossible preserve la verite de la recommandation. | Ne pas corriger silencieusement une donnee sante ou materiel. |
| `ENG-PERSIST-001` | Invariant logiciel | Snapshot versionne, restauration et idempotence protegent les series confirmees. | La persistance ne prouve pas la pertinence du programme. |

## Consequences pour la V1

1. Le moteur peut etre porte en Swift sans modifier les 45 sorties attendues.
2. Les reason codes doivent distinguer adaptation produit, securite et limite de
   capacite.
3. Aucun texte public ne doit presenter les facteurs de readiness, les budgets
   ou les fenetres comme des seuils scientifiquement demontres.
4. Le mode grossesse/post-partum reste bloque jusqu'a conception dediee et
   relecture competente, avec un message positif d'orientation.
5. Avant TestFlight externe : relecture clinique des transitions douleur et des
   textes d'orientation, puis beta sur faisabilite, comprehension, duree reelle
   et tolerance.

## Sources primaires et institutionnelles determinantes

- [ACSM, position stand 2026 sur la prescription de l'entrainement en
  resistance](https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/) : 137 revues,
  benefices de nombreuses formes de resistance training, pratique a domicile,
  grands groupes musculaires et surcharge progressive.
- [OMS, recommandations d'activite physique et de sedentarite](https://www.who.int/publications/i/item/9789240015128) : activites de renforcement des grands groupes musculaires et recommandations pour les sous-populations.
- [Pelland et al., 2026, dose-reponse volume et frequence](https://pubmed.ncbi.nlm.nih.gov/41343037/) : meta-regressions et comptage fractionnaire des series indirectes.
- [Robinson et al., 2024, proximite de l'echec](https://pubmed.ncbi.nlm.nih.gov/38970765/) : relation differente selon force et hypertrophie, avec incertitude sur l'optimum exact.
- [Influence du RIR sur la fatigue aigue, 2023](https://pubmed.ncbi.nlm.nih.gov/36752989/) : davantage de fatigue et d'inconfort en approchant l'echec dans ce protocole.
- [Zhang et al., 2025, supersets](https://pubmed.ncbi.nlm.nih.gov/39903375/) : duree reduite et adaptations comparables, avec effort percu potentiellement plus eleve.
- [Ramos-Campo et al., 2024, full-body contre split](https://doi.org/10.1519/JSC.0000000000004774) : resultats similaires a volume egal dans les etudes incluses.
- [McNulty et al., 2020, phase menstruelle et performance](https://pubmed.ncbi.nlm.nih.gov/32661839/) : effet moyen trivial, forte variabilite et preuve de faible qualite ; personnalisation recommandee.
- [Nolan et al., 2024, contraceptifs oraux et adaptations](https://pubmed.ncbi.nlm.nih.gov/37755666/) : pas d'effet significatif detecte sur hypertrophie, puissance ou force dans les etudes incluses.
- [ACOG, exercice pendant la grossesse et le post-partum](https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2020/04/physical-activity-and-exercise-during-pregnancy-and-the-postpartum-period) : activite generalement sure et souhaitable en l'absence de complication, avec evaluation et adaptations appropriees.
- [Consensus sur les risques de l'activite physique avec affection longue duree](https://pubmed.ncbi.nlm.nih.gov/34649919/) : benefices generalement superieurs aux risques et orientation si hausse dramatique des symptomes.
