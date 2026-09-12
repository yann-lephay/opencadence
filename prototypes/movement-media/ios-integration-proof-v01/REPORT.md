# Intégration iOS des démonstrations — 6 septembre 2026

## Périmètre

42 démonstrations visuellement acceptées par Yann intégrées localement, sans
modification du moteur, des règles de progression, de la persistance ou des
abonnements. Pas de publication, commit, push ou envoi TestFlight.

Source exacte : `../ios-accepted-selection-v01.json`. Elle inclut les dernières
corrections utilisateur (charnière KB, pied du RDL décalé, développé unilatéral,
mollets, rowing inversé à deux poses/deux cycles). Ne pas revenir aux anciens
essais encore référencés dans le catalogue de production historique.

126 ressources : 42 H.264, 42 posters WebP, 42 alternatives statiques WebP.
Total : 21 053 472 octets. Copie binaire sans réencodage ni nouvelle génération.
`node scripts/sync-ios-movement-media.mjs --check` : PASS, tous les fichiers
correspondent aux sources, décodage FFmpeg intégral effectué.

## Lecture

- Lecteur commun à tous les mouvements, ressources Bundle locales uniquement.
- Pause/relecture accessibles, pause respectée lors d'un changement de politique.
- Suspension en arrière-plan ; aucune prise de contrôle de la session audio.
- Réduire les animations : alternative statique, lecture uniquement sur demande.
- Économie d'énergie : pas de boucle continue.
- Gainages avant, incliné et latéral : poster fixe, pas de faux mouvement animé.
- Descente de traction : lecture unique, relecture explicite.
- Échec vidéo : maintien d'une alternative statique.

## Vérifications

- Suite Xcode Debug sur iPhone 17 / iOS 26.5 : réussite (journal local
  `/private/tmp/lbs-media-test-final.log`). Tests de toutes les ressources via
  AVFoundation et UIImage, politiques, relecture après fin, vidéo illisible,
  pause/reprise/background/changement de politique, plus tests moteur/parcours existants.
- Localisations : PASS, 389 clés, traductions EN/ES/DE complètes.
- Typecheck TypeScript : PASS.
- Build web : BLOQUÉ par l'environnement Turbopack (`binding to a port`,
  `Operation not permitted`), y compris après demande d'exécution escaladée.
  Aucun code web n'est changé pour contourner ce blocage hors périmètre.
- Revue anti-complexité : PASS après correction pause → changement de politique.
- Captures inspectées : `active-workout.png` (toutes commandes de séance visibles),
  `floor-press-playing.png` (vidéo dans AVPlayerLayer),
  `floor-press-reduce-motion.png` (poses fixes et lecture manuelle).
- `media-accessibility-text.png` : titre de test en taille accessibilité maximale ;
  le pictogramme trop grand observé a ensuite été borné à 18 pt dans sa cible 44 pt.
  Cette capture documente l'observation avant la correction, pas une validation finale.
- Captures de fin de traction et gainage non retenues : alerte système de compte
  Apple dans le simulateur. Aucun identifiant ou compte modifié pour la contourner.

## Limites explicites

Statut `reviewedPreview`, jamais `ready`. `releaseIsComplete` reste faux.
L'accord visuel utilisateur et le décodage ne prouvent ni maîtrise biomécanique,
ni innocuité, ni droits de diffusion. Les assemblages de poses ne sont pas des
captations continues. Certaines exceptions acceptées comportent deux poses.

Restent séparés : validation professionnelle du mouvement et des textes,
droits des médias/références (notamment référence du rowing inversé), relecture
des alternatives accessibles et essai VoiceOver sur appareil réel. Pas de test
complet physique, clinique, de batterie ou de toutes les tailles d'iPhone ici.
