# Lot média prototype 01 — état

Date : 4 septembre 2026.

Ce lot valide le pipeline de production et de QC. Aucun fichier n'est intégré à
l'application et aucun statut du `MovementMediaManifest` n'est modifié.

| Mouvement | Démonstrateur | Poses aller | Durée | Verdict | Fichier retenu |
| --- | --- | ---: | ---: | --- | --- |
| `supported_one_arm_row` | femme | 4 | 3,20 s | PASS PROTOTYPE | `supported_one_arm_row_stopmotion_preview_v04_balanced.mp4` |
| `push_up` | homme | 6 | 3,27 s | PASS PROTOTYPE | `push_up_stopmotion_preview_v02.mp4` |
| `dumbbell_romanian_deadlift` | femme | 8 | 3,23 s | À CORRIGER | `dumbbell_romanian_deadlift_stopmotion_preview_v02.mp4` |
| `squat` | homme | 6 | 3,27 s | PASS PROTOTYPE | `squat_stopmotion_preview_v02.mp4` |
| `glute_bridge` | femme | 6 | 3,13 s | PASS PROTOTYPE | `glute_bridge_stopmotion_preview_v01.mp4` |

## Réserves communes avant release

- atténuer ou retirer la trame sur le corps, les mains, les articulations et le
  matériel dans la vidéo active ;
- verrouiller les détails génératifs des mains, du visage, des pieds et des
  objets ;
- produire poster et fallback séparément à partir du master approuvé ;
- faire valider le mouvement par le professionnel compétent ;
- conserver ces fichiers hors du manifeste tant que ces preuves manquent.

Réserve propre au RDL : retirer les haltères inutilisés visibles dans le décor.

## Suite du catalogue

Le prochain mouvement prioritaire est `wall_hip_hinge`, suivi des régressions et
variantes matérielles du socle. Le même contrat QC s'applique : planche 4 × 4,
sélection stricte, boucle de 3 à 4 secondes, contrôle indépendant, aucun passage
automatique à `ready`.
