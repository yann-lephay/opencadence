# Politique de dose : contrat, comparaison et recommandation

7 septembre 2026 — exécution locale sur faits synthétiques. Aucun changement de prescription par défaut dans l’app, aucun commit, push ou publication.

## Recommandation

Retenir **deux séries stables comme socle ordinaire de la prochaine intégration automatique**, avec les modes explicites et les protections existants. Construire le programme puis estimer sa durée ; ne jamais remplir un budget ni retirer du travail au dépassement. Cette base est informée par ACSM 2026, pas un optimum individuel.

Ne pas activer d’ajout automatique de séries sur réussite, fréquence, cible plafonnée ou stagnation supposée. Les sources et la simulation ne fournissent pas de déclencheur individuel défendable. Conserver les progressions de répétitions/charge comme conventions de programmation explicables : l’étude Chaves ne valide pas les seuils exacts du moteur.

Le correctif empêchant la reprise d’une hausse ancienne jamais exécutée est suffisamment étayé comme **correction factuelle à intégrer avec la durée automatique**. Il est testé dans les deux voies expérimentales ; le dispatcher actuel de l’app reste inchangé et conserve donc son comportement antérieur tant que cette intégration n’a pas lieu.

Les préférences persistantes de volume et les ajustements locaux sur déclaration explicite restent **expérimentaux quant à leur utilité réelle**. Ils fonctionnent, mais ce banc ne justifie ni une nouvelle couche d’adaptation physiologique, ni des questions périodiques « trop facile » ou « entraînement ailleurs ».

## Contrat et recherche

[Contrat de décision D01–D11 et matrice des sources](../../../docs/80-20-DOSE-EXPERIMENT.md) : faits requis, contexte/provenance/date, décisions, raisons, limites, conventions, absence de réponse et tests.

Le rapport joint a été lu intégralement. Ses contraintes temporelles ont été explicitement écartées. ACSM, Pelland, Chaves, Halonen et Lopez ont été consultés en textes complets accessibles, avec les routes alternatives et limites d’accès documentées. Les suppléments et toutes leurs études incluses ne sont pas revendiqués comme audités.

Trois nuances changent le contrat :

- ACSM soutient deux séries comme recommandation générale, sans nombre optimal personnel. Pelland porte sur le volume hebdomadaire moyen ; aucun déclencheur individuel 2→3 n’en découle.
- Chaves compare répétitions/charge à quatre séries, sur extension du genou et jusqu’à l’échec. L’orientation est utile ; transposer ses résultats en règle exacte pour deux séries domestiques sans mesure d’effort ne serait pas justifié.
- Halonen étudie un arrêt réel d’entraînement. Une absence d’enregistrement ne prouve ni arrêt, ni perte de capacité. Les performances effectuées ailleurs restent inconnues si elles ne sont pas fournies.

La divergence ACSM/Pelland sur un éventuel plateau hypertrophique est conservée dans le registre ; aucun plafond hebdomadaire prétendument scientifique n’est codé.

## Ce qui est implémenté

La candidate appelle la sélection, la progression, la recalibration, le coût temporel et les protections du moteur Swift existant. Son registre local distingue **préférence choisie**, dernière prescription et **travail effectivement confirmé**. Il n’est pas branché à la persistance de l’app.

- Sans choix pertinent : volume stable, deux séries en l’absence de préférence compatible.
- Découverte choisie et reprise explicitement choisie : une série temporaire ; la préférence ordinaire est conservée. L’absence dans l’app ne sélectionne pas ces modes.
- Quantité excessive déclarée : une série locale en moins, sans interpréter une interruption inconnue comme fatigue.
- Difficulté excessive dès le départ : recalibration locale de difficulté, sans retirer une série pour masquer le problème.
- Autre volume historique : faits conservés ; adoption seulement comme préférence explicitement nommée, avec preuves comparables. Deux expositions et la fenêtre existante de 30 jours sont des conventions de vérification, pas des mesures de tolérance. Une preuve sans identité suffisante reste un fait historique mais ne compte pas comme deux expositions distinctes.
- Hausse explicite ou retour au volume ordinaire : difficulté précédente exactement conservée si comparable ; hausse différée sans base valide. Aucun changement simultané de volume et charge/variante.
- Trop facile au plafond : raison de limite du matériel, sans séries compensatoires ni conversion inventée.

