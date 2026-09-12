# Cadence stop-motion — audit des prototypes

Date : 4 septembre 2026.

> Historique de cadence, remplacé pour les décisions actuelles par
> `catalog-review.json` et `CATALOG-REVIEW.md` (revue du 5 septembre).
> Les nombres ci-dessous ne prouvent pas la correction du geste. La nouvelle
> inspection a retiré certaines poses et rejeté plusieurs sources dites ici
> « acceptables ». Le rowing à quatre poses reste un candidat visuel : le quota
> d'images ne justifie pas de remplacer une source cohérente par une moins bonne.

## Décision de travail

La référence reste le squat gobelet précédemment validé : six poses distinctes,
onze étapes aller-retour et une boucle de 3,77 secondes.

La cible des prochains médias est de six à huit poses réellement distinctes sur
l'aller, soit onze à quinze étapes affichées lorsque le retour peut reprendre
les mêmes poses. Treize étapes constituent la cible confortable, mais douze
n'est pas un quota justifiant des doublons, du morphing ou une nouvelle source
moins cohérente.

Les images presque identiques ne comptent pas comme des poses supplémentaires.
Une nouvelle pose n'est retenue que si elle réduit un saut perceptible tout en
préservant le corps, les appuis, le matériel, le décor, l'échelle et le cadrage.

## Inventaire des boucles retenues

| Mouvement | Poses aller | Étapes aller-retour | Décision de cadence |
| --- | ---: | ---: | --- |
| `incline_push_up` | 8 | 15 | suffisante |
| `dumbbell_romanian_deadlift` | 8 | 15 | suffisante, mais média à corriger pour le décor |
| `wall_hip_hinge` | 7 | 13 | suffisante |
| `dumbbell_floor_press` V12 | 7 | 13 | cadence suffisante, média encore rejeté pour les mains et prises |
| `push_up` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `squat` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `glute_bridge` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `kettlebell_deadlift` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `goblet_squat` | 6 | 11 | référence validée, ne pas modifier pour atteindre un quota |
| `band_overhead_press` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `seated_dumbbell_overhead_press` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `supported_calf_raise` | 6 | 11 | acceptable ; compléter seulement si un saut est visible |
| `single_arm_dumbbell_floor_press` | 5 | 9 | source plus dense souhaitable |
| `assisted_split_squat` | 5 | 9 | source plus dense souhaitable |
| `split_squat` | 5 | 9 | source plus dense souhaitable |
| `double_dumbbell_front_squat` | 5 | 9 | source plus dense souhaitable |
| `supported_one_arm_row` | 4 | 7 | insuffisante pour la cible actuelle ; nouvelle source nécessaire |

## Résultat du test de complétion

Trois essais ont été effectués sur `supported_one_arm_row` à partir de ses quatre
poses validées : une planche couvrant le cycle complet, une pose unitaire entre
deux ancres et une planche limitée à la montée.

Les planches produisent surtout des doublons près des extrémités et seulement
quatre hauteurs réellement distinctes. La pose unitaire change le cadrage et
saute vers une flexion trop avancée. Ces sorties sont donc rejetées.

Conclusion : les poses manquantes ne doivent pas être fabriquées isolément pour
remplir un quota. Pour les séquences à quatre ou cinq poses, régénérer une
planche complète limitée à une seule phase du mouvement ou utiliser une capture
réelle. Les séquences à six poses restent inchangées tant qu'un contrôle visuel
ne révèle pas de saut gênant.

Un essai supplémentaire limité à la seule descente du `split_squat` confirme la
limite : la génération saute presque directement de la position haute à la
position basse, puis répète des profondeurs très proches. La planche est rejetée
et n'est pas copiée dans le projet.

## Invariants d'assemblage

- boucle cible de 3,5 à 4,2 secondes ;
- cadrage et échelle fixes ;
- aucun zoom, fondu, morphing ou interpolation du corps ;
- retour miroir uniquement lorsque la trajectoire inverse est correcte ;
- légère pause possible au point terminal, sans dupliquer artificiellement une
  pose pour annoncer davantage d'images ;
- aucune modification du `MovementMediaManifest` avant validation explicite du
  paquet vidéo, poster, fallback et texte accessible.
