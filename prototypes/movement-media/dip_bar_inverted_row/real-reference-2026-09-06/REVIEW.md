# Deux poses guidées par une référence réelle

Source de mouvement : [SELF, Inverted Row](https://www.self.com/gallery/best-pulling-exercises), photographies Katie Thompson. Images0 et9 extraites du GIF public comme entrées effectives d'imagegen. Variante jambes tendues ; la variante genoux fléchis de Tarzan consultée n'a pas été utilisée.

Deux poses générées avec une autre personne, des vêtements vert/prune, un décor domestique crème/bois et un léger effet imprimé rétro. La vue reprend le léger trois-quarts de la référence, et non le profil strict précédemment essayé. Les demandes de génération exactes sont dans `generation.json`.

## Contrôle limité au prototype

- V01 : cadrage trop serré, conservée mais non retenue.
- V02 : chaussures et pieds des barres entièrement visibles ; les deux prises restent associées à leur barre ; bras plus tendus en bas et coudes pliés en haut, bassin décollé.
- Réserves : les deux images ne prouvent pas une transition cohérente ou des longueurs segmentaires identiques. La perspective masque une partie des membres éloignés. Position et dimensions du matériel devront être recalées/vérifiées avant animation, sans déformer le corps.
- Cette planche sert à la revue des deux positions par Yann. Aucune vidéo produite, aucune modification du catalogue, de l'application ou du manifeste iOS.
- Aucune validation professionnelle ou autorisation de publication. Les droits de la source ne sont pas présentés comme acquis et un changement de personnage/style ne constitue pas une garantie de droits pour une exploitation commerciale.

## Suite du 6 septembre : boucle candidate

Yann a accepté visuellement les deux positions V02 (« impeccable »), puis demandé la boucle. Cette acceptation ne porte pas sur les nouveaux intermédiaires.

Trois générations ont été tentées. Les deux premières sont rejetées (dérive du matériel / main éloignée manquante). La troisième utilise effectivement les images 3 et 6 de la référence réelle et la pose basse de marque. Les prompts complets sont dans `loop-generation.json`.

Livraison de contrôle : `../review-reference-loop-v02/dip_bar_inverted_row_review_reference_loop_v02.mp4`, 4 secondes, H.264, 612 × 612, 30 fps, sans audio. Quatre images sources sont affichées en sept étapes ; les images de montée sont réutilisées pour le retour. Ce ne sont pas douze poses distinctes : la première transition est très faible et la grande variation est concentrée entre les images 2 et 3.

Recalage global uniforme uniquement, puis recadrage commun 746 × 746 supprimant les bandes d'extension des bords de V01. Aucun membre n'est déformé séparément. Restent des variations des pieds des barres, du décor et des talons. Le montage est présenté comme essai à contrôler, pas comme démonstration finale validée. Application, catalogue et manifeste inchangés.

## Version retenue visuellement par Yann

Après comparaison, Yann a demandé uniquement les deux photos validées, puis deux cycles sur quatre secondes. Il a accepté explicitement `../review-reference-two-cycles-v01/dip_bar_inverted_row_review_reference_two_cycles_v01.mp4` (« ok on valide comme ça »). Cette version présente deux poses, quatre étapes d'une seconde. Retour exact enregistré dans `../review-reference-two-cycles-v01/user-acceptance.json`.

Cette acceptation remplace les essais précédents comme choix visuel pour ce mouvement, sans effacer leurs réserves ni constituer une validation professionnelle ou une autorisation de publication. Les fichiers de génération restent archivés ; aucune intégration iOS effectuée.
