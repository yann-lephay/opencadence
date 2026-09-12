# Raccordement natif — premières séances

## Résultat

Le vrai parcours iOS Home → préparation → ActiveWorkout utilise la personnalisation pour les nouvelles séances V2. Les anciens snapshots restent sur le dispatcher historique. Aucun déploiement, publication ou modification de données personnelles.

- Pratique du renforcement facultative, reprise distincte ; pas de calibration générale obligatoire en V2.
- Deux séries par défaut ; trois pour une pratique régulière avec mouvement localement familier ; préférence explicite et reprise prises en compte.
- Premier mouvement présenté ; programme complet à la demande ; estimation après génération, sans quota temporel actif.
- Réglage illustré des variantes, capacité locale, séries et portée aujourd’hui/habituellement avant effort ou au repos. Charges directes conservées.
- Couverture partielle signalée depuis les contributions musculaires réellement retenues.
- Contexte actif et connaissances durables distincts. Une correction préserve le repos, les confirmations et la dose initialement prescrite pour la provenance historique.
- Configuration Release préservée à chaque ajustement, sans contournement des validations médias.

## Vérifications

- 45 tests Swift moteur : PASS (`engine-tests.log`).
- 105 tests natifs / 11 suites : PASS (`native-tests.log`), dont 9 tests spécifiques dans PersonalizationNativeTests.
- Scénarios : pratique inconnue/régulière/familiarité, identité de séance, 3 séances successives, ajustement au repos + sauvegarde/relecture SwiftData en mémoire, refus pendant série commencée, séparation des repères ponctuels, corruption du profil, remplacement après 1/3 séries, restrictions Release et options réelles d'assistance.
- Revue anti_overengineering indépendante : PASS après correction des frontières de catalogue et de provenance.
- Typecheck web et build Next webpack : PASS. Localisations FR + EN/ES/DE : 553 clés, validation PASS.
- Contrat `qc/decision-surfaces/ios-personalized-first-sessions.json` : PASS.
- Captures natives `home.png` et `rest.png`, relues sur iPhone 17 iOS 26.5. Une légende de pratique a été ajoutée après la capture Home.

## Limites explicitement conservées

La suite intégrale de 106 tests a rencontré un échec indépendant de ces parcours : LifetimePurchaseTests. Le simulateur renvoie SKInternalErrorDomain code 3 au chargement de la configuration StoreKit et à la suppression des transactions, puis aucun produit n'est disponible. Le test n'a pas été modifié ; son échec n'est pas compté comme un succès. Le run fonctionnel exclut seulement cette suite.

Les captures utilisent le mode Debug `-OpenCadencePersonalizationProof` (et `-OpenCadencePersonalizationRestProof` pour le repos), qui crée exclusivement un stockage en mémoire. Le simulateur dédié est `1E3E60AE-7B9A-42DA-BD3E-83887C75BC20`. Aucun historique réel n'a été ouvert pour cette recette.

La recette automatisée et les deux captures ne remplacent pas un essai utilisateur, une revue linguistique humaine, la recette VoiceOver complète ou une validation biomécanique. Aucune installation sur l'iPhone personnel ni publication App Store n'a été effectuée.
