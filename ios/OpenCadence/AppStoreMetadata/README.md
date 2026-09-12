# Métadonnées App Store — brouillon localisé

Ces textes sont préparés pour `fr-FR`, `en-US`, `es-ES` et `de-DE`. Ils ne sont
pas publiés et ne doivent pas être copiés dans App Store Connect avant une revue
linguistique explicite de chaque langue.

Principes communs :

- le nom **La Bonne Séance** n'est jamais traduit ;
- la première séance complète est gratuite ;
- le prix de référence de la zone euro est de 59,99 € en achat unique pour un accès à vie, sans abonnement ;
- le prix local affiché par l'App Store avant achat reste toujours la référence ;
- l'historique reste local sur l'iPhone par défaut ;
- aucune séance manquée ou raccourcie ne crée de dette ;
- le produit ne pose pas de diagnostic et conserve une conduite prudente devant
  une gêne déclarée.

Les répertoires `screenshots/` contiendront les captures Aujourd'hui, Exercice
et Bilan produites depuis les vraies vues de l'app. Le répertoire `qa/` est
réservé aux preuves Dynamic Type, Reduce Motion et aux contrôles de chaînes
longues ; il ne constitue pas un lot publiable.

État fonctionnel actuel : l'app ne demande aucune permission système et ne
programme aucune notification. Ces deux surfaces sont donc `N/A` pour ce lot ;
toute introduction future devra ajouter ses textes au catalogue avant build.

Validation locale :

```bash
node scripts/validate-localizations.mjs
```
