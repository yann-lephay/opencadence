# Déclaration Apple — partage facultatif des séances

Préparation du 9 septembre 2026. **Pas encore saisie/publiée dans App Store Connect.**
La session Apple a expiré ; reconnexion demandée. Ne pas activer l’URL dans le
build distribué avant vérification des déclarations et de la politique publique.

## Réponses proposées

- Collecte : oui, même si optionnelle et réservée aux utilisateurs payants.
- Santé et activité physique → Activité physique / Fitness : oui.
  Exercices, séries, répétitions/durées, charges, repos, date et interruption.
- Identifiants → Identifiant utilisateur / User ID : oui.
  Empreinte d’un identifiant d’inscription aléatoire reliant les séances.
- Contenu utilisateur → Autres contenus utilisateur / Other User Content :
  appréciation facultative et précision structurée du bilan (aucun texte libre).
- Finalité : Analyse / Analytics (examiner les recommandations et améliorer le moteur).
- Liées à l’utilisateur : oui, choix prudent puisque l’historique est relié au
  même pseudonyme. Ni nom ni compte Apple transmis au collecteur.
- Suivi / Tracking : non. Aucun rapprochement publicitaire, courtier ou données tierces.

Les versions moteur/catalogue qualifient les rapports, sans crash, identifiant
matériel ou journal de navigation. Aucun champ douleur/symptôme/menstruation/texte
libre envoyé. Ne pas ajouter la catégorie Health sur la seule présence locale de
ces informations. Vérifier le reste de l’app et les champs déjà déclarés : cette
liste porte sur le delta collecte, pas sur une attestation générale de tous les SDK.
Les achats sont traités par StoreKit et non reçus par ce collecteur.

L’exception de déclaration facultative Apple ne convient pas : les rapports sont
récurrents après consentement, pas de rares retours occasionnels.

## URLs

- FR https://labonneseance.com/confidentialite
- EN https://labonneseance.com/en/privacy
- ES https://labonneseance.com/es/privacidad
- DE https://labonneseance.com/de/datenschutz

## Sources vérifiées

- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- https://www.cnil.fr/fr/quest-ce-ce-quune-donnee-de-sante
- https://www.cnil.fr/fr/quelles-formalites-pour-les-traitements-de-donnees-de-sante

Ces références éclairent les déclarations ; elles ne constituent ni une validation
juridique indépendante ni une approbation Apple.

## Recette technique

5 tests de protection natifs PASS. Test hébergé distinct PASS sur simulateur dédié,
transport URLSession réel en HTTPS : création d’un accord fictif, rapport synthétique,
accusé reçu, arrêt/suppression sans droit payant, nouvelle écriture rejetée HTTP410.
Journal et inscription en mémoire, aucun trousseau ni historique utilisateur.
Inspection SQL après test : zéro rapport.
Logs : /tmp/lbs-sharing-activation.log et /tmp/lbs-sharing-hosted.log.
Le test hébergé est ignoré par défaut ; activer LBS_TEST_HOSTED_SHARING=1 dans
EnvironmentVariables du fichier xctestrun généré pour une exécution volontaire.
