# La Bonne Séance iOS — brief produit et protocole de conception

Statut : `PRODUCT DIRECTION CHOSEN`
Version : 1.2 — 1er septembre 2026
Décision actuelle : concevoir la meilleure app iOS et un lancement App Store simple, sans optimiser la réutilisation du prototype
Propriétaire produit : Yann

## Décision recommandée

La Bonne Séance devient une **application iOS native en SwiftUI**. Le choix optimise
la qualité du produit à long terme : cycle de vie iOS, reprise des timers,
accessibilité, haptique, notifications, stockage, intégration Apple Health et
future extension Apple Watch. La quantité de code actuel réutilisée n’est pas
un critère de décision.

`OpenCadence` reste le nom technique du prototype et du projet pendant la
transition ; **La Bonne Séance** est le nom public retenu pour le produit, le
site et l’App Store.

Le prototype web OpenCadence reste un laboratoire fonctionnel et une source de cas de
référence. Les règles, les données de test et les planches d’exercices sont
réutilisées ; l’interface React et le serveur Next.js ne sont pas transportés
dans l’app. Le moteur est réécrit en Swift à partir d’une spécification
comportementale et de fixtures communes, puis devient la source canonique du
produit iOS.

Apple demande qu’une app aille au-delà d’un site web reconditionné. La Bonne Séance
apporte dès la première version publique une vraie utilité mobile :
fonctionnement hors ligne, stockage local, reprise fiable, feedback haptique,
interface de séance adaptée à l’iPhone, historique exploitable et export des
séances vers Apple Health avec consentement.

## Principe d’arbitrage

Les choix sont évalués dans cet ordre :

1. qualité et utilité pour l’utilisateur sur plusieurs années ;
2. exactitude et évolutivité du moteur ;
3. qualité de l’expérience iPhone et intégration à l’écosystème Apple ;
4. maintenabilité par une petite équipe assistée par des agents ;
5. coût et délai de construction.

Le ratio impact/complexité reste un garde-fou contre les abstractions inutiles,
mais il ne sert plus à choisir une solution inférieure simplement parce qu’elle
réutilise davantage le prototype.

## Thèse produit

> **Devenir plus fort sans se mettre à bout.**

La Bonne Séance s’adresse aux personnes qui veulent les bénéfices d’une pratique de
la force, mais ne se reconnaissent ni dans l’esthétique punitive du fitness ni
dans les programmes rigides. Son avantage n’est pas de proposer plus
d’exercices. Il consiste à prendre de meilleures décisions, séance après
séance, avec le matériel et l’énergie réellement disponibles.

Territoire verbal :

- « La musculation qui prend soin de toi. »
- « Un ton doux, un moteur sérieux. »
- « La force tranquille : une musculation utile, progressive et compatible
  avec une vie normale. »

Ces formulations sont une direction, pas encore une identité de marque
définitive.

## Contrat du job

Pour un adulte débutant ou intermédiaire qui s’entraîne chez lui, transformer
son temps disponible, son état du jour, son matériel exact et ses performances
récentes en une séance complète et faisable, afin qu’il puisse progresser en
force de façon régulière sans programmer lui-même son entraînement, sous des
contraintes de sécurité, de confidentialité, d’explicabilité et de reprise.

Le job n’est valide que si :

```text
la séance proposée est compatible avec le matériel déclaré
ET elle tient dans la durée annoncée
ET l’utilisateur comprend quoi faire et pourquoi
ET la progression respecte les performances et limites enregistrées
ET une interruption ou une saisie erronée est récupérable
ET aucune douleur ou contre-indication déclarée n’est minimisée
```

## Public et périmètre V1

### Cœur de cible

- adultes débutants ou intermédiaires ;
- entraînement à domicile deux à quatre fois par semaine ;
- trois durées explicites : 20, 30 ou 45 minutes ;
- cible d’inventaire complète pour la musculation à domicile : poids du corps,
  haltères fixes ou réglables, kettlebells, bandes, banc ou chaise stable, barre
  de traction, barres de dips, gilet lesté et rameur ; la V1 publique ne montre
  que les catégories dont les configurations, mouvements, illustrations et
  fixtures ont passé leur gate ;
