# Banc d’essai calibration V2 — 7 septembre 2026

Périmètre : un nouveau fichier de tests natifs seulement ; aucun changement de moteur, de parcours, de droits ou de données personnelles.

## Entrées exactes

- Date fixe : Unix 1 800 000 000.
- Deux familles : historique vide ; historique de deux séances V2 multi-mouvements synthétiques générées par le bridge à J−6 et J−3, 30 minutes, toutes séries prescrites confirmées, payloads construits par WorkoutHistoryBuilder. Aucune limitation/refus, aucun signal inhabituel ni périmètre clinique déclaré.
- Inventaire synthétique : poids du corps, 1 unité ; haltères réglables, 2 unités, 4/6/8/10 kg par unité, configurations pair/single/central/unilateral.
- Supports explicitement fournis par la fixture : wall_or_stable_plane, floor_allowed, stable_hand_support. Ces supports ne sont pas inférés pour une personne.
- Durées 20, 30 et 45 minutes × modes normal, light et recalibration.
- Pour chaque cas : référence sans réponse ni confirmation ; comparaison aux 4 couples foundation/foundation, foundation/established, established/foundation, established/established explicitement confirmés ; comparaison aussi à established/foundation non confirmé.
- Comparaison de PreparedWorkout complet : décision legacy exposée à l’UI et contexte V2 (plan, charges, raison/catégories de décision, durée/estimations, inventaire et supports snapshotés).

## Contrôles V1 et conservation

- Un UserSetupRecord synthétique en SwiftData strictement en mémoire demande toujours une calibration avec haltères réglables si aucune réponse explicite.
- Après réponses established/foundation datées, requiresCalibration devient false et usesExplicitCalibration reste true.
- Appel bridge V2 sans modification des réponses, date de confirmation, inventaire sérialisé, selectedDuration ou updatedAt.
- En productionV1, foundation/foundation et established/foundation produisent toujours des décisions distinctes et le reason code calibration.user_selected_variants ; aucune neutralisation silencieuse du comportement V1.
- Le choix explicite du flag runtime -OpenCadenceForceV1 conserve productionV1.

## Limite spécifique du volume historique

Cas de caractérisation ajouté : même premier mouvement issu du moteur, mêmes reps/charge/contexte/date, mais plan contrôlé de 1 série confirmée versus 3 séries confirmées. Les snapshots et payloads conservent leur volume distinct. Le test compare leur projection migratedV2History et la prochaine préparation complète. Il décrit le comportement actuel, sans inventer une politique de volume ni juger ce volume approprié. Les exécutions avec historique vérifient aussi que les références sont effectivement réutilisées (referenceStatus kept en mode normal) et que les payloadData restent inchangés.

## Résultats

**TEST SUCCEEDED**, sortie xcodebuild 0. Le log final compte 18 occurrences de cas réussis : les 9 cas paramétrés de la suite sont exécutés deux fois par la configuration du scheme. Aucun échec.

- 3 durées sans historique × 3 modes × 5 variantes de calibration comparées à absence = 45 égalités complètes.
- Même matrice avec deux séances confirmées = 45 égalités complètes supplémentaires.
- V1 : décisions foundation/foundation et established/foundation distinctes ; foundation-foundation-12 confirmé, reason code de calibration présent dans les deux.
- Garde setup V1 et non-mutation des réponses stockées en mémoire : PASS.
- Volume : 1 versus 3 séries confirmées produit des projections V2 égales et des prochaines préparations égales dans ce cas contrôlé. Les payloads sources conservent 1 et 3 séries. Cette égalité expose la limite actuelle de projection et ne signifie pas que les volumes se valent physiologiquement.

Log : /tmp/lbs-calibration-tests.log.
Résultat natif : /tmp/lbs-calibration-build/Logs/Test/Test-OpenCadence-2026.09.07_20-11-20-+0200.xcresult.
DerivedData isolé : /tmp/lbs-calibration-build. Destination demandée : 3D7896BF-4AC2-4F48-AFC8-8C3F0FB3FAEE ; Xcode exécute le test sur son clone de cet iPhone17.

Commande : xcodebuild -project ios/OpenCadence/OpenCadence.xcodeproj -scheme OpenCadence -destination 'platform=iOS Simulator,id=3D7896BF-4AC2-4F48-AFC8-8C3F0FB3FAEE' -derivedDataPath /tmp/lbs-calibration-build -only-testing:OpenCadenceTests/V2CalibrationEquivalenceTests test

## Limites

Ce banc teste l’équivalence du bridge pour des entrées contrôlées, pas l’efficacité, la sécurité clinique, l’adéquation des charges ni toute configuration de matériel/historique. Il ne valide aucune durée automatique : 20/30/45 sont ici des facteurs de test. Il ne modifie ni ne supprime la garde de calibration du parcours. Le contrôle de stockage utilise uniquement un conteneur mémoire et vérifie la non-mutation pendant l’appel ; il ne constitue pas une nouvelle preuve de migration ou reprise après arrêt du processus. Les données personnelles ne sont ni lues ni écrites.
