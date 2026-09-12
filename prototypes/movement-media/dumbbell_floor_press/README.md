# Développé au sol — média prototype

La passe `stop-motion-v07` a validé une méthode de travail, mais son média a été
rejeté avant intégration : la prise de certains haltères et la cohérence d'une
main restent insuffisantes.

## Statut

- `prototype_not_for_product`
- non intégré dans l’app iOS ;
- ne modifie pas le statut du `MovementMediaManifest` ;
- ne peut pas débloquer la gate `v2.movement_media_incomplete`.

## Ce que V07 a permis de valider

- une descente bilatérale en huit paliers, suivie d’une remontée miroir ;
- la tête et la nuque restent posées ;
- les deux haltères restent présents et suivent la zone pectorale ;
- le personnage masculin est ordinaire et cohérent avec le ton de la marque ;
- le rendu stop-motion reste lisible dans une boucle locale de 3,2 secondes ;
- une planche de huit ou seize images ne doit pas être générée avant validation
  de quatre poses maîtresses.

## Réserves connues

- la perspective oblique amplifie l’écart apparent entre les deux côtés ;
- le côté proche descend légèrement bas sur les dernières poses ;
- mains, haltères et détails du visage présentent encore un léger morphing ;
- la position basse ne constitue pas une référence biomécanique canonique.
- la prise des haltères n'est pas assez constante pour une démonstration produit.

## Prochaine méthode

1. produire seulement quatre poses maîtresses : haut, un tiers, deux tiers, bas ;
2. valider séparément tête, épaules, coudes, poignets, mains et haltères ;
3. corriger ces quatre poses jusqu'à validation ;
4. générer ensuite les intermédiaires à partir des seules poses approuvées ;
5. assembler et revoir la vidéo hors de l'app ;
6. intégrer uniquement après validation explicite de la vidéo.

Le média final doit toujours être produit à partir d’une captation réelle validée,
avec tête posée, mouvement bilatéral synchrone, poignets empilés au-dessus des
coudes et haltères maintenus au-dessus du milieu de poitrine.

## Fichiers de contrôle

- `stop-motion-v07/dumbbell_floor_press_contact_sheet_v07.png`
- `stop-motion-v07/dumbbell_floor_press_stopmotion_prototype_v07.mp4`
- `stop-motion-v07/dumbbell_floor_press_stopmotion_poster_prototype_v07.webp`
- `stop-motion-v07/dumbbell_floor_press_stopmotion_fallback_prototype_v07.webp`

## Prototype V09 — quatre poses maîtresses

Le dossier `master-poses-v09` contient la première planche limitée à quatre
poses retenue comme base de test visuel : haut, tiers supérieur, tiers inférieur
et bas.

`dumbbell_floor_press_continuity_preview_v09.mp4` est uniquement un test brut
de continuité. Il réutilise les quatre poses sans interpolation afin de rendre
visibles les sauts de cadrage, de corps ou de matériel. Il n'est pas intégré à
l'application et ne constitue pas un média de publication.

## Prototype V12 — sept poses fournies et montage normalisé

Le dossier `master-poses-v12-seven` conserve la planche de sept poses fournie
par Yann, les découpes sources et leur normalisation carrée en 612 × 612.

`dumbbell_floor_press_stopmotion_preview_v12.mp4` est conservé comme premier
montage rejeté : la différence de largeur entre les quatre cases du haut et les
trois cases du bas y créait un faux zoom.

`dumbbell_floor_press_stopmotion_preview_v12_no_zoom.mp4` utilise une échelle
corporelle commune et un recadrage aligné sur la tête, les pieds et le tapis. Il
enchaîne les sept poses en descente puis en remontée, avec une courte pause en
bas. Aucun frame intermédiaire, fondu ou morphing n'a été généré pendant le
montage. Ce fichier reste un prototype hors application et ne modifie pas le
manifeste de release.
