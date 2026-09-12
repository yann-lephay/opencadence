# Premières séances — contrat moteur du 8 septembre 2026

Statut : implémentation locale de la proposition discutée avec Yann. Politique `first-sessions-1`.

## Portée et entrée publique

`CadenceEngine.decidePersonalizedSession(input:person:now:configuration:evidenceSource:)`
renvoie décision, contrôles locaux, alternatives compatibles, connaissances déclarées et
couverture musculaire. Elle utilise les primitives du moteur V2, son catalogue et ses coûts.
Elle ne lit ni n'écrit de stockage. `evidenceSource` vaut `nativeConfirmed` par défaut ; les tests
sélectionnent explicitement `syntheticScenario` et ne mélangent pas ces sources.

Les appelants V1, `decideV2`, les expériences précédentes, les snapshots et les fixtures héritées
restent compatibles. **Le bridge iOS et le parcours natif consomment cette API depuis le
raccordement du 8 septembre décrit ci-dessous.** Le générateur web reste distinct ;
la présence de cette API ne prouve pas sa parité avec le parcours natif.
Aucun média non validé n'est activé : le filtre de publication Release continue à s'appliquer.

## Décisions adoptées et conventions à tester

- Pratique de renforcement : inconnue, découverte, occasionnelle, régulière. Reprise explicite
  séparée (`returning`). Aucune inférence depuis sexe, âge ou fréquence d'ouverture.
- Deux séries par défaut ; trois pour une pratique régulière **dans une configuration familière**.
  Une habitude explicite compatible prime, sans imposer deux séances de probation.
- Ces nombres sont des conventions produit, pas une mesure de dose optimale ou de tolérance.
- En reprise choisie, la dose est plafonnée à deux temporairement ; en mode allégé, elle diminue
  d'une série avec un plancher catalogue. La préférence ordinaire est conservée. La recalibration
  explicite réutilise la réduction de difficulté existante.
- Aucun ajout de série sur seule réussite, plafond matériel, absence ou fréquence.
- Une hausse de dose à partir de travail observé ne hausse pas simultanément la difficulté.
- Une séance est construite sur les ancrages complémentaires puis estimée. `durationMinutes`
  et `remainingSeconds >= 0` n'ajoutent ni ne retirent du travail. Les coûts restent ceux du catalogue,
  avec repos observés admissibles. Pas de promesse de durée réelle ni d'estimation personnalisée
  de vitesse d'exécution validée.

## Ce que les informations signifient

`V2MovementKnowledge` contient des déclarations propres à une configuration et version de catalogue :
familiarité, nombre habituel de séries, répétitions déclarées, maximum ou séries ordinaires,
charge/option et indisponibilité durable. Une sélection de variante ne prouve pas sa faisabilité.

`at` date le repère initial de capacité/familiarité. `preferenceUpdatedAt` date un choix durable de
volume/exclusion et ne rafraîchit jamais la capacité. `reportedUnableAt` conserve une incapacité
signalée comme fait daté à réévaluer, distinct d'une exclusion définitive.
Une déclaration ultérieure pertinente ou une confirmation réelle ultérieure peut la dépasser.

Les performances sont exclusivement extraites des `confirmedWorkEvidence` de `V2HistoryEntry`.
Les références prospectives et identifiants de mouvements terminés sans faits détaillés ne prouvent
ni capacité, ni nouvelle charge. Dates futures, unités/configurations/versions incompatibles,
événements dupliqués et signaux de sécurité ne permettent aucune progression. L'ordre utilise des
Dates parsées, pas l'ordre lexical des chaînes. Une charge changée pendant la séance n'est pas
moyennée : les dernières séries à cette charge constituent le nouveau point de départ, sans
progression fondée sur un bloc de séries mixtes. Une séance partielle reste un fait partiel.

Les repères de capacité anciens demandant vérification utilisent la fenêtre produit existante
(30 jours dans le catalogue actuel). Ce délai ne représente aucune perte physiologique.
La familiarité et la préférence de quantité ne disparaissent pas après ce délai.

## Choix initial et correction directe

L'ordre éditorial existant départage les candidats, après priorité aux configurations familières
et aux faits récents. Un mouvement familier commence la séance si disponible.