- recherche de force, de santé et de régularité plutôt que de performance
  extrême.

### Exclusions

- diagnostic, traitement, rééducation ou promesse médicale ;
- grossesse et post-partum sans mode dédié validé ;
- préparation sportive spécialisée ;
- optimisation bodybuilding avancée ;
- analyse automatique de la technique par caméra dans la V1 ;
- réseau social, défis publics, classements ou streaks culpabilisants.

La séance de 20 minutes est un vrai programme full body avec son propre budget,
pas une séance de 30 minutes amputée. Lorsqu’une séance est interrompue plus
tôt, le moteur conserve exactement ce qui a été réalisé et propose la meilleure
suite sans dette ni rattrapage punitif.

## Ce qui doit réellement différencier le produit

### 1. Une intensité utile, jamais théâtrale

- pas d’échec musculaire recherché par défaut ;
- pas de finisher punitif pour « compenser » ;
- pas de rattrapage agressif après une semaine irrégulière ;
- pas de score moral attaché à une séance manquée ;
- difficulté suffisante pour progresser, mais répétable dans une vie normale.

### 2. Un inventaire matériel exact

Le produit doit connaître davantage que la présence d’un type d’équipement. Il
doit représenter :

- les unités possédées et leur quantité ;
- les poids fixes disponibles ;
- pour un matériel réglable, les poids réellement composables et l’incrément ;
- les usages possibles : paire, charge centrale, unilatéral ;
- les accessoires qui changent un mouvement : banc stable, barre de traction,
  barres de dips, bandes, tapis ou rameur.

Invariant : le moteur ne propose jamais une charge inexistante. Exemple : il
doit distinguer `2 × 6 kg`, `1 × 16 kg au centre` et `2 × 16 kg`, qui ne sont ni
la même difficulté ni la même configuration.

### 3. Une progression stable et expliquée

La progression automatique V1 ne s’appuie que sur ce que le produit mesure de
façon fiable : consolider les répétitions dans la fourchette, puis passer au
palier réellement disponible après deux hauts de fourchette propres. Le retour
des répétitions en bas de la même fourchette fait partie de cette transition
atomique.

L’amplitude et la maîtrise restent des consignes et des motifs de refus, pas un
score automatiquement déduit. Une variante change seulement après calibration,
limitation ou décision explicite ; une série supplémentaire vient du déficit
roulant 7/21 jours, pas d’une progression opaque propre à un exercice.

Le moteur ne modifie pas plusieurs variables à la fois sans raison explicite.
Chaque changement important doit pouvoir être résumé en une phrase :

> « Tu as validé deux fois le haut de la fourchette avec encore 2 répétitions
> en réserve ; je te propose la charge disponible suivante. »

L’utilisateur confirme toujours la charge réellement utilisée.

### 4. Un plan roulant, pas une semaine idéale

La séance suivante cherche les familles sous-exposées sur 7 et 21 jours, garde
les mouvements assez stables pour mesurer la progression et reste complète
autant que le matériel le permet. Une séance interrompue est enregistrée comme
telle ; les exercices non réalisés ne deviennent pas des séries à zéro et ne
déclenchent pas une punition.

## Contrat cible du moteur V1

### Entrées

- durée disponible ;
- inventaire matériel et configurations de charge ;
- repères initiaux séparés haut/bas du corps ;
- historique des séries, répétitions, charges et variantes ;
- RIR de la dernière série, effort global et gêne ;
- limitations connues saisies par l’utilisateur ;
- symptômes du jour uniquement si le suivi correspondant est activé.

### Sorties

- séance ordonnée, estimée et compatible ;
- mouvement, variante, séries, cible, repos et charge proposée ;
- motif court de chaque adaptation notable ;
- alternative ou retrait lorsque l’équipement ou une limite invalide un
  mouvement ;
- prochaine recommandation après enregistrement de la séance réelle.

### Invariants à tester

- présence autant que possible des quatre ancrages : tirage, poussée,
  dominante genou et charnière ;
- budgets à valider : 8 séries principales à 20 minutes, 12 à 30 minutes et 16
  à 45 minutes ; chaque durée possède ses propres cas de référence ;
