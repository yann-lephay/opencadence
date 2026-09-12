# Fixtures du moteur 80/20 V2

Ces fixtures rendent le contrat de décision V2 observable et vérifient son
implémentation Swift ainsi que la configuration utilisée par la preview interne.

Cette V2 est appelable uniquement par l'opt-in interne `previewV2`. Elle n'est
pas activée dans l'interface ni persistée comme choix produit. Les coûts
temporels, le seuil de question de reprise et les
confirmations de progression sont des paramètres produit versionnés à tester.
Ils ne sont pas présentés comme des constantes physiologiques.

Le catalogue de test est volontairement limité à sept mouvements déjà connus du
projet. Il sert uniquement à éprouver :

- le matériel et les supports réellement disponibles ;
- l'assemblage dans 20, 30 ou 45 minutes ;
- les modes `normal`, `light` et `recalibration` ;
- la continuité locale des références ;
- les substitutions éditoriales partielles ;
- l'interruption, le refus et la branche conservatrice de sécurité ;
- la progression par répétitions puis par palier de charge réel.

Dans le manifeste, `policy` contient uniquement les cinq paramètres réellement
lus par Swift. `policyHypotheses` documente des choix de conception audités mais
non configurables à l’exécution ; modifier cette seconde section ne prétend pas
modifier le moteur.

`bodyweight_hinge` reste un mouvement de fixture à valider avant publication. Sa
présence permet de tester l'ancrage charnière sans matériel ; elle ne vaut pas
validation de sa fiche, de sa démonstration ou de sa chargeabilité.

Validation locale :

```bash
node scripts/validate-ios-engine-v2-fixtures.mjs
```

Le validateur contrôle la cohérence du manifeste et des sorties attendues. Il ne
prouve ni la justesse biomécanique des mouvements, ni la faisabilité humaine des
temps estimés, ni l'efficacité clinique de la doctrine.

La parité exécutable Swift est vérifiée avec :

```bash
swift test --package-path ios/CadenceEngine
```
