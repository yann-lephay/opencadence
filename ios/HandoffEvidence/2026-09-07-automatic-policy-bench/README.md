# Durée automatique : comparaison exécutée, politique non activée

7 septembre 2026 — banc local sur le vrai moteur Swift. **Recommandation : ne pas généraliser le maximum du catalogue. Soumettre le plafond à deux séries comme point de départ expérimental, avec une série en allégé, sans prétendre qu’il s’agit d’une dose optimale.**

Le principe acquis est conservé : construire le programme, estimer sa durée ensuite, ne pas retirer du travail parce que cette estimation est dépassée. Aucune politique n’est activée dans l’app et aucune séance existante n’est migrée.

## Ce que les exécutions changent dans la décision

1. Le maximum donne trois séries à chaque repère disponible, y compris sans historique et après 90 jours sans exposition. Il ne correspond pas à un volume démontré par la personne.
2. Le moteur reçoit des références de charge/répétitions, mais pas le nombre de séries confirmé. Un test du vrai bridge montre que **une et trois séries confirmées**, à contexte/reps/charge identiques, peuvent produire la même projection historique et la même préparation suivante. Les données sources conservent pourtant leur volume distinct. Un statut « régulier » ne peut donc pas justifier automatiquement trois séries dans cette entrée moteur.
3. Le catalogue produit autorise **une à trois séries**, pas deux à trois. Le minimum réduit fortement le programme et ne permet plus au mode allégé de réduire le nombre de séries : il retourne explicitement `light_plan_unavailable`. Ce résultat n’a pas été masqué.
4. Le plafond intermédiaire à deux réduit d’un tiers le nombre de séries par rapport au maximum, garde une réduction possible en allégé et ne demande aucune donnée ni règle de profil supplémentaire. C’est une convention produit à éprouver ; le banc ne démontre ni efficacité, ni tolérance physiologique, ni supériorité médicale.

## Comparaison principale — mode normal

Les durées sont les **estimations exécutées du moteur**, pas des séances chronométrées. Tous les profils sont synthétiques. Les noms de profils servent à lire les cas, pas de nouvelles variables cachées du moteur.

| Cas | A : maximum | C : plafond 2 | B : minimum |
|---|---|---|---|
| Sans historique | 12 séries · 28 min 45 s | 8 séries · 19 min 20 s | 4 séries · 9 min 55 s |
| Régulier, références récentes | 12 séries · 28 min 45 s | 8 séries · 19 min 20 s | 4 séries · 9 min 55 s |
| Reprise après 90 jours | 12 séries · 28 min 45 s | 8 séries · 19 min 20 s | 4 séries · 9 min 55 s |
| Un haltère fixe de 6 kg | 12 séries · 25 min 00 s | 8 séries · 16 min 10 s | 4 séries · 7 min 20 s |
| Sans matériel sportif | 9 séries · 16 min 10 s | 6 séries · 10 min 15 s | 3 séries · 4 min 20 s |
| Repos observés plus longs | 12 séries · 36 min 45 s | 8 séries · 23 min 20 s | 4 séries · 9 min 55 s |

Sans matériel sportif, le moteur ne trouve que trois familles faisables : pousser, genou, hanche. Le tirage est omis explicitement ; aucun mouvement ni équipement n’est inventé pour atteindre quatre.

## Reprise et estimation : deux limites à conserver visibles

Après 90 jours, le mode normal garde ici **10 kg / 10 répétitions** et marque les références `reconfirmation_pending`. Le mode `recalibration` explicite passe à **8 kg**, avec cibles 8 / 6 / 8 / 8. Sous A, il reste pourtant à douze séries ; sous C, à huit. Le questionnaire d’onboarding et ce mode de reprise sont deux mécanismes distincts : supprimer le premier ne doit pas supprimer le second.