- cible ordinaire de 2 à 3 RIR ;
- aucune charge ou variante incompatible avec l’inventaire ;
- aucun rameur intense en état allégé ou lorsqu’il est trop récent ;
- réduction ou recalibration selon effort répété, reprise ou intervalle très
  court ;
- grossesse/post-partum bloqués tant qu’un mode dédié n’existe pas ;
- douleur vive, croissante ou signal d’alerte : arrêt et orientation adaptée,
  jamais diagnostic ;
- même moteur de progression pour tous les sexes, avec calibration séparée des
  performances ;
- phase menstruelle jamais déduite ni utilisée automatiquement.

La doctrine détaillée reste [`80-20-DOCTRINE.md`](80-20-DOCTRINE.md) et
[`FEMALE-ADAPTATION.md`](FEMALE-ADAPTATION.md). Ce brief ne les remplace pas.

## Parcours et surfaces de décision

Avant tout design ou code substantiel, chaque surface ci-dessous recevra un
contrat de décision conforme au système QC de l’Usine : objectif, état, action,
contraintes, conséquence, recovery et preuve de réussite.

| Surface | Décision principale | Preuve de réussite | Recovery minimum |
|---|---|---|---|
| Démarrage | Cette app correspond-elle à mon besoin ? | Périmètre et exclusions compris | Quitter sans créer de profil |
| Inventaire | Qu’ai-je réellement chez moi ? | Toutes les configurations utiles sont représentées | Modifier une unité sans recommencer |
| Calibration | Quel repère initial pour le haut et le bas du corps ? | Première séance faisable, sans niveau global inventé | Recalibrer un seul repère |
| État du jour | Puis-je faire la séance prévue ? | Ajustement lié aux symptômes déclarés, pas à une supposition | Reporter ou ignorer sans culpabilité |
| Aperçu | Pourquoi cette séance aujourd’hui ? | Durée, matériel, objectif et adaptations compris | Modifier durée/matériel ou reporter |
| Séance active | Que faire maintenant ? | Série enregistrée et prochain geste évident | Corriger, passer, interrompre, reprendre |
| Bilan | Qu’a réellement retenu l’app ? | Réalisé, non réalisé, effort et gêne fidèles | Modifier avant validation finale |
| Progression | Pourquoi la suite change-t-elle ? | Raison courte reliée à une donnée réelle | Refuser une charge ou garder la variante |
| Historique | Est-ce que je progresse utilement ? | Tendances lisibles sans faux score global | Corriger une séance récente avec trace |

### Contrat de calibration V1

La calibration ne classe pas la personne. Elle recueille deux repères
independants, uniquement lorsque le matériel déclaré permet réellement au
moteur de choisir des variantes différentes :

- haut du corps : tirages et poussées ;
- bas du corps : jambes et mouvements de hanches.

Chaque repère propose de reprendre progressivement ou de partir de mouvements
déjà familiers. Les deux réponses peuvent être identiques ou différentes et
restent modifiables séparément. Le moteur doit distinguer un choix explicite de
ses valeurs techniques par défaut ; il ne peut donc jamais ignorer deux
réponses identiques. Cette calibration choisit une variante de départ, pas une
charge automatique, un diagnostic ou un score de condition physique.

### Adaptation ponctuelle avant la séance

Depuis l'aperçu, une personne peut écarter pour aujourd'hui un mouvement exact
du plan initial. Le moteur recalcule uniquement avec les variantes réellement
validées pour son matériel ; il n'interprète pas la cause et ne transforme pas
ce choix en limitation permanente. Si aucune séance compatible ne subsiste,
les sélections sont conservées et la personne revient directement à leur
modification. Le snapshot de la séance conserve les mouvements demandés comme
écartés afin que l'adaptation reste explicable.

## Principes d’expérience

- une seule action dominante par portée ;
- langage concret, non médical et non culpabilisant ;
- séance utilisable d’une main, avec cibles suffisamment grandes ;
- sens conservé avec réduction des animations ;
- VoiceOver, Dynamic Type, contraste, zoom et focus testés sur le parcours
  critique ;
- les illustrations aident l’exécution mais ne prétendent pas corriger la
  technique à elles seules ;
