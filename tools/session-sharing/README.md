# Partage facultatif des séances — serveur installé, iOS non activé

## Parcours construit

L'invitation non bloquante apparaît à l'accueil, hors séance, une fois l'accès à
vie chargé et vérifié. « Non merci » la masque ; le réglage reste accessible aux
utilisateurs payants. Aucun accord précoché ni accès conditionné au partage.

Le consentement `session-sharing-2` crée un secret aléatoire dans le trousseau de
cet iPhone (non synchronisé). Le serveur n'en conserve que le hash, qui sert de
pseudonyme. Chaque séance reçoit un identifiant dérivé distinct de son ID local.
Le jour est en UTC, sans heure ni fuseau. Les séances commencées avant l'accord,
les anciennes séances et les séances enregistrées sans droit payant vérifié ne
sont jamais ajoutées rétrospectivement à la file. Les bilans interrompus sont inclus.
Un abandon sans bilan enregistré ne crée pas un compte rendu fictif.

La sauvegarde locale ne dépend pas du réseau. Les nouveaux champs facultatifs
`sharingEnrollmentID` et `sharedAt` marquent l'éligibilité et l'accusé de réception,
sans toucher au payload moteur. Envoi au retour au premier plan, après sauvegarde,
après accord ou via Réessayer. Pas de promesse d'envoi iOS en arrière-plan fermé.
Les comptes rendus trop anciens ne sont plus réessayés.

## Données exactes et limites d'analyse

`SharedSession` est une liste blanche : version de schéma, jour UTC de fin,
version de politique/catalogue, interruption, plan courant (mouvement, quantité,
cible, unité, kg, repos) et séries confirmées (mouvement, réalisé, cible au
commencement si connue, kg, repos observé si connu). Un retour facultatif structuré
peut compléter le rapport : appréciation et une précision fermée, sans texte libre.
Le serveur accepte les anciens rapports v1 sans retour mais refuse ce nouveau champ
sous l’ancien consentement.

Le plan est celui conservé en fin de séance, **pas une trace exhaustive de chaque
modification**. Les variantes/charges présentes et le travail confirmé permettent
une première lecture, pas la reconstitution certaine de l'intention ou de la cause
d'un changement. Ni score de douleur, profil, symptômes, sexe, âge, nom, e-mail,
identifiants de matériel, notes libres ni snapshot brut. Aucune commande distante
ne modifie le moteur ou la prescription individuelle dans ce lot.

Un historique de performances est pseudonyme, pas anonyme. Les paquets réseau
arrivent nécessairement avec une IP : ne pas la journaliser au proxy/hébergeur.
Le serveur n'utilise ni ne conserve l'IP dans son stockage applicatif.
Le droit payant est vérifié **par le client iOS**, pas par une nouvelle validation
serveur des reçus Apple. L'API n'est donc pas une preuve anti-fraude d'achat ; des
rapports forgés restent possibles. Ne pas tirer une mesure commerciale de ce dataset.

## Stockage et consultation opérateur

Service Node séparé ; ne jamais déployer le Next.js local et son `/api/state` pour
cette collecte. Node 22.14+ avec `node:sqlite` (API expérimentale sur cette version,
sans dépendance npm). Un processus, base SQLite privée, écritures synchrones courtes,
taille HTTP bornée et plafonds globaux/par participant. Aucune route GET de données,
aucune interface d'administration publique. Pas de token partagé embarqué dans l'app.

Exemple de lancement **sur une machine de test**, chemin privé hors dépôt :

```sh
LBS_SHARING_DB=/chemin/prive/session-sharing.sqlite node tools/session-sharing/server.mjs
```

Par défaut, écoute `127.0.0.1:3041`. Le conteneur utilise une interface privée Docker.
Voir [le déploiement](DEPLOYMENT.md) pour le serveur installé et le DNS/TLS restant.
Aucune URL de collecte n’est ajoutée au build iOS.

Sur le serveur, via son accès opérateur existant :

```sh
LBS_SHARING_DB=/chemin/prive/session-sharing.sqlite node tools/session-sharing/inspect.mjs
LBS_SHARING_DB=/chemin/prive/session-sharing.sqlite node tools/session-sharing/inspect.mjs <pseudonyme>
```

La première commande liste les pseudonymes, nombres et jours ; la seconde les
comptes rendus chronologiques. Ce résultat est privé : ne pas le copier dans Git,
une issue ou un rapport public. Pas de consultation ouverte aux participants tiers.

## Arrêt, suppression et conservation

Arrêt immédiat de nouveaux envois, y compris pendant une requête. La suppression
reste en attente locale jusqu'à réponse positive. Un hash révoqué est conservé
sans date de consentement ni séances pour empêcher un retry tardif de recréer des
données. Une réactivation crée un nouveau pseudonyme après suppression confirmée.
Suppression accessible même sans droit payant. Le journal local n'est pas effacé.

Purge horaire des rapports de plus de 90 jours et au démarrage du service. 90 jours
est une convention de minimisation choisie pour ce lot, pas un besoin scientifique.
Une copie locale unique est renouvelée quotidiennement quand le service tourne.
Suppression et purge invalident aussi cette copie avant confirmation. Elle protège
contre une corruption de la base, pas contre la perte du VPS entier. Une désinstallation
sans demande de suppression empêche le retry local ; la rétention serveur continue.

## Activation restante

1. Choisir le serveur privé, configurer TLS, volume, accès opérateur et logs.
2. Mettre à jour la politique publique de confidentialité et les déclarations de
   collecte avant distribution d'une version activée ; le texte actuel sans collecte
   ne décrit pas cette fonctionnalité. Faire vérifier la base de consentement et la
   conservation pour ces données de performances ; ce lot n'est pas une validation juridique.
3. Injecter `LBSSessionSharingURL` dans l'Info.plist **après** ces préparatifs.
   URL absente/invalide : pas d'invitation, pas d'accord activable, aucun envoi.
4. Recette iPhone → serveur de test → inspection → suppression, avec données fictives.

Le build déjà soumis n'est pas modifié par ces fichiers locaux. Le serveur est installé séparément ; aucun changement Apple ni collecte réelle
n’est activé dans l’application.

## Tests

`node --test tools/session-sharing/server.test.mjs` : consentement obligatoire,
validation stricte (données supplémentaires refusées), isolation, idempotence,
immutabilité, révocation avant/après inscription et après redémarrage.

`SessionSharingTests` : accès gratuit/configuration absente/refus d'écriture,
non-rétroactivité, suspension sans accès payant, suppression hors ligne, rapport
expurgé et envoi unique d'un bilan admissible. Compléter par les suites natives
existantes de préservation du travail confirmé et du repos.
