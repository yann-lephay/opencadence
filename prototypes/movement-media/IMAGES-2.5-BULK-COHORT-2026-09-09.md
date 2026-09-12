# Images 2.5 bulk — cohorte stop-motion du 9 septembre 2026

Statut : prototypes de revue locale. Aucun manifeste produit, média embarqué ou
catalogue de validation n'est modifié.

Aperçu de contrôle à quatre temps par mouvement :
`IMAGES-2.5-BULK-COHORT-CONTACT-SHEET.jpg`.

## Décision de méthode

La formule retenue pour cette cohorte est une seule génération en planche 3 × 3
pour toute la phase aller, puis la réutilisation exacte des poses dans l'ordre
inverse. Il n'y a ni interpolation anatomique, ni seconde génération pour le
retour, ni duplication présentée comme une nouvelle pose.

Le prompt complet de référence se trouve dans
`supported_one_arm_row/images-2.5-test-2026-09-09/bulk-v01/README.md`.
Pour chaque exercice, le même contrat a été conservé avec quatre substitutions
explicites : nom du mouvement, position de départ, position finale et liste des
seules articulations autorisées à bouger.

Formule courte réutilisable :

```text
Create one clean 3 by 3 contact sheet containing exactly nine equal square
animation frames, read left to right and top to bottom. Frame 1 is the start;
frame 9 is the controlled end position; frames 2 through 8 are evenly spaced.
Every adjacent frame must show a small, clearly visible progression, with no
duplicates or near-duplicates. Lock identity, body proportions, clothes,
support points, equipment, environment, light, camera, crop, scale and style.
Only [BODY PARTS] may move along [MOTION PATH]. No text, arrows, labels,
watermark, camera drift, body drift, morphing, extra limbs or added equipment.
```

Contrats de mouvement ajoutés lors du deuxième lot :

| Mouvement | Départ → arrivée | Éléments autorisés à bouger | Invariants renforcés |
| --- | --- | --- | --- |
| `glute_bridge` | bassin au sol → alignement épaules-hanches-genoux | bassin et torse comme un seul bloc | pieds, épaules, tête, bras et paumes fixes ; pas d'hyperextension lombaire |
| `incline_push_up` | bras tendus → poitrine proche du banc | flexion symétrique des coudes et translation du corps rigide | mains, pieds et banc fixes ; ni bassin creusé ni bassin relevé |
| `seated_dumbbell_overhead_press` | haltères aux épaules → haltères au-dessus des épaules | extension symétrique des coudes | assise, pieds, tête et buste fixes ; poignets neutres et haltères identiques |
| `squat` | debout → cuisses proches de la parallèle | flexion coordonnée des hanches et genoux | pieds et talons fixes, genoux dans l'axe des orteils, mains jointes stables |

## Candidats produits

