# Test de micro-variations chaînées

Date : 9 septembre 2026.

Statut : essai local rejeté, non intégré au catalogue ou à l'application.

## Méthode

La pose 01 reprend la position basse sélectionnée dans `review-user-v01`. Chaque
nouvelle pose est une édition de la sortie immédiatement précédente. La demande
porte sur une seule micro-variation du bras chargé, avec conservation du corps,
du bras libre, du décor, du cadrage et de l'haltère.

## Résultat

- pose 02 : petit déplacement obtenu, avec redessin global et changement de
  résolution ;
- pose 03 : déplacement plus grand que le premier incrément ;
- pose 04 : nouvelle progression, cadrage encore assez stable ;
- pose 05-rejected-drift : seconde tentative depuis la pose 04, avec cible à
  deux points de pourcentage de hauteur. L'haltère continue de monter sans
  retour arrière, mais les textures et contours dérivent davantage.

Le test s'arrête à ce point : poursuivre la chaîne aurait accumulé une
trajectoire visuelle déjà irrégulière. Le fichier
`chained-test-with-rejected-drift.mp4` expose les cinq images, y compris la
sortie rejetée, à 0,8 seconde chacune. Ce n'est ni
une boucle candidate ni une répétition complète.

## Verdict borné

Le chaînage conserve mieux le cadre que la première planche 3 x 3 et la montée
reste monotone. Les incréments ne sont toutefois pas réguliers : 01 vers 02 est
très faible, puis 02 vers 03 est plus marqué. Surtout, peau, parquet, tissu et
contours sont progressivement reconstruits malgré les invariants répétés. Ce
test ne permet donc pas d'obtenir neuf poses exploitables. Il ne prouve pas que
la méthode échoue sur tous les exercices ou avec un outil d'édition muni d'un
masque local.
