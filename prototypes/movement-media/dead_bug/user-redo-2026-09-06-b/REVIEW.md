# Dead bug — reprise B du 6 septembre 2026

## Livrable limité
Aperçu des positions clés : `../review-user-keyposes-v01/dead_bug_review_user_keyposes_v01.mp4`.
Trois poses, quatre étapes (centre → A → centre → B), six secondes. C'est un diaporama diagnostique, PAS une démonstration animée terminée. Aucun intermédiaire n'a été retenu. Pas d'intégration dans l'app ni de promotion du manifeste.

La vue du dessus distingue les deux paires opposées. Le QC indépendant a accepté les extrémités comme candidats lisibles ; cette vue ne permet pas d'établir la hauteur au-dessus du sol ni la position lombaire. Petites différences de visage/torse/vêtements entre générations. La source générale utilisée pour clarifier la séquence est la fiche [NASM Dead Bug](https://www.nasm.org/resource-center/exercise-library/dead-bug) : retour au centre, puis autre bras/jambe opposés. Cette référence ne valide pas nos images.

## Sources
- `center.png` : centre corrigé, bras en perspective vers la caméra.
- `side-a.png` : bras gauche de l'image au-delà de la tête, jambe droite allongée.
- `side-b.png` : bras droit de l'image au-delà de la tête, jambe gauche allongée.
- Toutes créées par imagegen intégré ; prompts exacts associés dans ce dossier.
- `../../deadbug-keypose-selection-2026-09-06.json` fixe les sources et l'ordre, sans miroir ni interpolation.

## Essais non retenus
Triptyque initial : même pose répétée.
Construction oblique : jambes inversées, mais bras/épaules encore ambigus.
Planches intermédiaires : cadrage incompatible, une jambe tronquée, poses trop proches.
Singles a30/a65/b30 : pas une progression coordonnée suffisamment graduelle ; b65 inverse la mauvaise paire.
Early a : mauvaise paire ; early b : déplacement surtout du bras.
Ces fichiers sont archivés avec suffixes rejected/unused pour ne pas les réintroduire par erreur.

## Tests
- Rendu six secondes : H264, 612×612, 30fps, 180 images encodées ; décodage complet sans erreur.
- Test du renderer sans durée explicite : quatre secondes, 120 images ; décodage complet sans erreur.
- La durée est un paramètre facultatif local au montage, défaut quatre secondes. Pas de moteur d'animation ajouté.
- Catalogue : 42 références et fichiers contrôlés, 41 candidats et un needs_fix (dead_bug).
- Manifeste iOS SHA256 inchangé : f72f369f684fb2d210140f26f3f381aea8085c90bf78b8017c339d7b5a19e247.
- Pompes : acceptation visuelle explicite de review-user-v01 enregistrée, limites de densité et recalage conservées.

## Suite
Faire juger ce nouvel angle par Yann avant de poursuivre les transitions. Le moteur, le comptage des répétitions et le statut de publication restent inchangés. Les 12 images utiles demandées ne sont pas atteintes.

## Retour suivant — rythme raccourci
Yann confirme la lisibilité et propose de conserver les trois poses en raccourcissant la vidéo. Variante `review-user-keyposes-v02` : mêmes pixels sources et même ordre centre → A → centre → B, quatre secondes (une seconde par étape) au lieu de six. Pas de nouvelle génération, pas d'interpolation ni d'intégration. La version six secondes reste intacte. L'angle est accepté ; le nouveau rythme reste à juger. Vérifications : H264 612×612, 120 images à 30fps, décodage complet sans erreur et égalité des pixels RGB des trois poses. La comparaison binaire des PNG différait à cause des métadonnées temporelles, pas des pixels.