Les réponses périmées, ambiguës ou incompatibles ne sont pas utilisées. Des événements copiés ne comptent pas comme deux expositions. Les dates sont comparées chronologiquement, y compris avec des fuseaux différents. Une indisponibilité temporaire d’un contexte non sélectionné ne supprime pas sa préférence.

## Défaut reproduit et corrigé

Le moteur de progression écrivait une référence prospective pouvant être reprise des mois plus tard sans avoir été exécutée. Exemple réel du simulateur, graine 6, mêmes événements avant/après dans les deux politiques :

| Étape | Avant correction | Après correction |
|---|---|---|
| Jour 25, confirmations | 2 ×12 à 6 kg | Identiques |
| Jour 119, retour sans choix de recalibration | 2 ×8 à 8 kg jamais exécutés, référence à reconfirmer | **2 ×12 à 6 kg effectivement confirmés**, référence à reconfirmer |
| Jour 121, après confirmation du jour 119 | 2 ×9 à 8 kg | 2 ×8 à 8 kg, nouvelle proposition après cette confirmation |

Le correctif commun n’est appliqué qu’aux voies expérimentales. Une référence déjà confirmée reste conservée ; sans détail admissible, l’incertitude demeure et aucune performance n’est inventée. Le mode de reprise choisi conserve son traitement distinct.

Les premières matrices sont gardées sous `before-*`. Les mêmes profils, graines et paramètres sont rejoués après correction. Aucun seuil ou taux de réussite n’a été ajusté sur le contrôle.

## Comparaison de 24 semaines

21 profils ×5 graines ×2 politiques = **210 trajectoires d’exploration**, puis **210 de contrôle**. Les critères et empreintes des sources sont dans `protocol.json` et `before-protocol.json`. Les événements exogènes, questions et réponses sont identiques entre bras ; la référence ne consomme pas le registre de dose de la candidate.

Contrôle graines 6–10, après correction :

| Mesure synthétique | Référence stable 2 | Candidate |
|---|---:|---:|
| Séances générées | 6780 | 6780 |
| Séries prescrites | 54240 | 54200 |
| Séries confirmées | 53273 | 53233 |
| Interruptions sans cause connue | 164 | 164 |
| Arrêts de sécurité | 49 | 49 |
| Retraits temporels / dettes / invariants signalés | 0 | 0 |

Ces agrégats ne désignent aucun gagnant. Les propositions de progression de charge passent de 1450 à 1495 après la correction commune : certaines hausses sont proposées de nouveau après une confirmation actuelle. Ce compteur n’est ni un nombre de nouveaux gains physiques ni un critère de succès.

Sur les **1356 paires de séances tracées de la graine 6**,255 plans diffèrent, sans différence de sélection des mouvements :

| Cas | Décision utile observée |
|---|---|
| Quantité excessive | Une série locale durable au lieu de deux ; les autres mouvements sont conservés |
| Préférence historique 3 explicitement choisie | Trois séries locales, hausse initiale sans hausse de difficulté |
| Difficulté initiale excessive | Difficulté réduite, nombre de séries inchangé |
| Découverte | Une série temporaire, retour à deux sans hausse simultanée de difficulté |
| Reprise choisie | Volume temporairement réduit puis préférence ordinaire retrouvée |
| Cible atteinte sans effort connu / plafond matériel | Pas d’ajout de séries ni de diagnostic de stagnation |
| Fréquence variable | 8,48,16 séances dans trois blocs de huit semaines ; deux séries par mouvement, sans dette |
| Travail partiel / données manquantes / référence 3 sans réponse | Aucun volume réalisé adopté automatiquement |
| Entraînement extérieur inconnu ou déclaré | Aucun volume modifié par la seule information d’absence dans l’app |
| Changement de matériel | Substitutions comparables entre les deux bras ; pas de transfert fictif |