- l’état réel et les limites restent visibles même quand la complexité du
  moteur est absorbée par l’interface.

## Direction technique recommandée

### Stack native choisie

- Swift 6 et SwiftUI pour l’application ;
- SwiftData pour la persistance structurée et les migrations ;
- Swift Testing/XCTest pour le moteur, les migrations et les parcours ;
- UserNotifications et haptique iOS pour les fins de repos utiles ;
- HealthKit en écriture, avec permission contextuelle, pour enregistrer les
  séances terminées ;
- aucune dépendance d’architecture tierce tant qu’un besoin démontré ne
  l’exige.

Le code est organisé par domaine et capacité, sans framework de state
management externe : modèle métier, moteur déterministe, persistance et
surfaces SwiftUI.

### Ce qui est réutilisé du prototype

- règles et invariants observables de `lib/workouts.ts` ;
- fixtures JSON couvrant matériel, historique et séances attendues ;
- vocabulaire métier, historique et actions d’état ;
- planches d’exercices WebP en quatre phases ;
- doctrine et cas de sécurité.

### Ce qui bloque un emballage direct

L’application actuelle lit et écrit `data/state.json` avec les API Node
`fs/path`, puis les composants passent par `/api/state`. Un bundle iOS n’exécute
pas ce serveur Next.js local. Les timers d’interface basés sur `setInterval`
doivent aussi résister au verrouillage et au passage en arrière-plan.

### Migration contrôlée du moteur

```text
doctrine + cas de référence + fixtures JSON
  -> moteur TypeScript actuel utilisé comme témoin
  -> moteur Swift pur confronté aux mêmes entrées et sorties
  -> revue des écarts
  -> moteur Swift canonique une fois la parité prouvée
```

La parité porte sur les décisions, pas sur la structure du code. Le nouveau
moteur peut corriger une règle insuffisante si l’oracle et le changement de
comportement sont explicitement validés. Une fois la migration terminée, il
n’existe pas deux moteurs à maintenir comme sources concurrentes.

Pour les timers, persister une échéance absolue et recalculer le temps restant
au retour au premier plan. Un intervalle d’affichage ne doit pas être la source
de vérité.

### Expérience native attendue

- lancement et entraînement entièrement hors ligne ;
- reprise exacte de la séance après verrouillage, interruption ou redémarrage ;
- timer fondé sur une échéance absolue, avec haptique et notification locale
  lorsque cela rend le repos récupérable ;
- export Apple Health explicite et désactivable ;
- widgets ou Apple Watch seulement après stabilité du cœur iPhone, mais sans
  choix d’architecture qui les bloque ;
- aucun upload, compte ou appel IA requis pour s’entraîner.

### IA et vidéo

L’analyse vidéo par extraction d’images est techniquement possible, mais elle
ne doit pas entrer dans la V1. Pour la technique sportive, quelques images
peuvent manquer la vitesse, la trajectoire entre deux frames et le contexte de
charge ; une sortie plausible mais fausse peut pousser à une mauvaise décision.

Deux usages futurs restent séparés :

1. **outil éditorial interne** pour présélectionner des frames et contrôler les
   planches d’exercices, toujours avec revue humaine ;
2. **fonction utilisateur opt-in** de retour vidéo, uniquement après protocole
   d’évaluation, consentement, minimisation des données, limites visibles et
   voie manuelle.

Luna pourrait ultérieurement servir à des tâches bornées et peu risquées, mais
le moteur d’entraînement V1 doit rester déterministe et testable.

## Données, confidentialité et récupération

- local-first et sans compte propre à La Bonne Séance ;
- SwiftData comme copie canonique locale ;
- synchronisation iCloud privée ciblée en opt-in, sous réserve d’un spike qui
  prouve activation tardive, conflits, restauration et suppression ;
- version de schéma et migrations testées ;
- export et import manuels restent disponibles indépendamment d’iCloud ;
- import contrôlé du `data/state.json` historique, avec aperçu et sauvegarde
  avant migration, pour ne pas perdre les séances déjà réalisées ;
