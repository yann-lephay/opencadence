# Retour facultatif après séance

Contrat validé avant implémentation par la revue indépendante : bilan existant,
aucun formulaire avant effort, accès payant vérifié + inscription partage version2,
première séance admissible puis séances4,7,10 (hypothèse produit, pas résultat scientifique).
Aucune réponse obligatoire. Retour à l’accueil enregistre le bilan sans réponse.

Une appréciation (convient/mitigé/pas vraiment), puis une précision facultative
(trop facile/difficile/répétitive/exercice mal compris). Une seule précision,
aucun texte libre, aucune cause déduite d’un arrêt. Possibilité de changer les
choix avant la sauvegarde ou de tout passer. Les choix attendent la sauvegarde du
bilan, conservés à l’écran si celle-ci échoue ; ils ne sont pas des brouillons
durables en cas de fermeture forcée avant sauvegarde.

Champ facultatif distinct dans CompletedWorkoutRecord, jamais dans le payload
moteur. Le rapport est immuable après sauvegarde et envoyé avec la séance. Les
réponses ne changent ni dose, ni variantes, ni repos, ni signaux de douleur.
Consentement version2 décrit les réponses ; version1 suspendue côté iOS et peut
être supprimée avant un nouvel accord. Serveur maintient version1 pour les anciens
rapports sans retour et refuse un retour avec cet ancien accord.

Consultation privée existante : `docker exec lbs-session-sharing node /app/inspect.mjs`
puis ajout du pseudonyme pour lire les séances datées et leur champ `review`.
Absence de réponse ne prouve ni satisfaction ni insatisfaction ; ne pas interpréter
une absence comme un zéro. Les fréquences de réponse ne représentent pas tous les
utilisateurs : partage facultatif, payants seulement.

Activation générale toujours en attente des déclarations Apple. Aucun endpoint
n’est ajouté au build distribué. Mise à jour de confidentialité requise pour les
appréciations structurées. Fixture DEBUG -LBSReviewProof : sans journal ni réseau.

## Vérifications

- 9 tests natifs PASS, dont 10 séances de cadence, exclusion gratuit/sans accord,
  ancien accord suspendu, payload moteur intact, sauvegarde et doublon immuable.
- 4 tests serveur PASS : anciens rapports, consentement 2 pour retour, whitelist,
  idempotence, effacement/révocation, sauvegardes et purge.
- 627 clés FR/EN/ES/DE complètes.
- CUA simulateur : choix Mitigé, précision Trop répétitive, passage sans réponse
  vérifiés. Fixture du composant, pas recette complète d’une séance à l’effort.
- Logs /tmp/lbs-review-native-final.log et /tmp/lbs-review-hosted.log.

Recette hébergée finale : PASS (1 test natif réel, 0,59 s), après un premier
échec HTTP503 pendant le redémarrage du service. Nouvelle exécution après health
healthy / réponse401 sans authentification. Inspection privée finale : `[]`.
Le consentement 2 et le rapport contenant review sont acceptés, puis supprimés ;
le même pseudonyme révoqué est rejeté. Typecheck/build web et build natif PASS.
Revue indépendante finale PASS.

Lecture opérateur : `fits` = convenait, `mixed` = mitigé, `notFit` = pas vraiment.
Les raisons sont déclarées, pas inférées : `tooEasy`, `tooHard`, `repetitive`,
`unclear`. Lire ces réponses avec le plan et le travail confirmés ; comparer avant
une correction du moteur, sans conclure à une cause certaine à partir d’un retour.

Confidentialité complétée en FR/EN/ES/DE, commit site `1aa166e`, puis présence
des quatre mentions vérifiée sur les URL publiques. Déclarations Apple préparées
avec la catégorie supplémentaire Other User Content, non saisies (session expirée).
Aucun build iOS téléversé ni collecte utilisateur activée.
