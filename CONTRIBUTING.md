# Contribuer à OpenCadence

Une copie locale appartient à son utilisateur. Il peut la modifier comme il le
souhaite et n’a aucune obligation de partager ses changements.

Lorsqu’une amélioration paraît réutilisable — nouvel exercice, prise en charge
d’un matériel, correction d’un mouvement ou amélioration du moteur — Codex peut
proposer d’en faire une pull request vers le dépôt public.

## Consentement obligatoire

Avant toute publication, Codex doit :

1. expliquer ce que l’amélioration apporte aux autres utilisateurs ;
2. montrer le résumé des changements et la liste exacte des fichiers ;
3. confirmer que `data/state.json`, le profil, l’historique, les symptômes, les
   photos et les notes personnelles sont absents ;
4. demander explicitement : « Veux-tu que je crée cette PR publique ? » ;
5. ne créer ni branche distante, ni push, ni PR sans réponse affirmative.

La préférence « me proposer de partager » enregistrée dans le profil autorise
uniquement Codex à poser cette question. Elle ne constitue jamais une
autorisation de publier.

## Nouvel exercice ou nouveau matériel

Une contribution doit contenir :

- le matériel nécessaire et une alternative lorsque c’est réaliste ;
- la cible de répétitions ou de temps, le repos et les consignes de sécurité ;
- la règle de progression ;
- une planche WebP en quatre phases, techniquement relue ;
- l’entrée typée correspondante dans `ExerciseArt` ;
- un test du parcours concerné dans une copie sans données personnelles.

Si le matériel déclaré n’est pas couvert, OpenCadence préfère omettre le mouvement
plutôt que d’en inventer un ou de recommander une charge indisponible.

## Vérification minimale

```bash
npm run typecheck
npm run build
```
