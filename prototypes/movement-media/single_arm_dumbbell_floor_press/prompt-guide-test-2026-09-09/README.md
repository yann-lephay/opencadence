# Développé au sol unilatéral — test du 9 septembre 2026

Objectif : enrichir la trajectoire du clip iOS sélectionné à deux positions. Prototype local uniquement ; aucun média existant ni manifeste modifié.

Références : review-user-v01/frames/pose_02.png (bas), pose_01.png (haut). Même bras droit anatomique, à gauche pour le spectateur ; un seul haltère noir, bras libre au sol.

V01 : planche de neuf poses demandées en 3x3. Rejet indépendant : départs quasi identiques et changements de cadrage entre rangées. board-v01.png conservée, non assemblée.

V02 : six étapes demandées à 0/20/40/60/80/100% sur une montée, avec invariants de position de tête, corps, pieds, tapis et plinthe, espace réservé au bras haut. Le modèle a produit six cellules portrait au lieu des carrés demandés. Extraction uniforme 384x610 aux x22/434/846 et y6/634, adaptation à hauteur612 et marges latérales communes, sans couper le corps, sans recalage local ni déformation anatomique. Originaux dans board-v02.png.

Montage candidat : poses1,2,3,4,5,6,5,4,3,2 à 0,4s ; une répétition sur quatre secondes, 30fps H.264 612², aucun fondu/morphing/interpolation. Six sources ne sont pas 120 poses : l'encodage tient les images.

Comparaisons :
- current-left-test-right.mp4 : clip actuel exact (deux répétitions/4s) contre essai (une/4s), donc cadence non comparable.
- comparison-one-cycle.mp4 : comparaison conseillée, mêmes quatre secondes et une répétition. À gauche les deux poses initiales remontées bas1s/haut2s/bas1s ; à droite six poses. La temporalité discrète diffère nécessairement ; ce n'est pas une synchronisation exacte des angles.
- floor-press-six-poses-v02.mp4 : candidat seul.

Revue indépendante compare_curl : six poses examinées séparément. V02 candidate, gain visible face aux deux positions initiales. Tête, tronc, genoux, pieds, tapis et plinthe bien alignés, rupture entre rangées corrigée. Six poses distinctes ; petit pas01→02, progression ensuite plus ample. Prise et forme haltère globalement cohérentes. Réserves : doigts de main libre et contours légèrement variables, netteté inférieure aux références.

Limites : pas de lecture continue par l'agent, pas de validation biomécanique ni d'approbation utilisateur de cette sortie. Le modèle exact n'est pas exposé par image_gen. Revue des images et encodage ne prouvent pas la fluidité perçue sur appareil.

Prochaine action : regarder comparison-one-cycle.mp4 avant toute intégration. Aucune nouvelle génération nécessaire sans défaut visible supplémentaire.

## V03 — sans pose 02, demande utilisateur

Yann signale un effet de descente avant remontée sur la deuxième image en lecture. Inspection fixe : hauteur de haltère croissante sur01→02→03, mais variation du coude/avant-bras ; cause perceptive non établie. Variante demandée sans pose02 à aller et retour : 1,3,4,5,6,5,4,3 à0,5s, quatre secondes, cinq poses distinctes. Fichier floor-press-five-poses-v03.mp4. Sources et V02 conservées. Pas de validation utilisateur de V03 ni intégration.