Le gel d’une progression lors d’un retour au volume ordinaire peut décaler des prescriptions ultérieures. Les 255 différences ne sont donc pas 255 interventions distinctes ou 255 améliorations.

## Questions : utilité observée, pas compteur flatteur

Dans les traces d’une graine :34 questions simulées,30 réponses consommées. **Quatre réponses locales changent immédiatement la prescription** : découverte, quantité excessive, difficulté initiale excessive, préférence historique. Le retour choisi change également la séance, mais par le mode global ; la réponse « pas d’entraînement ailleurs » n’est pas la cause de cette différence.

Les 24 réponses « trop facile » ne changent pas la prescription face au comparateur ;19 produisent un signal de plafond. Les cinq autres n’ajoutent aucun effet observé. « Entraînement ailleurs » ne change pas la prescription non plus. Ces cas ont été simulés pour éprouver leur utilité ; ils ne justifient pas des questions systématiques dans le produit. Garder le signal ciblé de limite et les déclarations explicites utiles suffit ici.

Les 150 réponses consommées et 55 changements de volume par lot ne signifient pas 150 décisions utiles ni une efficacité physiologique démontrée.

## Plus petit test réel proposé

Un pilote en miroir sur **six adultes, trois semaines**, incluant des personnes qui reprennent et du matériel limité : comparer les deux propositions sur leurs séances réellement enregistrées, avec revue humaine avant toute modification de prescription. Ce format est une convention de faisabilité, pas une étude d’efficacité.

Observer seulement les ambiguïtés qui changent une décision : quantité ou difficulté, utilité d’une préférence conservée, compréhension de la hausse différée, durée estimée versus réelle. Retour bref lors de ces cas ; ne pas imposer un questionnaire quotidien. Les protections et gates existants, notamment avant bêta externe, restent applicables.

Continuer si les changements sont compris, souhaités et utiles face au socle stable, sans erreur de provenance ni intervention inexpliquée. Simplifier ou abandonner une branche si elle pose des questions sans changer une décision utile, reconduit du travail non confirmé ou confond préférence et capacité. Aucune conclusion sur force/hypertrophie ne peut venir de ce petit pilote.

## Vérifications et limites

- Moteur complet et régressions : `engine-tests.log` et `dose-tests.log`, réussis. Les tests couvrent l’oracle V1, V2, dates, comparabilité, mémoire, reprise et protections ; leur nombre ne définit pas la fin du parcours.
- `public-before.json` et `public-after.json` :60 sorties publiques identiques à l’octet. Aucune activation dans le dispatcher app, aucun changement de snapshot natif, confirmation ou gate.
- TypeScript et build webpack réussis. Aucune nouvelle interface ni validation visuelle revendiquée pour ce lot moteur.
- Revue indépendante anti-overengineering : **PASS** après correction de la mémoire, des identités de confirmations et du tri chronologique.
- Estimations temporelles fondées sur les coûts catalogue, sans validation chronométrique humaine nouvelle ni modèle physiologique. Les cibles de répétitions ne reparamètrent pas ces coûts automatiquement.
- Les répétitions simulées sont générées autour des consignes avec des probabilités fixées ; elles ne modélisent pas une capacité physiologique indépendante.
- Les tests natifs de persistance du lot précédent restent une preuve distincte ; ce lot vérifie le moteur et le simulateur, pas six mois d’utilisation humaine.

Preuves complètes : `summary.json`, `selected-trajectories.json`, archives `exploration.json.gz` / `control.json.gz`, leurs versions `before-*`, `return-before-after.txt`, `dose-policy.patch`. Données synthétiques uniquement, horloge virtuelle en 2027. Commandes reproductibles dans [le simulateur existant](../../../docs/80-20-SIMULATION.md).
