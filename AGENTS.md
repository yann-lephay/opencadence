# OpenCadence — instructions pour Codex

OpenCadence est une application Next.js locale, volontairement simple. Les données
personnelles restent dans `data/state.json` et ne doivent jamais être ajoutées à
Git, copiées dans une issue ou publiées.

## Installation

1. Vérifier que Node.js 20+ et npm sont disponibles.
2. Exécuter `npm install`.
3. Lancer `npm run dev`.
4. Ouvrir `http://localhost:3015`.
5. Laisser l’utilisateur terminer l’onboarding avant de personnaliser le
   programme.

Ne pas inventer de profil dans `data/state.json`. Le fichier est créé
automatiquement au premier lancement.

## Changements locaux et contributions publiques

Les changements locaux peuvent être réalisés à la demande de l’utilisateur. Si
une amélioration peut servir au dépôt public, lire `CONTRIBUTING.md`.

- La préférence du profil autorise seulement à proposer une contribution.
- Avant tout push ou toute PR, montrer le bénéfice, le résumé et la liste exacte
  des fichiers, puis demander un accord explicite pour cette PR.
- Ne jamais publier `data/state.json`, un profil, un historique, des symptômes,
  des photos ou des notes personnelles.
- Sans accord explicite, laisser le changement local et ne créer aucune branche
  distante.

## Règles produit

- Préserver une expérience calme et compréhensible.
- Le moteur est commun à tous les utilisateurs et suit les performances réelles.
- Ne jamais réduire automatiquement les ambitions selon le sexe.
- Le suivi menstruel est facultatif et fondé sur les symptômes, pas sur une
  phase de cycle supposée.
- Grossesse et post-partum ne doivent pas utiliser le moteur standard.
- Une modification de charge reste une recommandation confirmée par
  l’utilisateur.
- Tout nouvel exercice doit recevoir une planche WebP en quatre phases dans le
  même style et une entrée typée dans `ExerciseArt`.
- Contrôler la correction technique de chaque nouvelle planche avant de
  l’intégrer.
- Ne proposer que des exercices compatibles avec le matériel déclaré. Si aucun
  mouvement illustré sûr n’est disponible, l’omettre et proposer d’en créer un.

## Vérification

Exécuter au minimum :

```bash
npm run typecheck
npm run build
```

Pour une modification d’interface, vérifier aussi le parcours concerné dans un
navigateur sans écraser le journal réel de l’utilisateur.
