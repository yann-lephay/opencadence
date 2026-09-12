# Lot média prototype 02 — état

Date : 4 septembre 2026.

Ce lot poursuit la validation du pipeline 4 × 4. Aucun fichier n'est intégré à
l'application et aucun statut du `MovementMediaManifest` n'est modifié.

| Mouvement | Démonstrateur | Poses aller | Durée | Verdict | Fichier retenu |
| --- | --- | ---: | ---: | --- | --- |
| `wall_hip_hinge` | homme | 7 | 3,60 s | PASS PROTOTYPE | `wall_hip_hinge_stopmotion_preview_v02.mp4` |
| `incline_push_up` | femme | 8 | 3,20 s | PASS PROTOTYPE | `incline_push_up_stopmotion_preview_v01.mp4` |
| `chair_sit_to_stand` | homme | — | — | REJETÉ POUR MONTAGE | aucun |
| `seated_band_row` | femme | 4 seulement | — | À CORRIGER | aucun |

## Ce que le lot établit

- Une planche 4 × 4 est un bon réservoir de candidats, pas une garantie de 16
  poses utilisables.
- La boucle doit être assemblée uniquement à partir des poses indépendamment
  validées ; le retour peut réutiliser l'aller en ordre inverse lorsque ce
  retour correspond réellement au mouvement.
- Une géométrie de support qui dérive impose une nouvelle source. Elle n'est
  pas réparée par recadrage, interpolation ou faux zoom.
- Un matériel physiquement cohérent ne suffit pas : une séquence de quatre
  états reste refusée si les transitions deviennent trop saccadées.

## Suite recommandée

Continuer avec les mouvements dont les appuis et accessoires peuvent être
verrouillés visuellement. Mettre `chair_sit_to_stand` en attente d'une capture
réelle ou d'une génération capable de conserver un décor de référence fixe.
Pour `seated_band_row`, produire les deux ou trois intermédiaires manquants à
partir de poses unitaires validées plutôt que régénérer une nouvelle boucle
complète.

Ces verdicts restent des validations de prototype visuel. Ils ne remplacent ni
la validation professionnelle du mouvement ni le paquet média final de
release (vidéo, poster, fallback et texte accessible).
