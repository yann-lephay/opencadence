# Hébergement — 2026-09-09

## État vérifié

Service installé sur le VPS existant `159.195.201.29`, dossier
`/opt/lbs-session-sharing`, conteneur `lbs-session-sharing`. Configuration :
[compose.yaml](compose.yaml). Pas de port publié ; routage prévu par le proxy
Traefik existant sur le réseau Docker `coolify`.

**DNS et HTTPS validés :** enregistrement `A collecte -> 159.195.201.29`
(DNS only), visible dans Cloudflare et résolu par 1.1.1.1. Le certificat de
`https://collecte.labonneseance.com` est accepté sans contournement TLS.
Réponse sans authentification : HTTP 401 attendu. Conteneur : healthy.

L’URL reste absente du build iOS. Politique publique publiée et vérifiée en FR/EN/ES/DE
(commit site 4241b46). Déclarations Apple encore en attente : session expirée.
Aucun utilisateur réel collecté.

## Preuves

- Trois tests locaux passent : consentement/isolation/idempotence/révocation,
  copie SQLite lisible et effacement de sauvegarde, échec de renouvellement
  conservant la copie antérieure.
- Sur le service VPS : consentement, envoi fictif, retry idempotent, présence SQL,
  effacement, sauvegarde supprimée, retry révoqué rejeté : PASS.
- Redémarrage effectué ; inspection privée : `[]` (zéro séance).
- Test externe HTTPS : consentement, envoi, retry, GET refusé, suppression,
  rejet après révocation : PASS. Inspection serveur finale : `[]`.
- Test natif sur simulateur dédié → HTTPS public → suppression : PASS le 9 septembre.
  Journal synthétique en mémoire, aucune donnée ni trousseau utilisateur.
  Voir AppStoreMetadata/SESSION-SHARING-PRIVACY.md. Pas de recette sur iPhone physique.

## Exploitation privée

```sh
ssh root@159.195.201.29 'docker exec lbs-session-sharing node /app/inspect.mjs'
ssh root@159.195.201.29 'docker exec lbs-session-sharing node /app/inspect.mjs <pseudonyme>'
ssh root@159.195.201.29 'cd /opt/lbs-session-sharing && docker compose ps'
```

La base est `/opt/lbs-session-sharing/data/sessions.sqlite`, propriétaire 1000,
mode 0600, dossier 0700. Pas de tableau de bord public. Ne pas copier les résultats
réels dans Git ou dans un rapport. Gestion du service par SSH/Compose, pas par une
nouvelle application Coolify.

## Sauvegarde

Une seule copie `sessions-backup.sqlite`, renouvelée après environ 24 heures
(service actif), via VACUUM INTO temporaire puis renommage. En cas d’échec,
l’ancienne copie reste disponible. Toute suppression ou purge invalide la copie
et son temporaire ; la prochaine maintenance repart de la base courante.
Aucune archive externe ajoutée. Cette copie sur le même disque ne protège pas
contre la perte du VPS. La rétention de 90 jours est appliquée au démarrage et
chaque heure de fonctionnement.

Restauration uniquement après arrêt du collecteur et vérification privée de
l’intégrité et de la date de la copie. Ne jamais restaurer une archive ancienne
qui réintroduirait des données supprimées. Conserver la base endommagée hors
service pour diagnostic privé, remplacer la base par la copie valide avec droits
1000:1000 / 0600, puis redémarrer et vérifier l’intégrité. Pas de restauration
automatique ni de sauvegarde vers un prestataire supplémentaire.
