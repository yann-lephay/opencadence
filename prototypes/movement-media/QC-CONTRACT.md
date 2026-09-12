# Contrat QC des prototypes de mouvements

Ce contrat s'applique aux planches et boucles de démonstration produites avant
validation humaine finale. Un prototype accepté reste non intégré et ne passe
jamais automatiquement le `MovementMediaManifest` à `ready`.

## Contrôles obligatoires

1. **Séquence** — retenir uniquement des poses réellement distinctes, ordonnées
   et cohérentes avec le sens du mouvement.
2. **Cadence** — viser une répétition complète autour de quatre secondes
   (cible de montage 3,5 à 4,2 secondes, extensible si le geste l'exige). Une boucle ne
   doit ni clignoter ni imposer l'impression d'un tempo obligatoire.
3. **Densité** — générer 16 candidats et conserver toutes les poses réellement
   cohérentes. Viser 10 à 16 étapes visibles sur le cycle complet ; six poses
   distinctes sur un aller restent un minimum exceptionnel, et quatre ne sont
   acceptées que si le mouvement demeure parfaitement compréhensible.
4. **Stabilité** — refuser zoom, recadrage, déplacement du décor, des appuis ou
   du matériel sans raison liée au geste.
5. **Anatomie et matériel** — contrôler mains, doigts, articulations, prises,
   nombre d'objets, trajectoires et contacts.
6. **Technique** — vérifier les critères propres au mouvement et rejeter les
   images séduisantes qui les contredisent.
7. **Branding** — conserver crème, orange, vert encre et humeur rétro. Dans la
   vidéo active, la matière ne doit jamais masquer le corps ou le matériel. La
   grosse trame et le décalage d'encres appartiennent surtout aux posters.
8. **Accessibilité** — le geste doit rester compréhensible en image fixe et ne
   pas dépendre uniquement de la couleur.

## Verdicts

- `PASS PROTOTYPE` : séquence assemblable sans correction générative.
- `À CORRIGER` : une sélection ou une nouvelle planche ciblée peut suffire.
- `REJET` : anatomie, technique ou continuité trop ambiguë.

Le contrôleur indique toujours les indices retenus et exclus, les réserves et
la durée d'assemblage recommandée.

## Cas particuliers du catalogue complet

- Les planches de gainage montrent une tenue isométrique. Une image fixe claire
  est pertinente ; ne pas inventer un cycle corporel pour remplir seize cases.
- La descente de traction reste une descente. Le retour au départ doit montrer
  la remise en place sur le support ou être explicitement séparé de l'exécution.
- Les marches exigent une alternance gauche/droite réelle, avec main chargée
  constante. Aucun miroir spatial ni retour temporel d'un demi-pas.
- Le rameur exige un cycle complet avec la coordination jambes, buste, bras
  puis bras, buste, jambes ; son rythme est illustratif.
- Un cadre généré cohérent à l'œil reste un candidat : l'acceptation du rendu,
  la validation du mouvement et le statut de publication sont distincts.