L’estimation utilise les durées d’exécution fixes par série du catalogue, les deux côtés, les transitions et le repos entre séries. Elle ne modélise pas le rythme réel et ne croît pas actuellement avec le passage de 6 à 10 répétitions. Ainsi, les cas débutant et régulier ont la même estimation pour un même volume. Les repos observés de 150 s sont bien pris en compte : C passe de 19 min 20 s à 23 min 20 s. Cela justifie un affichage indicatif, pas une promesse de durée exacte.

## Décision proposée à arbitrer

- Point de départ automatique C : jusqu’à quatre repères réellement faisables, **au plus deux séries par repère**, bornées par le catalogue ; aucune compensation pour une famille absente, aucun complément/cardio ajouté pour remplir le temps.
- Mode allégé : réutiliser la réduction existante, soit une série par repère dans ces cas. C’est une modification explicite par rapport à la première proposition « trois en normal / deux en allégé ».
- Garder les références et mécanismes de confirmation/recalibration actuels. Le passage du temps ne prouve pas à lui seul une nouvelle capacité ; dans le cas de reprise, le signal de reconfirmation reste à traiter par le parcours existant.
- Ne pas augmenter automatiquement les séries sur la base d’un simple qualificatif d’expérience, d’une durée disponible ou de références sans volume. Une adaptation future du nombre de séries devra recevoir des faits comparables de volume, avec leur ancienneté et provenance ; ce lot n’ajoute ni ces données au moteur ni un import.
- Retirer le questionnaire uniquement du démarrage V2 est compatible avec les cas testés. Conserver les réponses enregistrées, la garde V1 et le mode de recalibration de reprise. L’activation du retrait reste une étape ultérieure.

**Contre-cas** : un pratiquant ayant effectivement toléré trois séries comparables peut trouver C trop réduit. Le banc actuel ne permet pas au moteur de distinguer ce fait d’une référence issue d’une seule série. Il faut traiter cette perte d’information avant de présenter un volume personnalisé comme démontré. Le plafond C est un départ prudent au sens du nombre de séries prescrit, pas une règle physiologique validée.

## Protections et isolation exécutées

- Douleur : arrêt prioritaire, aucune alternative chargée, travail confirmé conservé ; un travail déjà retiré n’est pas réintroduit par le passage du temps.
- Configuration inconnue, inventaire absent, version incompatible, entrée temporelle négative et périmètre hors standard : réponses de refus/validation conservées. Un seul haltère ne devient jamais une paire.
- Refus de mouvements en séance active : pas de restauration par la voie sans échéance.
- Reprise : snapshot synthétique encodé/décodé, deux séries déjà confirmées et une restante sur le premier mouvement. Les trois variantes conservent exactement les séries restantes, les doses et les confirmations, même avec zéro seconde restante. Aucun recalcul au nouveau plafond sur une séance existante.
- Dépassement : même plan automatique pour demandes 20 et 45 minutes avec zéro seconde restante ; le réducteur expérimental conserve le travail fourni. La voie publique historique continue de retirer du travail avec zéro seconde restante.
- Release : `.releaseV2` reste bloquée sur les mouvements non approuvés ; aucune retombée silencieuse vers le catalogue Preview.
- **60 sorties publiques avant/après identiques octet par octet**, dont 20/30/45 × six cas × trois modes, trois reprises actives et trois transitions de fin dans le temps. Le moteur « avant » a été recompilé depuis sa copie de départ, avec le même enregistreur public.

## Questionnaire : résultat du vrai bridge natif

[Protocole et résultats calibration](CALIBRATION.md) : 90 comparaisons de préparation complète, avec et sans deux séances synthétiques réellement confirmées dans les snapshots. Absence de réponses, foundation/established et réponses stockées non confirmées donnent des préparations V2 identiques à entrées comparables. Les références `kept` montrent que l’historique est consommé. V1 conserve des décisions distinctes et sa garde de calibration. Les payloads, réponses et dates stockés dans le conteneur mémoire ne changent pas.

