# Images 2.5 — test stop-motion du rowing unilatéral

Date : 9 septembre 2026.

Statut : prototype de revue locale, non intégré, non publiable et non marqué
`ready`. L'essai unitaire est rejeté ; le nouvel essai bulk est un candidat
visuel distinct, encore non validé.

## Objectif

Tester le modèle d'image intégré à Codex après l'annonce de ChatGPT Images 2.5,
sur le même mouvement qui avait échoué à produire des poses intermédiaires
fiables avec le modèle précédent.

Le modèle exact n'est pas exposé par l'outil intégré. L'annonce OpenAI indique
qu'Images 2.5 est disponible dans Codex depuis le 8 septembre 2026.

## Méthode de l'essai unitaire

- exercice : `supported_one_arm_row` ;
- édition image par image pour établir une base de comparaison avant l'essai
  bulk séparé ;
- `pose_01` utilisée comme base visuelle exacte et `pose_02` comme référence de
  trajectoire ;
- une seule modification demandée : avancer le bras droit et l'haltère de 45 %
  vers la pose suivante ;
- invariants répétés dans le prompt : personnage, visage, buste, appuis, main
  gauche, banc, décor, cadrage, échelle, lumière, texture et palette ;
- comparaison des trois images adjacentes avant assemblage ;
- boucle technique de 4 secondes, sans interpolation, zoom, fondu ni morphing.

## Prompt de la sortie testée puis rejetée

```text
Use case: precise-object-edit
Asset type: one square stop-motion exercise frame for La Bonne Séance
Input images: Image 1 is the edit target and exact visual base. Image 2 is the next-pose motion reference only.
Primary request: Create exactly one anatomically plausible intermediate frame 45% of the way from Image 1 toward Image 2. Change only the exerciser's right pulling arm: gently flex the right elbow, slide the right elbow slightly backward close to the torso, and raise the right hand plus the single dumbbell along the same rowing trajectory toward Image 2. Keep the hand gripping the same dumbbell rigidly; keep the wrist neutral. The intermediate must be visibly distinct from both endpoints and must not jump close to Image 2.
Subject and technique: supported one-arm dumbbell row; left palm remains planted on the bench, torso and spine remain fixed, hips and legs remain fixed, feet remain planted.
Style/medium: preserve Image 1 exactly: same warm editorial illustration, ink texture, palette, lighting, grain, linework and level of detail.
Composition/framing: preserve Image 1 pixel-level composition, square crop, camera angle, body scale and all object positions except the right forearm, right elbow, right hand and dumbbell.
Constraints: change only the right elbow, right forearm, right hand and dumbbell. Preserve the exact same woman, face, expression, hairstyle, clothing, body proportions, torso, shoulders except the minimal anatomically required right shoulder rotation, left arm and left hand, hips, legs, shoes, bench, mat, floor, wall, shadows, crop, scale and perspective. One frame only. No text. No watermark.
Avoid: redesign, photorealism, new props, extra dumbbells, altered anatomy, changing the bench, changing the background, zoom, camera drift, crop drift, morphing, blur, duplicated limbs, wrist bending, elbow flaring.
```

## Résultat

Le modèle conserve beaucoup mieux la direction visuelle que l'essai précédent :
le décor, le matériel, les appuis et le personnage restent cohérents à l'œil.
La conservation n'est toutefois pas pixel-stable : les contours et la texture
sont encore légèrement redessinés sur l'ensemble de l'image.

Surtout, la comparaison adjacente montre que la première sortie dépasse déjà
`pose_02` : l'haltère et le coude montent trop haut, puis reculent lorsque la
boucle revient sur la vraie `pose_02`. Deux autres essais entre `pose_02` et
`pose_03` dépassent eux aussi la cible, y compris avec une consigne de
micro-déplacement. Aucun intermédiaire généré n'est donc retenu.

Verdict : progrès net sur la conservation du personnage, du décor et du style.
Dans ce test, le modèle intégré n'a pas contrôlé assez finement la trajectoire
pour produire un intermédiaire exploitable.

## Fichiers

- `comparison_pose01_candidate_pose02.png` : comparaison adjacente montrant le
  dépassement ;
- `rejected_01_02_overshoot.png` : sortie originale rejetée, 1 254 × 1 254 ;
- `supported_one_arm_row_images25_overshoot_demo.mp4` : boucle technique de
  démonstration 612 × 612, H.264, 30 fps, 4 secondes. Elle rend visible le recul
  entre la sortie générée et la vraie `pose_02` ; ce n'est pas un média candidat.
- `bulk-v01/` : planche 3 × 3 générée en une fois, neuf poses extraites et boucle
  de revue de quatre secondes. C'est le résultat prometteur du test, encore
  classé `visual_candidate_not_release`.
