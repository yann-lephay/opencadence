# Doctrine 80/20 d’OpenCadence

Statut : règles intégrées au moteur le 26 juillet 2026 à partir de la recherche
fournie pour OpenCadence.

## Verdict produit

OpenCadence n’est pas un calendrier hebdomadaire. C’est un planificateur roulant du
prochain entraînement. Il cherche le déficit d’exposition des 7 et 21 derniers
jours, puis compose une séance complète dans le temps disponible.

La version sobre repose sur :

1. quatre ancrages full body : tirage, poussée, dominante genou et charnière ;
2. des crédits de séries sur 7 et 21 jours ;
3. une progression d’abord par les répétitions ;
4. des supersets non concurrents ;
5. quatre états d’autorégulation ;
6. un rameur intense conditionnel.

## Règles du moteur

### Séance complète

Chaque séance adaptative contient autant que possible un tirage, une poussée,
une dominante genou et une charnière compatibles avec le matériel déclaré.
Ainsi, une seule séance dans une semaine reste utile. Les séries supplémentaires
vont aux familles les moins exposées et aux priorités du profil local.

Les paires sont :

- A : tirage + dominante genou ;
- B : poussée + charnière ;
- C : épaules + gainage.

Les transitions de 20 à 30 secondes et le repos après le second mouvement
procurent environ deux à trois minutes avant de répéter le même ancrage.

### Volume roulant

Une série compte :

- 1 crédit pour un muscle principal ;
- 0,5 crédit pour un muscle secondaire significatif ;
- 0 pour l’échauffement et le simple rôle stabilisateur.

Les cibles initiales sont exprimées en crédits sur 7 jours. Le score combine le
déficit récent, le déficit moyen sur 21 jours, le temps depuis la dernière
exposition et les priorités explicitement enregistrées dans le profil.

Budgets nominaux :

- 30 minutes : 12 séries principales ;
- 31 à 38 minutes : 14 ;
- 39 à 45 minutes : 16.

Le moteur commence par une à deux séries des ancrages compatibles, puis
distribue au maximum une série de rattrapage par famille selon le déficit. Une
séance allégée reste aussi complète que le matériel le permet mais réduit les
séries.

### Effort et progression

La cible ordinaire est de 2 à 3 répétitions en réserve, notées `RIR`. La dernière
série de chaque exercice reçoit un bouton facultatif `0 / 1 / 2 / 3 / 4+`.

- effort global 7–8, douleur 0–2 : progression normale ;
- effort 9 une fois : pas de progression automatique ;
- effort 9 au moins deux fois sur les trois dernières : environ 65 % du volume,
  3–4 RIR, aucun rameur intense ;
- moins de 24 h depuis la dernière séance : environ 55 %, passage technique ;
- reprise après 8–14 jours : environ 75 %, 3–4 RIR ;
- reprise après plus de 14 jours : environ 60 %, recalibration.

À variante comparable, OpenCadence vise une répétition de plus lorsque l’effort est
au plus 8, la douleur au plus 2 et la dernière série gardait au moins 2 RIR. La
cible reste dans la plage de l’exercice. Les ancrages restent stables ; la
variation aléatoire n’est pas un objectif.

### Rameur

Chaque séance commence par quatre à cinq minutes faciles à RPE 3–4. Un finisher
court n’apparaît que si l’état est vert, la durée disponible au moins 37 minutes
et aucun finisher intense n’a été enregistré dans les sept derniers jours. Il
vient après la musculation.

### Douleur et sécurité

OpenCadence ne qualifie jamais une douleur de « normale ».

- 0–2 : surveiller si la sensation reste stable et la technique intacte ;
- 3–4 : arrêter la série, réduire l’amplitude ou substituer ;
- 5+, douleur vive ou électrique, perte de force, instabilité ou compensation :
  arrêter l’exercice ;
- oppression thoracique, malaise, syncope, symptôme neurologique ou
  essoufflement sévère inhabituel : arrêter la séance et rechercher une
  évaluation appropriée.

La zone douloureuse est enregistrée séparément. Si une douleur persiste, affecte
les activités quotidiennes ou revient sur plusieurs expositions, l’application
doit conseiller un avis professionnel plutôt que diagnostiquer.

## Données conservées

Pour chaque séance : horodatage, temps, variante, équipement prévu, répétitions
ou durée ou distance, bande de repos, RIR de la dernière série, douleur, zone,
RPE global, présence d’un finisher rameur et notes.

## Personnalisation physique

Les mensurations, photos, observations morphologiques et priorités d’une
personne restent dans sa copie locale et ne font pas partie de cette doctrine
publique. Une photo seule ne permet pas de mesurer la force, la mobilité, le
taux de masse grasse ou la tolérance d’un mouvement.

Le moteur public part donc d’un équilibre neutre. Les performances enregistrées,
la gêne, la récupération et les priorités explicitement saisies déterminent
ensuite la répartition du volume.

## Références déterminantes

- Currier et al., ACSM Position Stand 2026, DOI
  `10.1249/MSS.0000000000003897`.
- Pelland et al., dose-réponse volume/fréquence 2026, DOI
  `10.1007/s40279-025-02344-w`.
- Ramos-Campo et al., full body contre split 2024, DOI
  `10.1519/JSC.0000000000004774`.
- Robinson et al., proximité de l’échec 2024, DOI
  `10.1007/s40279-024-02069-2`.
- Singer et al., temps de repos 2024, DOI
  `10.3389/fspor.2024.1429789`.
- Zhang et al., supersets 2025, DOI `10.1007/s40279-025-02176-8`.
- Held et al., entraînement concurrent 2026, DOI
  `10.1007/s40279-026-02401-y`.

Toute sophistication future doit améliorer l’adhésion, la mesure ou la sécurité,
et non simplement rendre l’algorithme plus impressionnant.