| Mouvement | Poses aller retenues | Sortie | Revue visuelle |
| --- | ---: | --- | --- |
| `assisted_split_squat` | 9 | `assisted_split_squat/review-images25-bulk-v01/assisted_split_squat_review_images25_bulk_v01.mp4` | progression lisible, appuis et chaise stables |
| `bent_over_dumbbell_row` | 9 | `bent_over_dumbbell_row/review-images25-bulk-v01/bent_over_dumbbell_row_review_images25_bulk_v01.mp4` | tirage lisible, tronc stable |
| `chair_sit_to_stand` | 9 | `chair_sit_to_stand/review-images25-bulk-v01/chair_sit_to_stand_review_images25_bulk_v01.mp4` | amplitude complète et régulière |
| `dead_bug` | 7 distinctes / 9 cellules | `dead_bug/review-images25-bulk-v02/dead_bug_review_images25_bulk_v02.mp4` | les deux côtés controlatéraux sont montrés en 13 étapes ; le même neutre est réutilisé à la transition et à la fermeture pour supprimer le micro-saut |
| `dip_bar_inverted_row` | 9 | `dip_bar_inverted_row/review-images25-bulk-v01/dip_bar_inverted_row_review_images25_bulk_v01.mp4` | traction complète, barres, prises et talons nettement plus stables que dans le candidat rejeté |
| `glute_bridge` | 9 | `glute_bridge/review-images25-bulk-v01/glute_bridge_review_images25_bulk_v01.mp4` | montée progressive, pieds, épaules et tête stables |
| `incline_push_up` | 9 | `incline_push_up/review-images25-bulk-v01/incline_push_up_review_images25_bulk_v01.mp4` | descente régulière, banc, mains et pieds stables, ligne du corps cohérente |
| `low_step_up` | 9 | `low_step_up/review-images25-bulk-v01/low_step_up_review_images25_bulk_v01.mp4` | montée complète, marche et cadrage stables |
| `seated_band_row` | 9 | `seated_band_row/review-images25-bulk-v01/seated_band_row_review_images25_bulk_v01.mp4` | tirage fluide, ancrage et pieds stables |
| `seated_dumbbell_overhead_press` | 9 | `seated_dumbbell_overhead_press/review-images25-bulk-v01/seated_dumbbell_overhead_press_review_images25_bulk_v01.mp4` | élévation symétrique, assise, pieds et buste stables |
| `single_arm_overhead_press` | 6 sur 9 | `single_arm_overhead_press/review-images25-bulk-v02/single_arm_overhead_press_review_images25_bulk_v02.mp4` | six poses réellement distinctes ; parmi quatre cellules initiales trop proches, une seule a été conservée |
| `split_squat` | 9 | `split_squat/review-images25-bulk-v01/split_squat_review_images25_bulk_v01.mp4` | descente régulière et appuis stables |
| `squat` | 9 | `squat/review-images25-bulk-v01/squat_review_images25_bulk_v01.mp4` | neuf profondeurs lisibles, pieds et mains stables, genoux cohérents |
| `supported_calf_raise` | 9 | `supported_calf_raise/review-images25-bulk-v01/supported_calf_raise_review_images25_bulk_v01.mp4` | continuité forte ; mouvement volontairement subtil à contrôler sur petit écran |
| `supported_single_leg_calf_raise` | 9 | `supported_single_leg_calf_raise/review-images25-bulk-v01/supported_single_leg_calf_raise_review_images25_bulk_v01.mp4` | élévation du talon ordonnée ; amplitude subtile à contrôler sur petit écran |
| `wall_hip_hinge` | 9 | `wall_hip_hinge/review-images25-bulk-v01/wall_hip_hinge_review_images25_bulk_v01.mp4` | charnière lisible, pieds stables, contact mural atteint |

Le rowing unilatéral initial reste le candidat pilote :
`supported_one_arm_row/images-2.5-test-2026-09-09/bulk-v01/supported_one_arm_row_bulk_v01.mp4`.

`push_up` n'a pas été régénéré : son candidat précédent avait déjà été accepté
visuellement et cette cohorte cible les boucles encore trop pauvres ou saccadées.

## Vérification technique

Les seize nouvelles vidéos sélectionnées ont été sondées après encodage : 612 × 612, H.264,
30 images/s, 120 images encodées et 4,00 secondes chacune. Les phases de retour
réutilisent les poses déjà générées. Les répétitions de pixels nécessaires au
30 images/s ne constituent pas de nouvelles poses.

Le premier montage `dead_bug/review-images25-bulk-v01` est conservé comme essai
rejeté : il enchaînait trois neutres générés séparément. La sélection v02 garde
une seule pose neutre et la réutilise exactement. Le dead bug est donc la seule
exception bilatérale au simple schéma « phase aller puis retour inversé ».

## Limites et prochaine porte

- Les planches sont des générations cohérentes, pas des copies pixel-stables de
  la première image fournie.
- La continuité visuelle est nettement meilleure, mais elle ne remplace pas une
  validation biomécanique humaine.
- Les deux variantes de mollets demandent une attention particulière sur mobile
  car leur amplitude est naturellement plus discrète.
- Aucun fichier de manifeste ou statut de publication ne doit changer avant la
  revue visuelle explicite des boucles finales.
