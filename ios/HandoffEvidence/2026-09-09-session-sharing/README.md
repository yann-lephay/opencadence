# Partage pseudonyme facultatif — 9 septembre 2026

Implémentation locale, pas de collecte active ni de serveur déployé. L'accès payant
est une condition supplémentaire au consentement, jamais un consentement implicite.

## Livré

- Invitation non bloquante à l'accueil, sans séance active, uniquement après droit
  payant chargé/vérifié. Refus mémorisé. Réglage accessible aux payants ; arrêt et
  suppression toujours accessibles pour un consentement existant, même sans droits.
- Consentement versionné dans le trousseau local ; secret aléatoire, aucune identité
  envoyée. Date au jour UTC. Nouvelles séances seulement, commencées après l'accord
  et enregistrées avec droit payant vérifié. Pas de rattrapage de la séance gratuite.
- Compte rendu à liste blanche, distinct du snapshot ; aucun champ de santé ou texte
  libre. Plan final conservé, travail confirmé et unités connues, pas de trace
  exhaustive de chaque correction ni de cause inférée.
- Champs SwiftData facultatifs pour l'éligibilité et la réception. Aucun changement
  du moteur, des repos, de la prescription ou du payload confirmé.
- Envois séquentiels au premier plan et reprise manuelle ; déduplication serveur.
  Arrêt immédiat, suppression différée hors réseau, token révoqué empêchant un envoi
  tardif de recréer les rapports. Réactivation sous un nouveau pseudonyme.
- Service Node séparé avec SQLite privé, rétention de rapports 90 jours, consultation
  opérateur en CLI. Aucune API publique de lecture ni outil d'ajustement individuel.

Instructions : `tools/session-sharing/README.md`.
Contrat : `qc/decision-surfaces/ios-session-sharing.json` validé PASS.

## Preuves

- **23 tests natifs / 3 suites PASS** : SessionSharingTests (5 nouveaux tests),
  PersonalizationNativeTests et PersonalizationCorrectionsTests.
  Log `/tmp/lbs-sharing-final-tests.log` ; résultat
  `/tmp/lbs-sharing-0909/Logs/Test/Test-OpenCadence-2026.09.09_09-54-49-+0200.xcresult`.
  Simulator dédié `1E3E60AE-7B9A-42DA-BD3E-83887C75BC20`, derived data `/tmp/lbs-sharing-0909`,
  scheme OpenCadence, `-parallel-testing-enabled NO`, sélection `-only-testing` de
  chacune des trois suites. Transport HTTP simulé par URLProtocol ; pas de serveur réel.
- **Test HTTP serveur PASS**, `node --test tools/session-sharing/server.test.mjs`,
  base temporaire détruite : accord requis, champs additionnels refusés, isolation,
  rejouabilité malgré clés JSON permutées, immutabilité, suppression SQL effective,
  révocation durable après redémarrage et purge après 91 jours.
  Log `/tmp/lbs-sharing-server-tests.log`.
- **611 clés de localisation PASS**, source FR, EN/ES/DE complets. Quatre entrées
  préexistantes réextraites par Xcode sans traduction complétées sans changer le FR.
- Vérifications demandées par le dépôt : `npm run typecheck` et
  `npm run build -- --webpack` **PASS** (logs `/tmp/lbs-sharing-typecheck.log`
  et `/tmp/lbs-sharing-web-build.log`). Aucun code web modifié.
- Build simulateur PASS. `consent.png` : capture native de la fixture DEBUG
  `-LBSSharingProof`, aucun journal ni trousseau utilisateur. Défilement réel jusqu'au
  bouton d'accord et au lien de confidentialité vérifié avec CUA. Ce n'est pas un
  essai utilisateur ni une recette VoiceOver, petits écrans ou grandes polices.
- Revue indépendante anti_overengineering **PASS** après correction de l'idempotence
  JSON. L'échec intermédiaire d'un test venait du conteneur SwiftData de test libéré
  trop tôt ; fixture corrigée et suites relancées avec succès.

## Limites avant activation

L'Info.plist n'a pas d'adresse `LBSSessionSharingURL` : aucune invitation ni collecte
réelle n'est activée. Hébergement privé à choisir, TLS/volume/logs à configurer et
confidentialité publique/déclarations de collecte à actualiser avant distribution.
Aucune action Apple, publication, commit ou push dans ce lot.

Le droit payant est contrôlé dans iOS, pas attesté par l'API serveur ; les données
reçues ne prouvent donc pas un achat et restent falsifiables par un client externe.
Le service SQLite de Node 22 utilise une API marquée expérimentale ; sa version
runtime doit être figée/testée avant hébergement. Pas d'observabilité ni sauvegarde
externe ajoutée. La politique des sauvegardes et logs hébergeur reste à configurer.

La chaîne complète iPhone → serveur HTTPS hébergé → consultation → suppression
reste à recetter avec des données fictives une fois l'adresse disponible.
Le build déjà soumis est inchangé. Les modifications concurrentes ont été conservées.