- aucune note, douleur, photo ou vidéo dans les logs de diagnostic ;
- suppression locale compréhensible ;
- tant que le spike iCloud n’est pas concluant, la récupération repose sur
  SwiftData local et l’export/import manuel ;
- aucun backend propre à La Bonne Séance ; toute synchronisation autre que l’iCloud privé
  devient une décision produit et sécurité séparée.

## Validation du moteur

### 1. Oracles

Chaque règle critique est reliée à l’un des éléments suivants : doctrine datée,
source primaire, invariant explicite ou cas calculé indépendamment. Le code ne
se valide pas lui-même.

### 2. Matrice de scénarios déterministes

Couvrir au minimum :

- poids du corps seul ;
- paire de charges fixes ;
- charge unique utilisable au centre ou en unilatéral ;
- haltères réglables avec un saut important ;
- kettlebell seule et paire de kettlebells ;
- bandes de résistances différentes ;
- banc ou chaise stable avec positions réellement supportées ;
- barre de traction, barres de dips et gilet lesté ;
- rameur disponible puis absent ;
- équipement modifié entre deux séances ;
- débutant avec repères haut/bas très différents ;
- séance interrompue puis reprise ;
- plusieurs exercices non réalisés ;
- effort élevé répété, gêne, reprise après 8–14 jours et après plus de 14 jours ;
- durées 20, 30 et 45 minutes ;
- suivi menstruel désactivé, symptômes modérés et importants ;
- grossesse ou post-partum refusé par le moteur standard.

Pour chaque cas : séance attendue, incompatibilités interdites, budget de
séries, justification et état final attendu.

### 3. Simulation longitudinale

Simuler plusieurs semaines avec performances variables pour détecter :

- dérive de volume ;
- progression bloquée ou trop rapide ;
- répétition excessive ou variation arbitraire ;
- rattrapage punitif après interruption ;
- charge inventée ;
- conflit entre douleur, effort et progression.

### 4. Validation humaine

Le moteur passe les tests avant les utilisateurs. La bêta vérifie ensuite la
compréhension, la faisabilité et la confiance ; elle ne sert pas à découvrir
des erreurs déterministes évitables.

## Validation de l’app iOS

### Environnement Mac vérifié le 30 août 2026

- Xcode 26.6 installé dans `/Applications/Xcode.app` ;
- runtime et simulateurs iOS 26.5 disponibles ;
- compte Apple Developer, signature et provisioning de developpement valides ;
- conteneur CloudKit actif ;
- preuve de synchronisation CloudKit reelle passee entre deux simulateurs
  connectes au meme compte iCloud ;
- Node.js 22.14.0 et npm disponibles.

Un agent Codex peut donc modifier le projet, lancer `xcodebuild`, piloter le
simulateur avec `simctl`, prendre des captures et inspecter Xcode/Simulator via
le contrôle du Mac lorsque c’est nécessaire.

Restent `NON TESTE` : TestFlight, App Store Connect et appareil physique. Ces
preuves restent distinctes du build simulateur et de la synchronisation entre
simulateurs.

### Échelle de preuve

Ne jamais confondre :

```text
typecheck et tests moteur
-> build web statique
-> build Xcode simulateur
-> parcours sur plusieurs iPhone simulés
-> installation sur iPhone physique
-> archive signée
-> TestFlight
-> validation App Store
```

Chaque étape conserve sa commande, sa date, son environnement, son résultat et
ses limites.

## Validation restreinte avant la sortie publique

### Dogfood contrôlé

1. importer une copie anonymisée ou synthétique du profil existant ;
2. réaliser au moins plusieurs séances complètes et une interruption volontaire ;
3. vérifier matériel, temps, reprise, timers, charge et explication ;
4. corriger les défauts de moteur avant d’élargir.

### TestFlight technique restreint

Utiliser TestFlight uniquement pour éprouver l’installation, les achats, la
restauration et le parcours sur quelques iPhone réels avant la soumission
publique. Un petit groupe correspondant au cœur de cible peut vérifier :

- onboarding terminé sans aide ;
- inventaire jugé fidèle ;
- aucune série impossible avec le matériel déclaré ;
- séance terminée dans une durée proche de l’annonce ;
- adaptation comprise sans explication externe ;
- charge refusée ou corrigée facilement ;
- retour volontaire pour une nouvelle séance ;
- incident de douleur, données ou reprise traité et analysé séparément.

