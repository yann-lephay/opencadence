# Blocs, variété et travail récent — 8 septembre 2026

Implémentation locale dans le moteur Swift et le parcours iOS personnalisé. Aucun fichier de données personnelles, nouveau mouvement, service distant ou publication.

## Comportement

- L’ordre avance après une séance distincte contenant au moins un mouvement complètement confirmé sur deux séries ou plus. Préparer, rouvrir, restaurer ou confirmer une seule série ne fait pas avancer cette rotation. Les événements dupliqués ne comptent pas à nouveau.
- Les mouvements haut/bas sans contribution musculaire principale commune peuvent alterner. Deux partenaires chargés doivent avoir exactement la même configuration de charge ; sinon ils restent groupés. Après une correction de charge incompatible, le bloc termine les séries du premier partenaire avant le second. Les repos prescrits et les démarrages manuels sont conservés.
- Les variantes ne tournent que toutes les trois séances qualifiantes et parmi les options ayant chacune deux expositions complètes récentes et une capacité suffisante dans leur configuration propre. Un choix local explicite prévaut. Il n’y a pas de changement vers une variante inconnue pour créer de la nouveauté.
- Deux séances distinctes dans les 48 heures ayant chacune un mouvement entièrement confirmé sur au moins deux séries et sollicitant principalement un même muscle permettent de proposer une série de moins sur le mouvement concerné, dans les bornes du catalogue : 3→2 ou 2→1. Pas de hausse simultanée de charge ou de répétitions. Une préférence habituelle reste mémorisée ; une décision explicite de séries pour la séance reste prioritaire. La réduction est expliquée près du mouvement.
- Aucune réduction n’est déclenchée par les ouvertures de l’app, les références prospectives, deux exercices d’une seule séance, un travail incomplet ou un signal de sécurité. L’absence de réduction ne certifie pas une récupération.

Ces seuils sont des conventions produit à essayer. Les tests prouvent une cohérence logicielle, pas une efficacité physiologique, une meilleure motivation ou une conversion réelle. Une séance à deux séries peut rester utile et une séance interrompue ne crée aucune dette.

## Exécution et compatibilité

Un résolveur commun pilote prochaine série, aperçu pendant la pause, saut, réglage et estimation native. A×3/B×2 donne A/B/A/B/A. Les blocs sont conservés dans la sauvegarde active ; les anciens snapshots sans blocs gardent leur déroulé groupé. L’estimation conserve chaque repos sauf après la dernière série réelle, et utilise les blocs conservés lors d’une adaptation.

La couverture musculaire reste celle des exercices réellement retenus ; la variation ne répare pas le manque de tirage/ischio-jambiers du catalogue faisable au poids du corps seul.

## Validation

Voir `verification.txt`, `trajectories.json` et les captures. Les trajectoires passent par les services iOS et un stockage SwiftData en mémoire, avec sauvegarde/restauration des confirmations. Le dix-neuvième profil réalise dix séances quotidiennes. Les autres profils couvrent interruption, douleur, reprise, capacité insuffisante, changements de matériel et corrections de charge.

Revue indépendante anti-overengineering : PASS après correction de l’estimation des blocs asymétriques et réutilisation des blocs natifs conservés. Le paiement StoreKit est hors de cette modification ; le test LifetimePurchaseTests reste exclu pour la limitation de simulateur déjà documentée. Le chemin testé est previewV2 ; les gates médias/publication ne sont pas levés.

Résultat final : **48 tests moteur / 7 suites et 116 tests natifs / 13 suites PASS**, dont **190 séances synthétiques**. Build web et typecheck PASS. QC visuel ciblé indépendant PASS sur iPhone13mini. La dernière formulation a été revérifiée sur le simulateur ; VoiceOver et défilement grands textes ne sont pas revalidés dans ce delta.

Le contrôle visuel a révélé un second cas corrigé : pendant le repos, « Passer l’exercice » cible maintenant le prochain mouvement affiché. Le repos et les confirmations restent intacts ; un test protège cette correspondance.

Exemple synthétique quotidien : 8, 8, 4, 8, 8, 4, 8, 8, 4, 8 séries confirmées sur dix jours. L’habitué espacé de trois jours conserve ses 12 séries demandées. Ces trajectoires illustrent la règle, sans démontrer que cette cadence convient physiologiquement à toute personne. La rotation est déterministe et peut devenir reconnaissable ; son bénéfice motivationnel reste à observer.
