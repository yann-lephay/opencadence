# Spike SwiftData / iCloud d’OpenCadence

Statut : `GO`

Ce spike répond à une seule question : peut-on proposer une synchronisation
iCloud privée et tardive sans mettre en danger l’historique local d’une personne ?
Il ne constitue pas le schéma définitif de l’app, mais la réplication CloudKit a
maintenant été prouvée entre deux simulateurs connectés au même compte iCloud.

## Décision technique candidate

Ne pas rouvrir le même fichier SQLite en remplaçant dynamiquement
`cloudKitDatabase: .none` par `.private(...)`. Apple documente ces deux modes,
mais ne garantit pas cette bascule tardive sur un store déjà rempli.

Le chemin testé est plus sûr :

1. conserver le store local original comme rollback ;
2. créer un second store destiné à CloudKit ;
3. copier les snapshots par identifiant logique ;
4. résoudre les doublons de manière déterministe ;
5. vérifier le nombre d’objets et un checksum avant de basculer l’app ;
6. rendre l’opération idempotente si elle est relancée.

Les suppressions sont représentées par un tombstone versionné pour éviter la
résurrection d’un objet lors d’un conflit. L’effacement final du store reste une
action distincte et explicitement confirmée.

## Ce qui est réellement prouvé

Commande locale :

```bash
swift test
```

Sept tests passent :

- réouverture d’un store local sans perte ;
- copie tardive vers un second store ;
- migration relancée sans doublon ;
- conflit déterministe, avec priorité au tombstone sur une égalité exacte ;
- persistance et relecture d’un tombstone après réouverture du store ;
- sauvegarde JSON triée, checksum, restauration et rejet d’une sauvegarde altérée ;
- suppression totale puis réouverture vide.

La bibliothèque compile également contre le SDK iOS Simulator :

```bash
swift build \
  --triple arm64-apple-ios17.0-simulator \
  --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
```

## Preuve CloudKit exécutée

Deux simulateurs iOS 26.5 ont été connectés au même compte iCloud. Le scénario
réel suivant est passé :

1. copie d’une source locale vers le conteneur CloudKit privé ;
2. import sur un second réplica initialement vide ;
3. écritures concurrentes de même révision depuis A et B ;
4. convergence vers `replica-b` avec le même résultat sur les deux réplicas ;
5. propagation d’un tombstone gagnant ;
6. effacement physique des 5 objets depuis B ;
7. destination vide sur A et B, avec la source locale de A toujours intacte.

Les journaux Core Data/CloudKit confirment les exports et imports utiles avec
`success: 1` et `madeChanges: 1`. Le conteneur de développement est vide à la
fin du test.

## Environnement constaté le 30 août 2026

- Xcode 26.6, SDK et runtime iOS 26.5 installés ;
- app-probe compilée et lancée sur iPhone 17 et iPhone 17 Pro simulés sous iOS 26.5 ;
- le probe est rebranché sur le package `CadencePersistenceSpike` afin de tester
  une source locale et une destination CloudKit séparées ;
- équipe Apple Developer configurée : `6UCVDB6GEG` ;
- identité Apple Development et profil automatique valides ;
- Bundle ID `fr.opencadence.CadenceCloudProbe` et conteneur privé
  `iCloud.fr.opencadence.CadenceCloudProbe` actifs ;
- build iPhone signé réussi ;
- test d’intégration iOS : 1/1 ; package Swift : 7/7.

Le prochain niveau de validation est une bêta sur deux appareils physiques avec
le schéma produit réel. Ce n’est plus un blocage de l’architecture.

## App-probe iOS

Le projet `CadenceCloudProbe/` est volontairement séparé de l’application web.
Il expose une source locale, sa copie vérifiée vers une destination configurée
pour CloudKit, un tombstone et la valeur canonique. Il utilise le Bundle ID
`fr.opencadence.CadenceCloudProbe` et le conteneur de développement
`iCloud.fr.opencadence.CadenceCloudProbe`.

## Critères de verdict

### `GO`

- les sept tests locaux restent verts ;
- l’app iOS signée exporte les données locales vers un conteneur privé ;
- une seconde installation reçoit les mêmes snapshots ;
- les conflits convergent vers la même valeur canonique ;
- la suppression converge sur les deux réplicas et la restauration locale reste vérifiée ;
- le store local rollback reste intact jusqu’à vérification.

### `LOCAL_ONLY`

- perte, duplication ou résurrection non récupérable pendant l’un des scénarios ;
- impossibilité de vérifier la migration avant bascule ;
- comportement CloudKit incompatible avec le modèle local-first sans ajouter une
  couche de synchronisation disproportionnée.

Une toolchain ou une signature absente produit `PENDING_CLOUD_PROOF`, pas
`LOCAL_ONLY`.

## Sources Apple

- [Synchroniser des données SwiftData entre les appareils](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [ModelConfiguration.CloudKitDatabase](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct)
- [Miroir Core Data avec CloudKit](https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit)
- [Synchroniser un store Core Data avec CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)
- [Supprimer les données persistantes SwiftData](https://developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app)
