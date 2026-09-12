# Parcours iOS — écarts spécifiés terminés localement

7 septembre 2026. Ce suivi remplace les points matériel, bilan et moment du paywall laissés ouverts dans le rapport `2026-09-07`. La durée automatique et le retrait du questionnaire V2 font l’objet de la proposition jointe, non activée.

## Résultat observable

- **Matériel** : sélection tactile des familles, objets fixes/kettlebells multiples, déclaration des poignées, choix tactile des disques et quantités. Le calcul utilise les disques réellement disponibles pour les montages symétriques d’un haltère et pour deux haltères simultanés de même masse. Des compositions différentes de disques sont possibles. Aucun poids ni paire n’est déduit d’une déclaration incomplète.
- **Élastiques** : nom/couleur et résistance léger, moyen, fort ou « Je ne sais pas ». Identités stables et distinctes ; renommer un objet n’écrase pas les anciennes séries, supprimer puis recréer un homonyme ne reprend pas son identité. Les noms historiques restent lisibles sans le brouillon matériel. Aucun ordre de progression entre bandes n’est inféré de ces qualificatifs : une progression exige une relation déclarée dans le même objet moteur.
- **Bilan** : « Bien joué. », « Voilà ce que tu as fait. », illustration principale rétractable avec le défilement, illustrations par mouvement et détails des séries dépliables. Agrégats calculés uniquement depuis les séries confirmées, charges et unités par côté conservées. Les retours facultatifs sont repliés, avec intitulés visibles. « Retour à l’accueil » appelle la sauvegarde réelle et conserve ses erreurs/réessais ; aucun écran ne prétend avoir enregistré avant réussite. Le bilan vide garde une formulation distincte.
- **Paywall** : le bilan revient à l’accueil. Une nouvelle demande de séance déclenche la vérification des droits et éventuellement le paywall. La reprise d’une séance active a priorité, même si elle apparaît pendant la vérification. Paramètres et historique restent accessibles. Le produit StoreKit, ses offres et ses droits ne sont pas modifiés.

## Recette du parcours réel

Sur iPhone 17 / simulateur iOS 26.5, fixture Debug `journeyPersistent`, stockage SwiftData sur disque isolé de l’application normale :

1. Accueil → Reprendre → charge disponible → départ explicite → confirmation de la première série.
2. Repos en pause à **1:23**, progression **1/12** → fermeture effective du processus → relancement → action Reprendre : **1:23 et 1/12 restaurés**.
3. Poursuite de cinq mouvements, avec douze départs et confirmations distincts. Les repos sont volontairement passés pour cette recette ; les répétitions affichées sont confirmées dans l’UI. Ce sont des données de test, pas une séance physique ni une mesure d’efficacité.
4. Bilan **5 mouvements / 12 séries** → Retour à l’accueil : **aucun paywall automatique**.
5. Paramètres → historique : **une seule séance de 12 séries / 5 mouvements**.
6. Accueil → Commencer ma séance : **paywall affiché à ce moment seulement**. Les offres existantes sont indisponibles dans cet environnement ; aucun achat n’a été exécuté.

La fixture `summary` distincte construit son bilan par le vrai moteur et les confirmations du coordinator avec des temps simulés. Les quantités peuvent différer de la recette UI : elles ne sont pas des performances personnelles. Les captures ne mélangent pas ces deux sources.

## Captures utiles

- `captures/summary-portrait-final.png` : copie, illustration et première ligne de mouvement.
- `captures/summary-retracted-details.png` : hero disparu au défilement natif, détails et illustrations de plusieurs mouvements.
- `captures/summary-feedback-final.png` : intitulés et aide facultative corrigés.
- `captures/summary-landscape-final.png` : cadrage paysage corrigé.
- `captures/summary-accessibility-max.png` : corps en taille d’accessibilité maximale ; miniatures décoratives masquées dans ce mode pour laisser la place au texte.
- `captures/equipment-plates.png`, `captures/equipment-band-resistance.png` : disques/quantités et choix de résistance.
- `captures/flow-paused-before-close.png`, `captures/flow-paused-after-relaunch.png` : reprise persistante.
- `captures/flow-summary-12-confirmed.png`, `captures/flow-home-after-summary.png`, `captures/flow-history.png`, `captures/flow-paywall-next-start.png` : séquence complète.
- `captures/welcome-resume-final.png` : titre de reprise sans ponctuation orpheline.

## Vérification et limites

- Suite native complète : **PASS**, 78 cas rapportés par xcodebuild, `native-tests.log`. Elle couvre notamment le calcul exact du matériel, les identités, la compatibilité, les politiques d’accès et les protections existantes. Les deux appels throwing manquants dans les nouveaux tests ont été corrigés avant ce succès.
- Moteur ciblé : **PASS**, 21 tests / 4 suites, parité des 45 fixtures V1 et 13 décisions V2 comprise, `engine-tests.log`.
- Build final après les retouches visuelles constatées : **PASS**, `final-build.log`. La suite native complète précède ces seules retouches de présentation ; elles ont été compilées puis revues à l’écran.
- Localisations : **PASS**, 513 clés ; français source/fallback, anglais/espagnol/allemand complets. Ce n’est pas une revue linguistique humaine.
- Bilan inspecté en portrait, paysage, grand texte et via la branche Reduce Motion forcée en Debug. La réduction d’animation conserve un hero statique dans le défilement. Le défilement et les disclosures ont été actionnés via l’accessibilité native du simulateur ; aucune prétention de recette VoiceOver complète ou de contrôle physique.
- Revue indépendante : PASS du lot sur les sources et dix captures, puis PASS complémentaire des quatre derniers rendus et de la proposition durée/calibration. Aucun défaut matériel supplémentaire relevé sur ce lot.
- Aucune release, aucun commit/push, aucune écriture dans `data/state.json` ou l’historique personnel. Les sources iOS étaient déjà non suivies au départ ; les autres modifications du dépôt sont préservées.
- Catalogue média `reviewedPreview` et gates de diffusion inchangés. Captures et tests ne donnent pas d’autorisation clinique, biomécanique ou de diffusion des médias.
- Nouvelle offre StoreKit, notifications et collecte restent des travaux séparés. Le placement du paywall est terminé indépendamment de ces sujets.

## Proposition suivante

Lire `DUREE-CALIBRATION.md` : politique automatique explicite, durée estimée après programme sans coupure, conservation des anciennes séances et de V1, retrait du questionnaire uniquement au démarrage V2. Le principe de durée automatique n’est pas remis en débat ; seuls ses paramètres moteur sont soumis à validation.
