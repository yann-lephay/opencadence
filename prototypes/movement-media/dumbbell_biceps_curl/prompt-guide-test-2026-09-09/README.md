# Curl : test planche et édition unitaire

9 septembre 2026. Prototype local, aucun manifest modifié.

Planche : neuf poses générées en une fois depuis la pose 01 de review-v02. Montée seulement, retour inverse. Neuf positions visuellement distinctes. Boucle de 4 secondes, 16 étapes, sans interpolation. Cadrage extrait de façon uniforme (408 px) pour enlever les séparations de grille. Les coudes avancent légèrement en haut et la forme des haltères varie : validation visuelle et technique encore requise.

Édition unitaire : la même image initiale sert de base, flexion demandée de 20 degrés. Résultat single-edit.png : flexion visiblement plus importante, donc non retenu comme premier petit incrément. Ce test ne constitue pas une séquence complète de neuf éditions et ne démontre pas que toute édition unitaire échoue.

Modèle exact non exposé par image_gen. Source de méthode : guide OpenAI image-prompting et rowing bulk-v01 existant.

## Comparaison complète ajoutée après demande utilisateur

La méthode B a ensuite été menée jusqu'au bout : voir `individual-v01/README.md`. Ne pas confondre ce nouvel ensemble complet avec le premier essai isolé `single-edit.png` décrit plus haut.

- A : `curl-nine-poses.mp4`, planche générée en une fois.
- B : `individual-v01/curl-individual-nine-poses.mp4`, initiale + huit éditions indépendantes depuis cette initiale.
- Comparatif synchronisé : `comparison-bulk-left-individual-right.mp4`, A à gauche, B à droite.
- Deux boucles H.264 de quatre secondes, neuf images, seize étapes, sans interpolation.

### Revue indépendante des images et montages

L'agent compare_curl a inspecté les deux planches et chacune des 18 poses, ainsi que l'ordre/durée des montages. Il n'a pas visionné les MP4 en lecture continue. Il s'agit d'une revue visuelle image par image, pas d'une validation de fluidité en lecture ni d'une validation biomécanique.

Verdict sur ces sorties : A donne la progression la plus exploitable. B conserve très bien décor et pieds, mais présente des quasi-paliers 03→04 et 06→07, puis un saut marqué 04→05. Les haltères changent davantage d'orientation et de silhouette en 03→04 et 05→06 ; le torse/épaule varient en 08→09. Aucun doublon strict établi.

A reste imparfaite : petit pas 06→07 et déplacement plus visible des coudes vers l'avant/haut en 08→09. Les prises sont souvent masquées par les disques. Le retour inverse reproduit les irrégularités de chaque montée.

Prochaines itérations suggérées, non réalisées dans ce comparatif : A redistribuer 06–08 et corriger 09 ; B refaire 04 entre 03/05, 07 entre 06/08, contrôler les prises 03–06 et refaire 09 sans variation du torse. Conserver ce test brut pour comparaison. Le résultat ne prouve pas la supériorité générale d'une méthode.

Revue de proportion anti_overengineering : PASS. Aucun catalogue, manifeste ni code produit modifié.
