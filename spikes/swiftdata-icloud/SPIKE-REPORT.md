# Rapport de décision — SwiftData / iCloud

Date : 30 août 2026  
Verdict actuel : `GO`

## Résultat

La persistance locale, l’activation tardive par copie vérifiée, la résolution de
conflit, le rollback, la restauration et la synchronisation privée sont
faisables avec SwiftData et CloudKit sans dépendance additionnelle. Le package
compile en Swift 6 pour une cible iOS 17+ et le probe signé compile pour iPhone.

La preuve distante a été exécutée entre deux simulateurs iOS 26.5 connectés au
même compte iCloud. Export, import, conflit concurrent, tombstone et effacement
physique ont convergé. Après l’effacement distant, le réplica A conservait sa
source locale (`1`) avec une destination CloudKit vide (`0`).

La bascule directe du même store `.none` vers `.private(...)` n’est pas retenue :
elle n’est pas garantie par la documentation Apple et ne fournit pas un rollback
suffisamment sûr pour un historique d’entraînement.

## Matrice de preuve

| Scénario | Statut | Preuve |
|---|---|---|
| Store local après relance | PASS | Test SwiftData sur disque |
| Activation tardive | PASS local | Copie vers un second store, source intacte |
| Relance de migration | PASS | Même nombre et même checksum |
| Conflit de révision | PASS local | Résolution déterministe |
| Tombstone contre donnée vivante | PASS local + CloudKit | Tombstone gagnant sur égalité exacte et propagé aux deux réplicas |
| Sauvegarde et restauration | PASS | Checksum et rejet d’altération |
| Suppression après relance | PASS local | Store vide après réouverture |
| Compilation iOS | PASS | Simulateur et build iPhone signé avec provisioning automatique |
| App-probe sur simulateur | PASS local | Lancement réel sur iPhone 17 / iOS 26.5 |
| Flux local vers destination séparée | PASS local | Dans l’app simulée : source `0 → 1`, destination `0`, puis copie vérifiée `1 / 1` |
| Intégration du moteur dans l’app | PASS | Test iOS du contrôleur : 1/1 ; package Swift : 7/7 |
| Export CloudKit privé | PASS | Export Core Data/CloudKit `success: 1`, `madeChanges: 1` |
| Import sur second réplica | PASS | Store initialement vide, import `success: 1`, `madeChanges: 1` |
| Conflit CloudKit réel | PASS | Écritures A et B de révision 50 ; les deux réplicas choisissent `replica-b` |
| Tombstone CloudKit réel | PASS | Tombstone de révision 50 reçu et choisi sur les deux réplicas |
| Suppression CloudKit réelle | PASS | 5 objets supprimés sur B, destination `0` sur A et B ; source locale A intacte |

## Probe iOS créé

Le projet isolé se trouve dans `CadenceCloudProbe/`. Il utilise le Bundle ID
`fr.opencadence.CadenceCloudProbe` et le conteneur de développement
`iCloud.fr.opencadence.CadenceCloudProbe`. Le probe n’utilise pas les données de
l’application web et ne constitue pas l’application iOS finale.

Commande de validation locale :

```bash
xcodebuild \
  -project CadenceCloudProbe/CadenceCloudProbe.xcodeproj \
  -scheme CadenceCloudProbe \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath CadenceCloudProbe/.derived-data \
  -only-testing:CadenceCloudProbeTests test
```

## Défaut détecté pendant la preuve

Le premier test distant du tombstone a révélé une collision de nom : la propriété
SwiftData `isDeleted` entrait en conflit avec l’état interne de suppression de
l’objet géré. La valeur était écrite en base, mais relue comme une donnée vivante.

Le champ stocké a été renommé `tombstone`, sans changer l’API métier
`SnapshotValue.isDeleted`. Un test de persistance après réouverture protège ce
cas. Le scénario a ensuite été rejoué et a convergé sur les deux réplicas.

## Portée du `GO`

Le `GO` valide l’architecture local-first suivante pour l’application iOS :
store local conservé comme rollback, second store CloudKit, copie vérifiée,
résolution déterministe et tombstones versionnés. Il ne fige pas encore le
schéma produit final et ne remplace pas une bêta sur deux appareils physiques
avant publication.