Le nombre de téléchargements ne prouve ni le job ni la rétention.

TestFlight n’est ni une offre commerciale, ni une attente imposée aux futurs
clients. Le lancement public se fait directement sur l’App Store lorsque les
gates techniques et produit sont fermées.

## Acquisition SEO et GEO

### Contrat éditorial

**Lecteur et décision :** une personne qui veut commencer ou reprendre la
musculation chez elle et hésite entre un programme dur, des vidéos éparses ou
une pratique plus progressive.

**Thèse :** la meilleure pratique pour ce profil n’est pas la séance la plus
dure, mais une dose efficace qui reste régulière et progresse.

**Choix défendu :** La Bonne Séance lorsque la priorité est une force durable à la
maison avec un matériel imparfait.

**Raisons :** compatibilité réelle du matériel, progression expliquée, plan
roulant et ton non punitif.

**Contre-cas :** préférer un professionnel ou une autre solution pour la
rééducation, la grossesse/post-partum, un objectif compétitif spécialisé ou un
besoin fort de cours collectifs.

### Architecture de contenu initiale

1. **Commencer sans violence** : reprendre, gérer une semaine irrégulière,
   choisir une difficulté soutenable.
2. **Force et santé** : ce que les recommandations et revues permettent
   réellement d’affirmer, avec limites explicites.
3. **S’entraîner avec ce que l’on a** : configurations de charges, variantes et
   progression à domicile.
4. **Tenir dans le temps** : effort, RIR, récupération, douleur et continuité.

Actif d’acquisition prioritaire : un outil gratuit « Que peux-tu faire avec ton
matériel chez toi ? » qui produit une réponse utile avant de proposer l’app.
Le moteur de compatibilité devient ainsi une preuve du produit, pas un simple
lead magnet.

Commencer par 8 à 12 pages ou outils réellement excellents. Une nouvelle URL
exige une situation, une preuve, une sortie ou une décision différente ; une
reformulation de mot-clé ou un fan-out LLM ne suffit pas.

### Règles de vérité et de citabilité

- distinguer recommandation, résultat mesuré, corrélation et causalité ;
- sourcer les affirmations santé avec les sources primaires et leur date ;
- publier auteur, relecteur, méthode, limites et date de mise à jour réelle ;
- écrire des réponses autonomes lorsqu’elles aident la lecture, sans quota de
  mots ni FAQ artificielle ;
- rendre l’HTML public, les liens et les métadonnées accessibles aux moteurs ;
- mesurer séparément crawl, indexation, citation, referral, activation et
  revenu ;
- ne jamais promettre un classement ou une citation IA.

Sources éditoriales de départ : recommandations d’activité physique de l’OMS,
position stand ACSM 2026 et recherches primaires déjà consignées dans la
doctrine. La formulation « un peu vaut mieux que rien » ne doit jamais devenir
« cinq minutes remplacent tout le reste ».

## Protocole design et QC

### Avant les maquettes

1. valider ce brief et les décisions encore ouvertes ;
2. écrire les contrats des surfaces de décision ;
3. fabriquer deux directions visuelles sous forme d’images isolées ;
4. faire choisir une direction par Yann ;
5. extraire un contrat visuel explicite ;
6. seulement ensuite, implémenter et comparer le rendu réel à la référence.

### Gates avant TestFlight

- **Foundation :** utilisateur, job, périmètre, données, sources et exclusions ;
- **Decision/intelligibilité :** état, action, conséquence, limites et recovery ;
- **Product :** oracle moteur, parcours complet, interruption, correction et
  confidentialité ;
- **Expérience :** mobile, VoiceOver, Dynamic Type, réduction du mouvement,
  contenus longs et usages d’une main ;
- **Distinction :** aucune copie générique de dashboard fitness, identité reliée
  au calme et à la progression ;
- **Risk/truth :** claims santé, douleur, étapes de vie et limites ;
- **Anti-sur-ingénierie :** dépendances, abstractions et services justifiés par
  un problème mesuré.