Le catalogue marque les configurations exigeant un repère de capacité initial : tractions strictes,
assistées, descentes, tirage sous barres et pompes au sol (dont gilet). Matériel et familiarité seuls
ne lèvent pas ce contrôle. Une capacité inconnue, zéro, inférieure au minimum, ou exprimée comme un
maximum n'est pas transformée en séries répétables. Aucun maximum n'est converti par un coefficient.
Le contrôle est local : autre mouvement faisable choisi si possible, sinon omission explicitée et
question requise avant ce mouvement. Les premières propositions non marquées restent des départs à
ajuster, jamais une garantie universelle de faisabilité.

`optionsByExercise` propose au plus deux autres configurations disponibles du même ancrage,
avec leurs charges/options réelles et indication d'une capacité à vérifier. Ce sont des alternatives
éditoriales, pas une échelle universelle facile/difficile ni une équivalence de performances.
Un choix explicite de variante exigeante sans repère produit un contrôle, sans substitution silencieuse.

`V2SessionChoice` nomme session, mouvement, date et portée :

| Choix | Effet aujourd'hui | Mémoire durable |
|---|---|---|
| `load` | Charge réelle et unité exacte, séries conservées | Aucun niveau permanent ; les séries faites apprendront le repère |
| `variant` | Autre contexte, sans transfert de poids/répétitions | Le choix seul ne crée pas de capacité |
| `sets` | Quantité choisie, difficulté conservée | Seulement avec portée `usual` explicite |
| `difficultyTooHigh` | Palier inférieur existant, sinon répétitions réduites, sinon contrôle local | Aucune réécriture de capacité sans faits |
| `cannotPerform` | Configuration écartée, alternatives recherchées | Signal daté à réévaluer ; aucune série zéro fictive |
| `exclude` | Configuration écartée | Exclusion durable uniquement avec `usual` |

Une seule correction par mouvement et appel évite des commandes contradictoires ; l'appelant
peut ensuite appeler à nouveau avec la décision mise à jour. Les choix de charge/variante/difficulté
n'acceptent pas la portée `usual`. L'habituel se déclare avec les champs explicites ou s'apprend
à partir du travail réellement confirmé. Les choix liés à une autre session sont rejetés.

## Séance active

`activeSession.confirmed` reste intact, même en cas d'entrée refusée ou d'arrêt de sécurité.
`activeSession.unstarted` contient uniquement les séries qui n'ont pas commencé. L'appelant
retient séparément la série en cours et fournit `inProgressExerciseId` : une correction de ce
mouvement pendant son exécution est refusée. Une correction pendant le repos peut modifier les
séries restantes du même mouvement après une première série confirmée.

Le choix `sets(3)` désigne **trois séries au total pour cette configuration** : après une série
confirmée, le résultat contient deux séries restantes, pas trois supplémentaires.
L'absence de changement conserve exactement la prescription restante. Aucun dépassement temporel
ne retire de série. Les anciens plans actifs avec plusieurs configurations du même ancrage ou des
compléments hors ancrages renvoient une entrée incompatible et doivent rester sur leur dispatcher
historique ; ils ne sont pas partiellement migrés en supprimant du travail.

## Couverture

Le catalogue produit décrit désormais les contributions principales musculaires des ancrages
(poitrine, dos, quadriceps, fessiers, ischio-jambiers, épaules selon le mouvement). Le drill de
charnière au mur ne prouve pas à lui seul une couverture musculaire de force.

La sortie distingue principales, secondaires et contributions principales manquantes face à un
ensemble éditorial explicite (`chest`, `back`, `quadriceps`, `glutes`, `hamstrings`). Cela n'est ni
un score de séance complète, ni une équivalence de volume, ni l'exhaustivité des muscles entraînés.
Par exemple quatre ancrages avec pont fessier peuvent laisser les ischio-jambiers non couverts
principalement. En reprise active, la couverture inclut les exercices déjà confirmés.
Une lacune ne provoque aucun volume compensatoire et ne devient aucune dette.

## Scénarios d'acceptation

- Première séance : choix raisonnable à partir des déclarations ; une correction charge 4→6 kg
  agit immédiatement sans fabriquer une performance.
- Deuxième : les séries réellement faites à 6 kg fondent la proposition, même si une référence
  prospective héritée prétend 999 kg. Une correction non effectuée ne le fait pas.
- Troisième : même contexte reconnu, aucun contrôle de capacité répété sans motif nouveau.
- Tractions : inconnu, zéro, 1, 2, maximum déclaré, assistance et déclaration ancienne ne deviennent
  pas une prescription stricte au minimum 3. Cinq répétitions habituelles strictes déclarées
  peuvent borner un départ strict ; elles ne prouvent pas la répétabilité ou la tolérance.