## Détails par cas

[Résultats structurés complets](results.json) contient les entrées exactes de chaque appel, toutes les sorties, raisons moteur, configurations et contrôles. Le temps de référence du banc Swift est `2026-09-07T12:00:00Z`. `durationMinutes: 30` est conservé dans le format d’entrée historique pour le banc mais n’influence pas la voie automatique ; cette indépendance est vérifiée. La calibration native utilise sa propre date fixe décrite dans son protocole.

### Sans historique

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1},{"category":"adjustable_dumbbell","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[4,6,8,10,12,16],"units":2}].

Soutiens déclarés : floor_allowed, stable_hand_support, stable_incline_support, seated_support, wall_available, overhead_clearance, travel_space.

Historique : aucun.

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Rowing unilatéral avec appui — `supported_one_arm_row__adjustable` | 8 par côté | 4 kg au total | 90 s | `new` | 8 par côté · 4 kg au total |
| Développé au sol avec haltères — `dumbbell_floor_press__adjustable` | 6 | 4 kg par haltère | 90 s | `new` | 6 · 4 kg par haltère |
| Goblet squat — `goblet_squat__adjustable` | 8 | 4 kg au total | 90 s | `new` | 8 · 4 kg au total |
| Soulevé de terre roumain — `dumbbell_romanian_deadlift__adjustable` | 8 | 4 kg par haltère | 90 s | `new` | 8 · 4 kg par haltère |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |

Raisons moteur observées : `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

### Régulier, références récentes

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1},{"category":"adjustable_dumbbell","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[4,6,8,10,12,16],"units":2}].

Soutiens déclarés : floor_allowed, stable_hand_support, stable_incline_support, seated_support, wall_available, overhead_clearance, travel_space.

Historique synthétique : 2026-09-01T12:00:00Z, 2026-09-03T12:00:00Z, 2026-09-05T12:00:00Z. Chaque entrée porte les configurations listées ci-dessous comme complétées, avec références 10 kg / 10 répétitions ; les séries ne figurent pas dans ce format V2. 

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Rowing unilatéral avec appui — `supported_one_arm_row__adjustable` | 10 par côté | 10 kg au total | 90 s | `kept` | 8 par côté · 8 kg au total |
| Développé au sol avec haltères — `dumbbell_floor_press__adjustable` | 10 | 10 kg par haltère | 90 s | `kept` | 6 · 8 kg par haltère |
| Goblet squat — `goblet_squat__adjustable` | 10 | 10 kg au total | 90 s | `kept` | 8 · 8 kg au total |
| Soulevé de terre roumain — `dumbbell_romanian_deadlift__adjustable` | 10 | 10 kg par haltère | 90 s | `kept` | 8 · 8 kg par haltère |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |

Raisons moteur observées : `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

### Reprise après 90 jours

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1},{"category":"adjustable_dumbbell","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[4,6,8,10,12,16],"units":2}].

Soutiens déclarés : floor_allowed, stable_hand_support, stable_incline_support, seated_support, wall_available, overhead_clearance, travel_space.

Historique synthétique : 2026-06-09T12:00:00Z. Chaque entrée porte les configurations listées ci-dessous comme complétées, avec références 10 kg / 10 répétitions ; les séries ne figurent pas dans ce format V2. 

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Rowing unilatéral avec appui — `supported_one_arm_row__adjustable` | 10 par côté | 10 kg au total | 90 s | `reconfirmation_pending` | 8 par côté · 8 kg au total |
| Développé au sol avec haltères — `dumbbell_floor_press__adjustable` | 10 | 10 kg par haltère | 90 s | `reconfirmation_pending` | 6 · 8 kg par haltère |
| Goblet squat — `goblet_squat__adjustable` | 10 | 10 kg au total | 90 s | `reconfirmation_pending` | 8 · 8 kg au total |
| Soulevé de terre roumain — `dumbbell_romanian_deadlift__adjustable` | 10 | 10 kg par haltère | 90 s | `reconfirmation_pending` | 8 · 8 kg par haltère |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 28 min 45 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 19 min 20 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |

Raisons moteur observées : `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `progression_held_reference_to_reconfirm` : La prescription est conservée en attendant une nouvelle exposition comparable.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

### Un haltère fixe de 6 kg

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1},{"category":"fixed_dumbbell","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[6],"units":1}].

Soutiens déclarés : floor_allowed, stable_hand_support.

Historique : aucun.

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Rowing unilatéral avec appui — `supported_one_arm_row__fixed` | 8 par côté | 6 kg au total | 90 s | `new` | 8 par côté · 6 kg au total |
| Pompes — `push_up` | 6 | Poids du corps | 75 s | `new` | 6 · Poids du corps |
| Goblet squat — `goblet_squat__fixed` | 8 | 6 kg au total | 90 s | `new` | 8 · 6 kg au total |
| Pont fessier — `glute_bridge` | 10 | Poids du corps | 75 s | `new` | 10 · Poids du corps |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 25 min 00 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 16 min 10 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 7 min 20 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2, 2 | 8 | 16 min 10 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1, 1 | 4 | 7 min 20 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 25 min 00 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 16 min 10 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 7 min 20 s |

Raisons moteur observées : `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

### Sans matériel sportif

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1}].

