# Bulk v01 — planche 3 × 3

Statut : prototype de revue locale, non intégré et non publiable.

## Formule testée

Une seule génération produit neuf poses dans une planche 3 × 3. La planche ne
demande que la phase de tirage. La phase de retour réutilise exactement les
mêmes images en sens inverse afin d'éviter un second redessin des mêmes poses.

```text
Use case: scientific-educational
Asset type: production test contact sheet for a stop-motion exercise loop in La Bonne Séance
Input images: Image 1 is the exact identity, style, environment, camera, framing and first-pose reference.
Primary request: Create one clean 3 by 3 contact sheet containing exactly nine equal square animation frames, read left to right and top to bottom. Together, the nine frames show one smooth, anatomically plausible pulling phase of a supported one-arm dumbbell row, from the exact bottom position in Image 1 to the top position with the right elbow close to the torso and the dumbbell beside the lower ribs. Frame 1 must match Image 1. Frames 2 through 8 are evenly spaced intermediate poses at approximately 12.5% increments. Frame 9 is the controlled top position. Every adjacent frame must show a small, clearly visible, evenly sized progression. All nine arm and dumbbell positions must be genuinely distinct; no duplicates and no near-duplicates.
Motion path: only the right upper arm, elbow, forearm, hand and the same single dumbbell move. The right elbow bends progressively and travels backward close to the torso. The dumbbell follows a smooth shallow arc upward and backward. The wrist remains neutral and the right hand remains rigidly wrapped around the same dumbbell. The elbow never flares and never rises above the torso.
Locked invariants across all nine frames: exact same woman, face, expression, hairstyle, clothing, body proportions, torso angle, neutral spine, hips, legs, planted feet, shoes, left shoulder, straight supporting left arm, planted left palm, bench, mat, floor, wall, shadows, warm orange palette, editorial illustration style, ink texture, grain, lighting, camera angle, crop, body scale and perspective. No motion anywhere except the right pulling arm and dumbbell.
Contact-sheet layout: nine equal square cells in a precise 3 by 3 grid with thin uniform pale-cream gutters. Show the full square composition in every cell. No panel may be cropped differently. No labels, numbers, captions, arrows or decorative border.
Constraints: strict locked-camera stop-motion continuity; one subject and one dumbbell per panel; no text; no watermark.
Avoid: duplicated poses, uneven motion jumps, changing identity, face drift, body drift, torso movement, left-hand movement, foot movement, bench drift, background drift, camera drift, zoom, crop changes, style drift, photorealism, morphing, blur, added props, extra dumbbells, duplicated limbs, broken grip, bent wrist, elbow flaring.
```

## Revue visuelle

Points positifs :

- neuf positions du bras et de l'haltère visuellement distinctes ;
- trajectoire ordonnée de bas en haut sans retour arrière entre deux cases ;
- personnage, appuis, banc, décor, cadrage et style remarquablement stables ;
- boucle de quatre secondes assemblée sans interpolation, zoom, fondu ni
  morphing.

Limites :

- `pose_01` ressemble fortement à la référence mais n'en est pas une copie
  pixel-stable ;
- la forme et la perspective de l'haltère varient légèrement ;
- la position haute finit plus près de la hanche que des côtes basses et doit
  recevoir une validation technique humaine ;
- neuf poses aller produisent seize étapes dans la boucle, soit une de plus que
  la cible locale habituelle de onze à quinze ; conserver les neuf pour ce test
  demandé, puis retirer une pose seulement si la lecture vidéo le justifie ;
- le modèle exact n'est pas exposé par l'outil intégré de Codex.

Verdict : le bulk est nettement plus convaincant que les éditions unitaires de
ce test. C'est une formule crédible pour produire un candidat complet en une
fois, mais la planche reste `visual_candidate` tant que la boucle et la position
haute n'ont pas été validées explicitement. Aucun manifeste produit n'est
modifié.