- Reprise et quantité du jour n'effacent pas la préférence ordinaire.
- Réduction de difficulté distincte de réduction de quantité ; aucune hausse automatique de dose.
- Modification après une série confirmée, restauration, série en cours et garde clinique/périmètre.
- Couverture réelle partielle malgré quatre ancrages, couverture des mouvements déjà terminés.
- Déclarations/événements futurs, version/unité/charge impossibles, provenance mélangée et doublons.

## Raccordement iOS (8 septembre 2026)

Le parcours Home natif appelle maintenant `decidePersonalizedSession` avec les déclarations
facultatives et les confirmations natives. Les anciens snapshots restent sur leur ancien parcours.
Le profil SwiftData reçoit deux champs facultatifs ; un bloc de connaissances illisible produit une
erreur explicite au lieu de devenir un profil vierge. La reprise reste attachée à la séance.

Le parcours iOS ouvre directement le premier mouvement prêt, sans page de configuration intermédiaire ; le programme complet reste consultable via la liste. La durée
est estimée après préparation. Les variantes, repères de capacité et séries se règlent dans « Adapter »
avant le mouvement ou au repos. Les charges directes existantes restent disponibles. Une déclaration
locale de familiarité peut préciser le départ ; choisir une variante seule ne certifie pas sa capacité.

Le contexte actif conserve configuration Release/preview, repos, confirmations et prescription
historique. Remplacer une variante après 1/3 séries ne transforme pas cette exposition en 1/1.
Les choix du jour n'enrichissent pas les connaissances durables ; les préférences explicites le font.

Preuves et limites : `ios/HandoffEvidence/2026-09-08-native-personalization/README.md`.
Les tests ne démontrent ni gain physiologique ni friction nulle en conditions réelles.

QC design du parcours direct : `ios/HandoffEvidence/2026-09-08-ready-session-design/README.md`.

## Corrections après les dix séances synthétiques — 8 septembre 2026

- Les choix explicites compatibles de la séance survivent au recalcul avant effort (charge, variante, séries). Les choix incompatibles avec le matériel du jour ne sont pas appliqués et sont signalés ; une variante abandonnée ne conserve pas son ancienne charge.
- La cible de répétitions est figée au démarrage de chaque série et enregistrée séparément du réalisé. Une ancienne cible absente reste inconnue.
- Convention expérimentale : deux expositions complètes et comparables sous la cible peuvent déclencher un réglage facultatif pendant le repos. Le moteur maintient alors le réalisé sans en déduire la fatigue. Une préférence explicite de répétitions reste attachée à sa charge, et peut être libérée dans Adapter le mouvement. Plus tard suspend la question ; les changements de difficulté ne reprennent pas les écarts d'une autre charge.
- La couverture partielle est visible avant le premier effort. Voir les mouvements possibles n'apparaît que lorsqu'un contrôle local ou une alternative existante peut changer la proposition. Le catalogue n'est ni complété fictivement ni compensé par davantage de séries ailleurs.
- Terminer pendant le repos d'un mouvement achevé ne le marque plus comme passé.

Preuves : `ios/HandoffEvidence/2026-09-08-personalization-corrections/README.md`. La couverture totale sans matériel, la validation physique individuelle et la conversion ne sont pas démontrées par ce banc.

## Variété et séances rapprochées — 8 septembre 2026

Le parcours personnalisé produit désormais des blocs alternés quand les partenaires
haut/bas et leurs charges sont compatibles. Les blocs sont figés dans la séance,
et l’aperçu de pause utilise la même règle que le passage à la prochaine série.
L’ordre varie selon les séances effectivement confirmées, pas les ouvertures de
l’app. Les anciennes séances sauvegardées gardent leur déroulé.

Une réduction locale de une série peut suivre deux séances complètes récentes
sur un même muscle principal, dans les limites du catalogue, sans progression
simultanée. Ce cas particulier peut donc proposer une série au lieu du socle
ordinaire de deux. Le seuil de 48 heures est une convention explicite, pas une
mesure de fatigue. Les choix du jour restent prioritaires et les habitudes ne
sont pas réécrites. Détails et preuves :
`ios/HandoffEvidence/2026-09-08-session-variety/README.md`.
