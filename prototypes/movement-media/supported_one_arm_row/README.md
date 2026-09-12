# Rowing unilatéral avec appui — prototype média

Statut : prototype non intégré, non publiable et non marqué `ready`.

## Méthode retenue

- planche candidate 4 × 4 à cellules égales ;
- une ligne représente quatre phases du même mouvement ;
- sélection humaine des seules poses cohérentes ;
- assemblage stop-motion sans interpolation, zoom ni génération intermédiaire ;
- mouvement : main gauche en appui sur un banc stable, haltère unique dans la main droite, buste fixe et coude droit tiré près du corps.

La ligne 3 de `stop-motion-v02-candidate-matrix` est utilisée pour le premier aperçu. Elle suit : départ, tirage initial, tirage avancé, position haute, puis retour par les mêmes images dans l'ordre inverse.

## Cadence retenue après essai

- une boucle active vise environ 4 secondes, avec une cible de 3,5 à 4,2
  secondes, et non une répétition précipitée en moins de 2 secondes ;
- quatre poses distinctes et sept étapes aller-retour restent suffisantes pour ce prototype, mais constituent le minimum acceptable ;
- les mouvements suivants doivent viser six à huit poses réellement distinctes sur l'aller lorsque la génération le permet ;
- des poses presque identiques issues de prises différentes ne sont pas ajoutées seulement pour augmenter le nombre d'images : elles créent surtout du micro-jitter ;
- la vidéo active porte la marque par la palette, le décor et la lumière ; la grosse trame et le décalage d'encres restent réservés au poster et aux surfaces éditoriales.

## Limites connues

- le personnage, le cadrage et le matériel doivent encore être contrôlés image par image ;
- les essais `stop-motion-v03-dense-rejected` et `stop-motion-v04-intermediate-candidates` n'apportent pas assez d'étapes distinctes et ne doivent pas être assemblés ;
- l'essai `stop-motion-v05-dense-candidates` confirme la même limite : malgré
  seize cases, il ne fournit qu'environ quatre hauteurs de tirage réellement
  distinctes. La pose unitaire générée entre deux ancres modifie en plus le
  cadrage et se rapproche trop de la position haute. Aucun de ces nouveaux
  fichiers ne doit être assemblé ou présenté comme une amélioration ;
- ce prototype ne remplace pas la future captation humaine validée ;
- aucun fichier de cette arborescence ne doit être déclaré prêt dans `MovementMediaManifest` avant validation explicite.