Soutiens déclarés : floor_allowed, wall_available.

Historique : aucun.

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Pompes — `push_up` | 6 | Poids du corps | 75 s | `new` | 6 · Poids du corps |
| Squat — `squat` | 8 | Poids du corps | 75 s | `new` | 8 · Poids du corps |
| Pont fessier — `glute_bridge` | 10 | Poids du corps | 75 s | `new` | 10 · Poids du corps |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3 | 9 | 16 min 10 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2 | 6 | 10 min 15 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1 | 3 | 4 min 20 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2 | 6 | 10 min 15 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1 | 3 | 4 min 20 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3 | 9 | 16 min 10 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2 | 6 | 10 min 15 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1 | 3 | 4 min 20 s |

Raisons moteur observées : `anchor_omitted_no_compatible_movement` : Aucun mouvement propre et compatible ne couvre cet ancrage aujourd'hui.; `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

### Repos observés plus longs

Inventaire exact : [{"category":"bodyweight","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[],"units":1},{"category":"adjustable_dumbbell","optionIDs":[],"optionProgressionIsDeclared":false,"perUnitWeightsKg":[4,6,8,10,12,16],"units":2}].

Soutiens déclarés : floor_allowed, stable_hand_support, stable_incline_support, seated_support, wall_available, overhead_clearance, travel_space.

Historique synthétique : 2026-09-01T12:00:00Z, 2026-09-03T12:00:00Z, 2026-09-05T12:00:00Z. Chaque entrée porte les configurations listées ci-dessous comme complétées, avec références 10 kg / 10 répétitions ; les séries ne figurent pas dans ce format V2. Chacune porte aussi 90 s prévus / 150 s observés pour chaque configuration.

| Mouvement / configuration exacte | Répétitions normal/allégé | Charge normal/allégé | Repos | Statut référence | Cible et charge en recalibration |
|---|---|---|---|---|---|
| Rowing unilatéral avec appui — `supported_one_arm_row__adjustable` | 10 par côté | 10 kg au total | 150 s | `kept` | 8 par côté · 8 kg au total |
| Développé au sol avec haltères — `dumbbell_floor_press__adjustable` | 10 | 10 kg par haltère | 150 s | `kept` | 6 · 8 kg par haltère |
| Goblet squat — `goblet_squat__adjustable` | 10 | 10 kg au total | 150 s | `kept` | 8 · 8 kg au total |
| Soulevé de terre roumain — `dumbbell_romanian_deadlift__adjustable` | 10 | 10 kg par haltère | 150 s | `kept` | 8 · 8 kg par haltère |

| Mode | Variante | Décision | Séries par mouvement | Total | Estimation |
|---|---|---|---|---|---|
| normal | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 36 min 45 s |
| normal | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 23 min 20 s |
| normal | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | A — maximum catalogue | `generate_session` | 2, 2, 2, 2 | 8 | 23 min 20 s |
| light | C — plafond à 2 | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |
| light | B — minimum catalogue | `no_clean_session` | — | 0 | — |
| recalibration | A — maximum catalogue | `generate_session` | 3, 3, 3, 3 | 12 | 36 min 45 s |
| recalibration | C — plafond à 2 | `generate_session` | 2, 2, 2, 2 | 8 | 23 min 20 s |
| recalibration | B — minimum catalogue | `generate_session` | 1, 1, 1, 1 | 4 | 9 min 55 s |

Raisons moteur observées : `light_mode_user_selected` : La personne a choisi une séance allégée.; `light_plan_unavailable` : Aucune réduction utile ne respecte le bloc minimal.; `recalibration_user_selected` : La personne a choisi de retrouver ses repères..

## Reproduction, sources et statut de preuve

Depuis le dépôt Cadence :

```bash
LBS_AUTOMATIC_BENCH_OUTPUT=/tmp/lbs-automatic-bench swift test --package-path ios/CadenceEngine --scratch-path /tmp/lbs-automatic-policy-build --filter AutomaticPolicyBenchTests
```

Le banc est dans `ios/CadenceEngine/Tests/CadenceEngineTests/AutomaticPolicyBenchTests.swift`. Les seules modifications de logique sont des paramètres internes optionnels dans `CadenceEngineV2.swift`. Le dispatcher public ne les fournit jamais. Aucun modèle persistant, appel UI, StoreKit, notification, collecte ou import n’est modifié. Le test natif ajouté est `ios/OpenCadence/OpenCadenceTests/V2CalibrationEquivalenceTests.swift`.

- `results.json` : observations complètes, y compris résultats bloquants attendus ; aucune donnée personnelle.
- `public-before.json` / `public-after.json` et `isolation.json` : preuve de non-activation publique. `engine-start-to-experiment.patch` documente le delta exact depuis le début de ce lot, indépendamment du dossier iOS déjà non suivi par Git.
- `engine-tests.log` : suite moteur complète, PASS. `before-tests.log` / `after-tests.log` : recorder public avant/après, PASS. `calibration-tests.log` : suite native ciblée, PASS.
- Revue indépendante finale : PASS du delta, des résultats et des protections, puis PASS de la cohérence entre le rapport et sa recommandation. Le verdict porte sur la cohérence de l’expérience, pas sur l’adéquation clinique du volume.
- Typecheck web annexe : PASS. Le build Turbopack a rencontré une restriction de création de processus/port ; le build alternatif `next build --webpack` est PASS, consigné dans `web-webpack-build.log`, sans modification de configuration.

Profil QC : banc privé natif ; Release local = PASS sur les contrôles Swift exécutés, Product = OBSERVÉ pour les conséquences / INCONCLUSIF pour efficacité et tolérance physiologique. Publication, SEO, commerce et collecte = N/A dans ce lot. Aucun checkpoint Cadence n’est présent dans le hub de ce worktree ; ce rapport conserve le checkpoint local et les preuves. Prochain déclencheur : arbitrage sur C et sur la transmission future de faits de volume, avant toute activation.

**Aucune justification scientifique nouvelle n’est avancée.** Les bornes du catalogue et le seuil existant de reconfirmation sont des conventions de produit dans cette expérience. Tester des invariants et des profils synthétiques ne prouve pas qu’une dose est adaptée à une personne. Aucun commit, push ou publication ; aucune lecture/écriture de données personnelles.
