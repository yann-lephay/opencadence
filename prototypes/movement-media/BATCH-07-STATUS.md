# Lot média prototype 07 — état

Date : 4 septembre 2026.

Ce lot teste trois mouvements chargés dont les trajectoires doivent rester
faciles à lire image par image. Aucun média n'est intégré à l'application et
aucun statut du `MovementMediaManifest` n'est modifié.

| Mouvement | Démonstrateur | Poses aller | Durée | Verdict | Fichier retenu |
| --- | --- | ---: | ---: | --- | --- |
| `single_arm_overhead_press` | homme | — | — | REJETÉ POUR MONTAGE après V02 | aucun |
| `bent_over_dumbbell_row` | femme | — | — | REJETÉ POUR MONTAGE après V02 | aucun |
| `double_dumbbell_front_squat` | homme | 5 | 3,23 s | PASS PROTOTYPE | `double_dumbbell_front_squat_stopmotion_preview_v01.mp4` |

## Décisions

- Les deux essais du développé à un bras sautent de la position à l'épaule à
  l'extension sans fournir au moins cinq hauteurs distinctes. Aucun montage ne
  tente de masquer ce défaut.
- Les deux essais du rowing penché restent limités à quatre phases crédibles.
  Une cinquième microvariation n'est pas comptée artificiellement comme un
  palier.
- Le squat à deux haltères est volontairement arrêté avant les poses les plus
  profondes de la planche. La boucle conserve cinq positions contrôlées, les
  deux charges au rack et les appuis stables.
- Après deux échecs présentant le même défaut, la régénération s'arrête pour ces
  deux mouvements. Ils nécessitent une source plus contrôlable ou une future
  prise réelle.

Le seul fichier retenu est un prototype visuel. La validation professionnelle,
les posters, les fallbacks statiques, les textes accessibles et le paquet média
complet de release restent nécessaires.