## Phases proposées

### Phase 0 — contrats et preuve de persistance

Contrats de décision, contrat moteur et oracle déterministe terminés : 45
fixtures structurelles, 18 règles et 8 configurations moteur candidates. Le
spike SwiftData valide la persistance locale, la migration, le conflit
deterministe, le rollback, la restauration et la suppression. La preuve
CloudKit distante entre deux simulateurs signes est `GO`, y compris conflit,
tombstone, suppression dure et conservation locale apres suppression cloud.
La coque structurelle dispose de preuves Simulator ; la direction visuelle
finale reste volontairement en attente du protocole image-first et du choix de
Yann.

### Phase 1 — fondation native

Projet SwiftUI, modèle SwiftData et moteur Swift pur créés. Les fixtures de
référence sont importées et leur parité est prouvée par le package et la coque.

### Phase 2 — expérience

Explorer deux directions visuelles, choisir et extraire le contrat visuel.
Prototyper ensuite le parcours iPhone principal contre les contrats de décision
déjà validés.

### Phase 3 — produit iPhone

Implémenter le parcours complet, la reprise, les timers, HealthKit, les
notifications contextuelles et l’accessibilité. Prouver le parcours sur
simulateur avant toute signature.

### Phase 4 — validation de sortie

Test sur iPhone physique, archive signée, TestFlight technique restreint,
validation des achats et correction des défauts de compréhension ou de moteur.

### Phase 5 — acquisition et sortie

Construire le site, l’outil matériel et le premier corpus sourcé ; soumettre
l’app seulement lorsque son utilité mobile et sa récupération sont prouvées.

## Décisions de produit et hypothèses de lancement

1. **Nom public retenu : La Bonne Séance.** OpenCadence reste temporairement le
   nom interne du dépôt et du prototype. Le site et l’App Store utilisent La
   Bonne Séance, sous réserve des derniers contrôles de marque et de fiche store.
2. **Plateforme : SwiftUI natif.** Le prototype web reste une référence de
   comportement, pas le socle de l’app.
3. **Matériel : cible maison complète.** Une catégorie n’apparaît dans
   l’onboarding V1 que lorsque ses configurations, mouvements illustrés et cas
   de référence sont tous prêts ; la promesse publiée correspond toujours au
   périmètre réellement validé.
4. **Durées : 20, 30 ou 45 minutes.** Chacune possède un budget et une logique
   propres ; la durée annoncée est un contrat.
5. **Modèle commercial confirmé le 7 septembre 2026 : une première séance complète gratuite, puis un achat unique à 59,99 € pour un accès à vie, sans abonnement.** L’offre apparaît lors de la prochaine demande explicite de séance. Le montant affiché provient de StoreKit pour le pays du compte Apple. Le produit non consommable local est `fr.labonneseance.lifetime` ; sa configuration dans App Store Connect et les tests Sandbox restent à vérifier avant diffusion.
6. **Promesse de reprise : retrouver la bonne séance sans engagement récurrent.** Une absence ne crée ni retard ni séance à rattraper. L’achat peut être restauré avec le même compte Apple ; un achat remboursé ou révoqué ne donne plus accès aux nouvelles séances. Le travail enregistré reste conservé.

## Sources techniques et produit

- [Apple — SwiftUI](https://developer.apple.com/swiftui/)
- [Apple — SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple App Review Guidelines — 4.2 Minimum
  Functionality](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)
- [ACSM Position Stand 2026 — prescription de l’entraînement en
  résistance](https://pubmed.ncbi.nlm.nih.gov/41843416/)
- [OMS — recommandations d’activité physique](https://www.who.int/news-room/fact-sheets/detail/physical-activity)
- [`80-20-DOCTRINE.md`](80-20-DOCTRINE.md)
- [`FEMALE-ADAPTATION.md`](FEMALE-ADAPTATION.md)

## Prochaine action unique

Concevoir puis implémenter le parcours iPhone défini dans
`qc/decision-surfaces/ios-first-session-paywall-return.json` : première séance,
bilan, aperçu de l’adaptation suivante, achat/restauration et reprise après une
absence, sans retirer l’accès à l’historique déjà acquis.
