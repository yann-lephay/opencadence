# QC design — la séance est prête

## Décision produit

La page « Composer la séance » était un défaut important : après « Commencer ma séance », elle demandait encore de préparer puis de commencer, sans montrer le mouvement. La capture fournie par Yann établit ce défaut de hiérarchie et de positionnement ; elle ne prouve pas un taux d'abandon.

Parcours normal V2 corrigé : accueil → premier mouvement prêt → démarrage explicite de la série. Le matériel requis reste déclaré si inconnu. Aucun effort ni repos ne démarre lors de la préparation automatique.

Les deux actions intermédiaires de préparation disparaissent. « Tu pratiques déjà ? » ouvre une feuille facultative avant la première série, avec pratique et familiarité locale ; reprise, intention et matériel du jour restent accessibles. Les ajustements locaux pendant les repos sont conservés. La liste de séance reste facultative. L'accueil explique simplement première séance offerte puis achat unique.

## QC appliqué

Profil détecté saas, périmètre réel natif iOS : Product + Release + portes Universelle/SaaS + Design/Experience. SEO, pages web publiques, acquisition et déploiement N/A sur ce delta. Pas de nouvelle identité, médias, dépendance ni changement du moteur de dose. Le contrat visuel iOS existant reste la référence.

Contrat de décision : `qc/decision-surfaces/ios-personalized-first-sessions.json`, validé.

### Constats corrigés

- IMPORTANT : formulaire moteur imposé entre envie et effort → étape retirée du parcours normal.
- IMPORTANT : affichage « Réalisé : 8 » avant l'effort alors que prescription 6 → saisie uniquement après début explicite, valeur de départ issue de la prescription.
- IMPORTANT : réglage global pouvait perdre une capacité déclarée aujourd'hui → bases active et durable séparées.
- IMPORTANT : décocher la familiarité était ignoré → booléen appliqué dans les deux sens sans modifier capacité/date.
- OPTIONNEL : compteur 0 sans contexte → retiré de la nouvelle séance.

## Preuves actuelles

1. `01-welcome.png` : accueil, CTA et information commerciale visibles, lien de méthode secondaire plus bas.
2. `02-first-movement.png` : proposition, démonstration, adaptation et démarrage visibles, aucune montagne ni résultat prématuré.
3. `03-optional-preferences.png` : feuille facultative avec Annuler/Appliquer. Les réglages ne constituent plus une étape obligatoire.
4. `04-large-type.png` : taille accessibility3, retours à la ligne conservés, CTA lisible. Les actions secondaires plus bas demandent de défiler ; cela ne vaut pas audit VoiceOver complet.

5. `05-compact.png` : iPhone 13 mini, prescription, CTA et actions secondaires visibles ensemble après résolution du premier lancement bloqué du simulateur.

108 tests natifs dans 11 suites PASS, dont démarrage prêt sans effort/repos, refus de régénération après début/confirmation, familiarité réversible et conservation du repère ponctuel. Build natif final PASS ; build web webpack et typecheck PASS ; localisations FR/EN/ES/DE 561 clés validées. Le moteur de dose n'a pas été modifié dans ce delta (preuve antérieure 45 tests conservée).

Revue anti_overengineering : PASS. Revue indépendante produit/design : PASS ciblé sur accueil, premier mouvement iPhone17 standard, feuille facultative, texte accessibility3 et iPhone13mini compact. Le défilement des actions secondaires et la sémantique VoiceOver ne sont pas validés par ces captures.

StoreKit : échec précédent de configuration du simulateur conservé dans le rapport native-personalization ; la suite LifetimePurchaseTests est explicitement exclue du run fonctionnel, aucune réussite d'achat revendiquée.

## Ce que cela devrait apporter — hypothèse

Rendre immédiatement tangible la promesse et réduire les décisions avant le premier effort. Une amélioration de conversion n'est pas mesurée. Les observations utiles lors des prochains essais sont : compréhension du prochain geste, démarrage sans aide, pertinence de la première proposition, correction réussie et volonté de refaire une séance. Le retour pour la deuxième séance et l'achat restent deux résultats distincts.

Aucune instrumentation, transmission ou publication ajoutée. Données fictives en mémoire et simulateurs dédiés uniquement. Le test visuel ne remplace ni l'essai utilisateur ni la recette VoiceOver et achat.

Checkpoint final : modifications locales livrées ; Build/Release local PASS, Product fonctionnel PASS sur scénarios testés, Design visuel PASS sur les cinq captures ; VoiceOver/interactions de défilement exhaustives NON TESTÉS, achat StoreKit INCONCLUSIF, impact conversion NON MESURÉ. Prochaine validation produit : essai utilisateur du démarrage et de la correction de première séance.

## Reprise du 9 septembre : préparer l'observation humaine

Comparaison au code courant : `HomeView` prépare puis ouvre la séance dans sa
`.task`, `WorkoutEngineBridge` appelle `NativePersonalization.prepare`, et
`ActiveWorkoutView` conserve la feuille facultative avant effort ainsi que
« Adapter le prochain mouvement » au repos. Le parcours personnalisé est donc
raccordé ; la phrase contraire en tête de `docs/80-20-FIRST-SESSIONS.md` a été corrigée.
Le diff partagé préexistant (dont `ios/` non suivi) a été conservé.

Nouveau jalon : `docs/FIRST-SESSIONS-USER-TRIAL.md`, protocole accompagné de trois
visites avec consignes ouvertes, fiche sans identité et décisions après observation.
L'accès aux visites suivantes est un prérequis à vérifier séparément, pas une
capacité supposée. Aucun changement de code, règle de dose, collecte ou parcours.
Revue indépendante `anti_overengineering` du protocole et de la correction : **PASS**.

Preuves exécutées le 9 septembre sur le code courant :

- `swift test --package-path ios/CadenceEngine --scratch-path /tmp/lbs-first-session-engine-0909` :
  **48 tests / 7 suites PASS**. Log `/tmp/lbs-first-session-engine-0909.log`.
- `xcodebuild test`, scheme `OpenCadence`, simulateur dédié LBS Personalization QA
  `1E3E60AE-7B9A-42DA-BD3E-83887C75BC20`, derived data `/tmp/lbs-first-session-native-0909`,
  `-parallel-testing-enabled NO`, sélection `-only-testing:OpenCadenceTests/PersonalizationNativeTests`,
  `-only-testing:OpenCadenceTests/PersonalizationCorrectionsTests` et
  `-only-testing:OpenCadenceTests/TenSessionPersonaTests` : **20 tests / 3 suites PASS**,
  dont le test paramétré de 19 profils sur dix occasions de séance.
  Log `/tmp/lbs-first-session-native-0909.log`, résultat
  `/tmp/lbs-first-session-native-0909/Logs/Test/Test-OpenCadence-2026.09.09_09-23-22-+0200.xcresult`.

Les premiers appels sans accès aux caches Swift/CoreSimulator ont échoué dans le
sandbox ; les exécutions autorisées ci-dessus ont terminé avec succès.
Ces suites utilisent des données synthétiques et du stockage de test en mémoire.
Aucun journal personnel n'a été lu ou modifié. Pas de nouvelle preuve visuelle,
VoiceOver, d'usage humain ou de conversion dans cette reprise ; les captures du
8 septembre restent des preuves datées. Les tests web ne sont pas relancés pour
ce delta documentaire. Aucune action Apple, commit, push ou publication.

Prochaine observation : laisser une personne juger le premier mouvement et
chercher seule une correction si nécessaire, avant de lui expliquer l'interface.
