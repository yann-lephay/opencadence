# La Bonne Séance iOS

Le target Xcode conserve provisoirement le nom interne `OpenCadence`, mais le
nom public affiché par l'app est **La Bonne Séance**. Cette coque native relie le moteur
Swift valide au parcours `materiel -> duree -> apercu -> seance active` et
persiste localement l'inventaire ainsi que la seance en cours avec SwiftData.

## Ouvrir et verifier

Ouvrir `OpenCadence.xcodeproj`, choisir le scheme `OpenCadence`, puis un
simulateur iPhone.

Validation en ligne de commande :

```bash
xcodebuild \
  -project OpenCadence.xcodeproj \
  -scheme OpenCadence \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Validation du catalogue localisé et des métadonnées App Store :

```bash
node scripts/validate-localizations.mjs
```

Le français est la langue source et de repli. Les catalogues anglais, espagnol
et allemand ainsi que les brouillons App Store sont complets, mais leur
publication reste bloquée jusqu'à une revue linguistique explicite, langue par
langue. Les prix affichés dans l'app viennent toujours de StoreKit ; les montants
mentionnés dans les métadonnées ne sont que les prix de lancement prévus pour la
zone euro.

Le package moteur local est reference depuis `../CadenceEngine` ; aucune
dependance tierce n'est necessaire.

## Parcours interne du moteur V2

Les builds Debug utilisent le moteur V2 dans le vrai parcours iOS. Le flag de
lancement `-OpenCadenceForceV1` restaure immédiatement le moteur V1 ; les builds
Release utilisent la configuration V2 protégée. Tant que les validations produit,
catalogue, médias et cliniques ne sont pas terminées, cette configuration refuse
les mouvements non approuvés au lieu de retomber silencieusement sur la V1.

Une seance Debug V2 conserve dans son snapshot le plan versionne, l'inventaire
traduit et les supports utilises. Elle peut donc etre interrompue puis reprise
sans regeneration. Apres chaque repos, le moteur compare le temps reellement
ecoule au budget choisi et peut retirer seulement du travail non commence. Les
series confirmees restent immuables et aucune dette n'est creee. Une seance V2
terminee reconstruit ensuite une reference factuelle pour la prochaine seance.
Une sauvegarde V2 d'une autre version est bloquee avant toute nouvelle serie :
l'utilisateur peut enregistrer le travail deja fait sans progression automatique,
ou fermer la sauvegarde sans l'enregistrer.

Cette preview reste volontairement conservatrice :

- les supports réellement utilisables sont collectés explicitement pendant
  l'installation et peuvent être retirés pour la séance du jour ;
- une configuration matérielle absente n'est jamais déduite du seul nombre
  d'unités ; les haltères seuls, les paires, les kettlebells, le gilet et chaque
  élastique gardent une référence distincte ;
- un refus peut viser uniquement aujourd'hui ou persister pour cette
  configuration précise, sans être transformé en incapacité ;
- l'ancien historique ne transmet que les mouvements dont toutes les series
  prescrites ont ete factuellement terminees ;
- aucune charge ni reference de progression V2 n'est inventee a partir du V1 ;
- le catalogue produit contient les 42 mouvements retenus et sépare leurs
  configurations de progression ;
- un repos réellement plus long n'ajuste le budget qu'après trois observations
  comparables concordantes. Il ne change jamais la charge ou le niveau ;
- le moteur standard s'arrête devant un signal inhabituel déclaré et reste hors
  périmètre lorsqu'une grossesse ou un post-partum est explicitement déclaré.

Le catalogue et la politique runtime de cette voie sont verifies contre les
fixtures V2. Il s'agit d'une activation interne testable, pas encore d'une
activation produit publique.

## Achat à vie et test local

La première séance complète est gratuite. Lors de la prochaine demande explicite
de séance, l’app propose un achat unique pour un accès à vie, sans abonnement.
L’historique et les réglages restent accessibles sans achat.

Le scheme `OpenCadence` utilise `LaBonneSeance.storekit` sur le simulateur.
Les achats y sont fictifs et ne débitent rien :

- `fr.labonneseance.lifetime` — produit non consommable, 59,99 EUR en achat unique.

Avant une distribution TestFlight, créer ce produit dans App Store Connect avec
exactement le même identifiant et vérifier achat, restauration et remboursement
en Sandbox. Les prix affichés par l’app viennent de StoreKit, selon le pays du
compte Apple, et non de valeurs codées en dur.

## Perimetre prouve

- inventaire poids du corps, haltères fixes ou réglables, kettlebells, élastiques,
  gilet lesté, barre de traction, barres de dips et rameur ;
- calibration explicite et modifiable avec deux repères indépendants pour le
  haut et le bas du corps, sans niveau global inventé ;
- choix 20, 30 ou 45 minutes ;
- génération V2 par le catalogue produit de 42 mouvements en Debug, avec
  rollback V1 et barrière d'approbation séparée pour Release ;
- seance active, series, repetitions et repos pause/reprise/redemarrage ;
- confirmation d'une charge appartenant a l'inventaire avant une serie ponderee ;
- snapshot courant et snapshot precedent de secours ;
- reprise d'une seance et d'un repos en pause apres fermeture de l'app ;
- bilan factuel avec effort, gene et RIR facultatifs, sans valeur par defaut ;
- historique local idempotent et reinjection dans readiness, progression et
  priorites roulantes 7/21 jours ;
- proposition de reprise facultative apres interruption, avec acces garanti a
  une seance normale.
- première séance gratuite, achat à vie proposé au prochain démarrage explicite, achat et restauration via
  StoreKit 2, sans backend ni SDK tiers ;
- adaptation avant demarrage : mouvements exacts ecartes pour la seance
  courante, recalcul moteur reversible et recovery si aucun plan ne subsiste ;
- signalement pendant la seance : gene faible conservee, arret de serie a
  3-4, arret du mouvement a 5+, et orientation sans diagnostic pour un signal
  inhabituel ;

Les 42 démonstrations retenues par Yann sont embarquées : MP4 H.264 local,
poster, fallback statique, angle et libellé accessible. Les 126 fichiers pèsent
environ 21 Mo. La sélection exacte est conservée dans
`prototypes/movement-media/ios-accepted-selection-v01.json` ; vérifier les sources
et les copies avec `node scripts/sync-ios-movement-media.mjs --check` depuis la
racine du produit. Les médias sont `reviewedPreview`, pas `ready` : l'acceptation
visuelle et l'intégration locale ne valent pas validation professionnelle ou
autorisation de diffusion. Les gainages restent statiques ; la descente de
traction se lit une fois. Les autres démonstrations bouclent, sauf réduction
des animations ou économie d'énergie, avec pause et relecture explicites.

Restent externes au code : la validation des mouvements et des textes de santé
par les professionnels compétents, la revue juridique des formulations, la
création réelle des produits App Store Connect et la vérification des droits
des médias et de leurs références. La synchronisation iCloud et l'édition détaillée d'une
ancienne séance ne sont pas requises pour la V1 publique.

## Personnalisation des premières séances — 8 septembre 2026

Le parcours natif V2 prépare désormais une séance personnalisée sans choix de durée. La pratique
facultative et les repères locaux influencent la prescription ; les déclarations du jour restent
séparées du profil durable. Les anciens snapshots conservent le parcours historique décrit plus haut.
Une nouvelle séance personnalisée ne retire pas de travail à l'échéance d'un budget de durée.
Voir `../HandoffEvidence/2026-09-08-native-personalization/README.md` pour la recette et ses limites.
