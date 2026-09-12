# Durée automatique et questionnaire V2 — proposition à valider

7 septembre 2026. Proposition de traduction dans le moteur, non activée. Le principe « l’app décide » est acquis.

## Politique proposée

1. Construire la séance à partir des quatre familles repères disponibles : tirer, pousser, dominante genou, dominante hanche. Conserver la sélection, les substitutions et les exclusions actuelles selon matériel, soutiens, historique et périmètre.
2. En séance normale, utiliser le volume haut prévu par le catalogue pour chacun de ces repères — généralement trois séries. S’il manque une famille faisable, ne pas inventer un remplacement ni compenser par du volume supplémentaire.
3. Pour cette première politique automatique, ne pas ajouter de complément ni de cardio uniquement pour remplir une durée. C’est le choix de périmètre proposé, à approuver avec la politique.
4. En séance allégée, deux séries par repère disponible. Conserver les prescriptions prudentes de la recalibration de reprise ; ne pas augmenter simultanément son volume ou ses charges.
5. Calculer l’estimation après la construction du programme, avec les coûts du catalogue, les deux côtés lorsque requis, les repos et les transitions. L’interface n’exige plus de choisir une durée ; elle présente le programme et sa durée estimée.
6. Le dépassement de l’estimation ne retire aucun travail non commencé. L’utilisateur peut toujours terminer volontairement, faire une pause ou signaler une douleur ; les protections existantes restent prioritaires. L’estimation n’est pas une échéance.

Exemple de structure : quatre repères disponibles donnent normalement douze séries ; une séance allégée en donne huit. La durée varie avec les mouvements retenus, leurs doses et leurs repos. Aucun chiffre fixe de minutes ne doit devenir une promesse produit.

## Compatibilité de mise en œuvre

Persister une politique explicite de temps dans le snapshot V2 : `automatic` ou `chosen`. L’absence de ce champ désigne le comportement historique `chosen`. Les séances déjà commencées conservent intégralement leur plan et leur gestion du temps ; aucune régénération à la migration. Les futurs appels V2 en mode automatique évitent les boucles de remplissage du budget et la suppression de travail pour dépassement. Le chemin V1 reste inchangé.

Avant activation : vérifier qu’un dépassement n’enlève aucune série en mode automatique, qu’une ancienne séance conserve son comportement, que les quatre familles ne sont retenues que si faisables, que le mode allégé respecte son volume, et que douleur/pause/reprise/arrêt volontaire continuent de fonctionner. Vérifier enfin le parcours réel sans sélecteur de durée.

## Questionnaire de calibration

Le questionnaire haut/bas du corps actuel alimente V1 ; le bridge V2 ne transmet pas ces réponses au moteur. Proposer une garde dépendant explicitement de la version du moteur : questionnaire requis selon les règles existantes en V1, supprimé du démarrage V2.

Ne supprimer aucune réponse stockée. Conserver leur accès dans les paramètres lorsqu’elles existent et leur usage V1. Préserver en V2 les déclarations de matériel, de soutiens et de périmètre, ainsi que la confirmation explicite de la charge réellement choisie avant le départ. Le retrait du questionnaire ne doit pas être confondu avec le mécanisme de recalibration après une interruption de pratique, qui reste utile et conservé.

Avant activation : à inventaire, historique et soutiens identiques, démontrer l’identité des décisions V2 avec réponses absentes, foundation ou established ; vérifier que V1 conserve ses exigences. Un échec d’écriture ne doit jamais valider une étape ou démarrer une série.

## Arbitrage demandé

Valider ce paquet précis : quatre repères au volume catalogue, deux séries en allégé, pas de complément/cardio ajouté dans cette première politique, durée informative sans coupure ; retrait du questionnaire uniquement du démarrage V2 avec conservation des données et du comportement V1.
