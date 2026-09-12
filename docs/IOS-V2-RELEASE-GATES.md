# Barrières de release — La Bonne Séance V2

## Mise à jour du 8 septembre 2026

Yann a explicitement approuvé les 42 mouvements et médias actuels pour la version
destinée à Apple et autorisé sa soumission avec publication manuelle. Leur
approbation produit est enregistrée dans une liste fixe ; les ajouts futurs
restent non approuvés. Cela ne constitue pas une validation clinique,
professionnelle ou juridique. Les validations externes décrites ci-dessous
ne sont pas attestées par cette décision.

48 tests moteur et 116 tests iOS passent, dont la préparation et l’adaptation
Release. Le build 1.0 (2) a été téléversé dans App Store Connect. L’achat
StoreKit reste non validé de bout en bout. Voir
`ios/HandoffEvidence/2026-09-08-appstore-submission/README.md`.

Le reste de ce document conserve le contexte historique précédant cette
autorisation ; les mentions de catalogue fermé et de médias reviewedPreview
ne décrivent plus le statut des 42 éléments approuvés.

## État du produit

Le moteur V2, le parcours iOS et les 42 démonstrations visuellement acceptées
peuvent être testés localement avec le branding. Une build publique reste
volontairement fermée tant que les validations de diffusion ne sont pas acquises.

## Déjà exécutable

- profils matériel et supports explicites ;
- modes normal, allégé et recalibration ;
- séances de 20, 30 et 45 minutes ;
- mouvements repères stables et compléments à rotation limitée ;
- substitutions éditoriales, refus du jour et refus durable par configuration ;
- historique par configuration, progression répétitions puis charge réelle ;
- identité d'élastique sans conversion en faux kilogrammes ;
- repos conseillé, contrôlé par l'utilisateur et ajusté seulement après trois
  observations comparables systématiquement plus longues ;
- interruption, reprise, travail partiel sans dette et réduction du seul travail
  non commencé ;
- périmètre grossesse/post-partum explicitement déclaré et branche de sécurité
  conservatrice ;
- première séance gratuite puis achat unique à vie via StoreKit.

## Barrières automatiques

1. `V2EngineConfiguration.releaseV2` refuse chaque mouvement dont
   `productPublicationStatus` n'est pas `approved_for_product`.
2. `MovementMediaManifest.releaseIsComplete` reste faux tant que les 42 médias,
   posters, fallbacks et descriptions accessibles ne sont pas présents et prêts.
   `WorkoutEngineBridge` bloque alors explicitement `.releaseV2` avec
   `v2.movement_media_incomplete`, avant toute génération de séance.
3. Une sauvegarde V2 d'une autre version ne peut pas être réinterprétée.

## Médias intégrés, validations de diffusion restantes

Pour chacun des 42 mouvements :

- `<movement_id>_main_v01.mp4` — séquence locale carrée H.264 de 4 secondes ;
- `<movement_id>_poster_v01.webp` — poster ;
- `<movement_id>_phases_v01.webp` — fallback statique des poses retenues.

Les 126 fichiers sont intégrés au statut `reviewedPreview`. La sélection exacte
est `prototypes/movement-media/ios-accepted-selection-v01.json`, qui inclut les
dernières corrections acceptées et prime sur les anciens essais du catalogue.
Les séquences sont des assemblages de poses, pas des captations continues ;
certaines versions acceptées ne comportent que deux poses. Les gainages sont
affichés en position fixe et la descente de traction ne boucle pas.

Avant promotion : relecture des alternatives accessibles, validation du mouvement,
contrôle des droits des médias/références, puis autorisation explicite de diffusion.
Le statut catalogue `approved_for_product` et le statut média `ready` ne sont pas
modifiés par cette intégration.

Le catalogue final alterne les démonstrateurs pour obtenir une représentation
globale proche de 50/50 entre hommes et femmes. Un mouvement conserve un seul
démonstrateur : aucune variante genrée, aucun sélecteur et aucun doublon média.
Les mêmes critères de cadrage, de lisibilité et de validation s'appliquent à
toutes les personnes filmées.

## Validations externes avant diffusion

- professionnel du mouvement : exécution, amplitude, appuis, matériel ;
- médecin du sport ou kinésithérapeute : textes et conduite face à une gêne ;
- santé pelvienne/obstétrique : périmètre grossesse et post-partum ;
- juridique : finalité revendiquée, formulations de santé et confidentialité ;
- App Store Connect : produit non consommable `fr.labonneseance.lifetime`, achat unique à 59,99 € en zone euro ; achat et restauration à vérifier en Sandbox.

Ces validations sont des preuves de release. Elles ne doivent pas être remplacées
par un booléen interne, un test automatisé ou une sortie de simulation.
