# Pompe inclinée — test « décor figé »

Statut : expérience A/B locale, non intégrée et non publiable.

## Hypothèse

Demander explicitement au modèle de recopier un même décor pixel pour pixel et
de ne faire évoluer que la personne pourrait supprimer l'impression de cut.
La même image de départ que le candidat bulk précédent a été utilisée. Le prompt
exact est conservé dans `prompt.txt`.

## Sorties

- planche : `contact-sheet-3x3.png`
- boucle :
  `../review-images25-fixed-scene-v01/incline_push_up_review_images25_fixed_scene_v01.mp4`
- comparaison gauche = bulk précédent, droite = décor figé :
  `../review-images25-fixed-scene-v01/incline_push_up_ab_old-left_fixed-scene-right.gif`

## Résultat

Le prompt améliore légèrement la stabilité d'une zone de mur uniforme, mais ne
fige pas réellement toute la scène. Sur des repères structurés comme l'étagère,
ses objets et la plante, une dérive reste visible et peut être plus forte que
dans la première planche.

Mesures exploratoires de différence entre zones censées être statiques :

- mur, première pose → pose médiane : RMSE normalisée `0,014016` dans le bulk
  précédent contre `0,012466` dans le test décor figé ;
- étagère, première pose → dernière pose : `0,196886` dans le bulk précédent
  contre `0,253755` dans le test décor figé.

Ces nombres ne mesurent pas la qualité anatomique. Ils servent seulement à
vérifier que le décor n'est pas recopié à l'identique.

## Diagnostic

Le rendu vidéo applique le même découpage, le même redimensionnement et le même
canevas à chaque cellule. Il n'ajoute ni translation, ni zoom, ni interpolation.
Le mouvement global perçu existe donc déjà dans la planche générée ; le montage
ne fait que le rendre visible à chaque changement de pose.

Verdict : le renforcement du prompt seul est insuffisant. La prochaine expérience
utile est une stabilisation géométrique déterministe sur les repères du décor,
comparée à la boucle brute, sans encore intégrer de média dans le produit.
