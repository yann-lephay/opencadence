# OpenCadence

**Un coach d’entraînement adaptatif, local et open source pour faire du sport à
la maison.**

OpenCadence prépare des séances guidées de 30 à 45 minutes, montre chaque
mouvement en quatre étapes, lance les temps de repos et ajuste la suite à partir
de ce que vous avez réellement réussi.

![Aperçu des entraînements OpenCadence](public/assets/opencadence-training.png)

## Pourquoi OpenCadence ?

- **Pas de semaine rigide** : les séances s’enchaînent quand votre agenda le
  permet et l’application conseille le prochain jour pertinent.
- **Votre matériel, pas un catalogue imaginaire** : poids du corps seul,
  haltères, barre de traction, barres de dips, gilet lesté, rameur ou autre
  matériel déclaré.
- **Progression lisible** : répétitions, charge, effort, gêne et marge restante
  servent à adapter les prochaines recommandations.
- **Mouvements compréhensibles** : les exercices illustrés montrent quatre
  positions qui s’animent en boucle, y compris pendant la récupération.
- **Données privées** : aucun compte, aucune base distante. Le profil et
  l’historique restent dans `data/state.json` sur votre ordinateur.

OpenCadence suit une logique 80/20 : assez de variété pour rester motivant, mais
des mouvements suffisamment stables pour mesurer une vraie progression.

## Installation la plus simple avec Codex

Envoyez ce message à Codex :

```text
Installe OpenCadence sur mon ordinateur depuis ce dépôt, lance l’application et
ouvre-la dans mon navigateur. Laisse-moi répondre aux trois étapes de démarrage
avant de modifier le programme :
https://github.com/yann-lephay/opencadence
```

Codex peut alors cloner le projet, installer les dépendances et ouvrir
[http://localhost:3015](http://localhost:3015).

## Installation manuelle

Prérequis : Node.js 20 ou plus récent.

```bash
git clone https://github.com/yann-lephay/opencadence.git
cd opencadence
npm install
npm run dev
```

Sur Mac, vous pouvez ensuite double-cliquer sur
`Lancer OpenCadence.command`. Le premier lancement installe automatiquement les
dépendances manquantes.

## Premier démarrage

Trois étapes suffisent :

1. votre prénom et la durée maximale d’une séance ;
2. quelques repères simples sur les pompes et les tractions ;
3. votre matériel, vos limitations connues et, si vous le souhaitez, un
   contexte physiologique.

Ces réponses choisissent une première séance de calibration. Elles ne servent
pas à appliquer un programme « homme » ou « femme ». Le matériel peut être
corrigé à tout moment dans **Profil**. Si aucune variante illustrée n’est
compatible, OpenCadence retire le mouvement au lieu d’inventer un équipement ou
une charge.

## Comment le programme s’adapte

- Le moteur utilise les répétitions, la marge restante, l’effort et la gêne.
- Les charges suivent une double progression prudente.
- Une charge supérieure n’est proposée qu’après deux validations propres en
  haut de la fourchette.
- Vous confirmez toujours la charge ou le gilet réellement utilisé.
- Le rameur est comparé uniquement à vos propres références réalisées dans des
  conditions similaires.

### Suivi menstruel facultatif

Le sexe ou une phase supposée du cycle ne réduit jamais automatiquement une
séance. Si le suivi est activé, seuls les symptômes déclarés le jour même
peuvent ajuster le volume. La grossesse et le post-partum nécessitent un mode et
un accompagnement dédiés ; le programme standard reste alors désactivé.

La doctrine correspondante est détaillée dans
[`docs/FEMALE-ADAPTATION.md`](docs/FEMALE-ADAPTATION.md).

## Données et confidentialité

`data/state.json` contient le profil, le matériel, les séances, les performances
et les notes. Ce fichier est ignoré par Git : il n’est jamais inclus dans un
commit ou une contribution. Pour plusieurs personnes sur un même ordinateur,
utilisez une copie distincte du dépôt par personne.

Codex peut analyser ce journal local à votre demande. Aucun service d’IA n’est
nécessaire au fonctionnement normal de l’application.

## Contribuer

Les corrections, nouveaux exercices illustrés et améliorations du moteur sont
bienvenus. OpenCadence peut proposer de transformer une amélioration locale en
pull request, mais ne publie jamais automatiquement : le contenu et les fichiers
concernés doivent être montrés, vérifiés puis approuvés explicitement.

Consultez [`CONTRIBUTING.md`](CONTRIBUTING.md) avant d’ajouter un exercice ou de
modifier les règles de progression.

## Soutenir le projet

OpenCadence est gratuit et aucune fonctionnalité n’est réservée aux
contributeurs. Vous pouvez
[offrir un café au projet](https://buy.stripe.com/00w00jeYH06O8si4662VG0c)
avec un montant libre et sans abonnement.

Le paiement est hébergé par Stripe. L’application ne reçoit ni ne conserve de
donnée bancaire. Le lien peut être remplacé dans une copie personnelle avec
`NEXT_PUBLIC_SUPPORT_URL`.

## Développement

```bash
npm install       # installer les dépendances
npm run dev       # lancer sur http://localhost:3015
npm run typecheck # vérifier TypeScript
npm run build     # produire la version de production
```

Documentation :

- [Doctrine 80/20](docs/80-20-DOCTRINE.md)
- [Brief de recherche](docs/RESEARCH-PROMPT.md)
- [Règles des visuels](docs/VISUAL-ASSET.md)

OpenCadence n’est pas un dispositif médical. Une douleur vive ou croissante,
une oppression thoracique, un malaise, un vertige ou un essoufflement inhabituel
doit faire arrêter la séance et demander un avis professionnel adapté.

Licence : [MIT](LICENSE).
