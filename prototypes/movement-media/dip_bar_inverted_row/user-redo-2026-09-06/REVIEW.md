# Rowing inversé — reprise du retour utilisateur

Yann refuse review-v03 pour incohérences et accepte les neuf autres vidéos du lot21–30. Les chemins exacts sont enregistrés dans `../../user-review-21-30-2026-09-06.json`.

## Nouvel aperçu

- `../review-user-v01/dip_bar_inverted_row_review_user_v01.mp4`
- Trois poses sources : bras étendus, position intermédiaire, position haute.
- Cinq étapes : départ → milieu → haut → milieu → départ, sur4secondes. Le retour réutilise explicitement les poses ; aucune interpolation.
- La planche initiale a été écartée sauf sa première case : les autres cases déplaçaient les pieds et le matériel. Les deux autres poses ont été générées à partir de références individuelles.
- Contrôle visuel : les deux mains restent associées aux mêmes poignées, les talons restent au sol, la montée du buste et du bassin est lisible. De légères variations de prise/contour et de texture subsistent. La vue masque en partie les épaules ; ne pas affirmer une validation biomécanique complète.
- Contrôle technique : H.264,612×612,30fps,120images encodées,4secondes ; décodage intégral FFmpeg sans erreur. Ces120images ne sont pas120poses.
- Statut : nouvel essai à revoir par Yann, non intégré. L'ancienne sélection reste `needs_fix` dans le registre et n'est pas remplacée automatiquement.

Images créées avec imagegen intégré. Prompts exacts et provenance dans `generation.json`. Aucune API vidéo payante, aucune modification du moteur, des données personnelles ou du manifeste iOS.
