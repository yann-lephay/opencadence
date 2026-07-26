import type { ExerciseArt } from "@/lib/types";

type FigureProps = {
  kind: ExerciseArt;
  label: string;
};

const stroke = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 5.5,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

const effort = [0, 0.55, 1, 0];

function Head({ x, y }: { x: number; y: number }) {
  return <circle cx={x} cy={y} r="8.5" fill="currentColor" />;
}

function Ground() {
  return <path d="M10 158h140" stroke="var(--line)" strokeWidth="2.5" />;
}

function Pose({ kind, phase }: { kind: string; phase: number }) {
  const t = effort[phase];

  if (kind === "lunge") {
    const hipY = 82 + 34 * t;
    const shoulderY = 44 + 30 * t;
    const headY = 27 + 28 * t;
    const frontKneeX = 125 - 20 * t;
    const frontKneeY = 116 + 14 * t;
    const backKneeX = 20 + 28 * t;
    const backKneeY = 116 + 30 * t;
    return (
      <>
        <Ground />
        <Head x={72} y={headY} />
        <path d={`M80 ${headY - 1}h5`} stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
        <path d={`M72 ${headY + 9}L72 ${hipY}`} {...stroke} />
        <path d={`M72 ${shoulderY + 12}L94 ${shoulderY + 26}L76 ${shoulderY + 32}`} {...stroke} />
        <path d={`M72 ${hipY}L${frontKneeX} ${frontKneeY}L125 156`} {...stroke} />
        <path d={`M72 ${hipY}L${backKneeX} ${backKneeY}L20 156`} {...stroke} />
        <path d="M10 156h26m105 0h-27" stroke="var(--accent)" strokeWidth="5" strokeLinecap="round" />
        <path d="M20 137v-16m105 16v-16" stroke="var(--accent)" strokeWidth="2.5" strokeDasharray="4 4" />
      </>
    );
  }

  if (kind === "squat") {
    const hipY = 80 + 35 * t;
    const shoulderY = 44 + 28 * t;
    const headY = 27 + 26 * t;
    return (
      <>
        <Ground />
        <Head x={80} y={headY} />
        <path d={`M80 ${headY + 9}L80 ${hipY}`} {...stroke} />
        <path d={`M80 ${shoulderY + 12}L52 ${70 + 22 * t}M80 ${shoulderY + 12}L108 ${70 + 22 * t}`} {...stroke} />
        <path d={`M80 ${hipY}L48 ${112 + 17 * t}L36 157M80 ${hipY}L112 ${112 + 17 * t}L124 157`} {...stroke} />
        <path d="M25 157h24m62 0h24" stroke="var(--accent)" strokeWidth="5" strokeLinecap="round" />
      </>
    );
  }

  if (kind === "pullup") {
    const bodyShift = 35 * t;
    return (
      <>
        <path d="M20 17h120" {...stroke} />
        <Head x={80} y={67 - bodyShift} />
        <path d={`M80 ${76 - bodyShift}L80 ${115 - bodyShift}`} {...stroke} />
        <path d={`M80 ${83 - bodyShift}L43 28M80 ${83 - bodyShift}L117 28`} {...stroke} />
        <path d={`M80 ${114 - bodyShift}L59 ${151 - bodyShift}M80 ${114 - bodyShift}L101 ${151 - bodyShift}`} {...stroke} />
        <circle cx="43" cy="27" r="4.5" fill="var(--accent)" />
        <circle cx="117" cy="27" r="4.5" fill="var(--accent)" />
      </>
    );
  }

  if (kind === "pushup" || kind === "plank" || kind === "mountain" || kind === "pike") {
    const drop = kind === "pike" ? 22 * t : 27 * t;
    const shoulderY = kind === "pike" ? 112 + drop : 74 + drop;
    const hipY = kind === "pike" ? 47 : 92 + drop * 0.65;
    return (
      <>
        <Ground />
        <Head x={35} y={shoulderY - 10} />
        <path d={`M44 ${shoulderY - 5}L92 ${hipY}L139 153`} {...stroke} />
        <path d={`M50 ${shoulderY}L34 156M58 ${shoulderY + 4}L51 156`} {...stroke} />
        <path d={`M92 ${hipY}L112 156`} {...stroke} />
        {kind === "mountain" && <path d={`M92 ${hipY}L63 142`} {...stroke} />}
        <path d={`M25 ${shoulderY + 9}h40`} stroke="var(--accent)" strokeWidth="2.5" strokeDasharray="4 4" />
      </>
    );
  }

  if (kind === "rdl") {
    const headX = 79 - 31 * t;
    const headY = 25 + 37 * t;
    const hipX = 80 + 11 * t;
    const hipY = 80 + 8 * t;
    const handY = 91 + 46 * t;
    return (
      <>
        <Ground />
        <Head x={headX} y={headY} />
        <path d={`M${headX + 3} ${headY + 9}L${hipX} ${hipY}`} {...stroke} />
        <path d={`M${headX + 7} ${headY + 17}L59 ${handY}M${headX + 9} ${headY + 17}L83 ${handY}`} {...stroke} />
        <path d={`M${hipX} ${hipY}L67 119L62 157M${hipX} ${hipY}L98 119L103 157`} {...stroke} />
        <path d={`M49 ${handY}h20m4 0h20`} stroke="var(--accent)" strokeWidth="6" strokeLinecap="round" />
        <path d="M113 73h21" stroke="var(--accent)" strokeWidth="2.5" strokeDasharray="4 4" />
      </>
    );
  }

  if (kind === "dip") {
    const bodyY = 34 + 27 * t;
    return (
      <>
        <path d="M12 82h42v76M148 82h-42v76" {...stroke} />
        <Head x={80} y={bodyY} />
        <path d={`M80 ${bodyY + 9}L80 ${bodyY + 58}`} {...stroke} />
        <path d={`M80 ${bodyY + 22}L51 84M80 ${bodyY + 22}L109 84`} {...stroke} />
        <path d={`M80 ${bodyY + 58}L65 ${bodyY + 102}M80 ${bodyY + 58}L96 ${bodyY + 102}`} {...stroke} />
        <circle cx="51" cy="84" r="4.5" fill="var(--accent)" />
        <circle cx="109" cy="84" r="4.5" fill="var(--accent)" />
      </>
    );
  }

  if (kind === "side-plank") {
    const hipY = 133 - 32 * t;
    return (
      <>
        <Ground />
        <Head x={31} y={98 - 11 * t} />
        <path d={`M41 ${101 - 10 * t}L88 ${hipY}L139 155`} {...stroke} />
        <path d={`M48 ${104 - 8 * t}L30 154M88 ${hipY}L65 151`} {...stroke} />
        <path d={`M46 ${113 - 13 * t}L76 ${79 - 13 * t}`} {...stroke} />
        <path d={`M43 ${122 - 10 * t}L122 ${146 - 17 * t}`} stroke="var(--accent)" strokeWidth="2.5" strokeDasharray="4 4" />
      </>
    );
  }

  if (kind === "bridge") {
    const hipY = 137 - 39 * t;
    return (
      <>
        <Ground />
        <Head x={27} y={132} />
        <path d={`M36 134L84 ${hipY}L119 128L139 157`} {...stroke} />
        <path d="M45 139L62 157M119 128L98 157" {...stroke} />
        <path d={`M69 ${hipY - 7}h30`} stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" />
      </>
    );
  }

  if (kind === "floor-press") {
    const handY = 112 - 54 * t;
    return (
      <>
        <Ground />
        <Head x={29} y={140} />
        <path d="M38 142L94 151L137 157M63 148L52 157" {...stroke} />
        <path d={`M65 146L62 ${handY}M95 151L98 ${handY}`} {...stroke} />
        <path d={`M50 ${handY}h24m12 0h24`} stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" />
      </>
    );
  }

  if (kind === "lateral" || kind === "rear-delt") {
    const armY = 91 - 43 * t;
    const torsoLean = kind === "rear-delt" ? 23 : 0;
    return (
      <>
        <Ground />
        <Head x={80 - torsoLean} y={30 + torsoLean} />
        <path d={`M80 ${40 + torsoLean}L${80 + torsoLean} 101`} {...stroke} />
        <path d={`M82 ${56 + torsoLean}L33 ${armY + torsoLean}M82 ${56 + torsoLean}L130 ${armY}`} {...stroke} />
        <path d={`M${80 + torsoLean} 101L60 157M${80 + torsoLean} 101L104 157`} {...stroke} />
        <path d={`M24 ${armY + torsoLean}h18m79 ${armY}h18`} stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" />
      </>
    );
  }

  if (kind === "row-dumbbell") {
    const elbowY = 112 - 37 * t;
    return (
      <>
        <Ground />
        <Head x={45} y={50} />
        <path d="M54 56L102 86L119 157M75 69L54 128L36 157M101 86L76 157" {...stroke} />
        <path d={`M72 68L103 ${elbowY}L116 ${126 - 42 * t}`} {...stroke} />
        <path d={`M105 ${127 - 42 * t}h22`} stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" />
      </>
    );
  }

  if (kind === "curl") {
    const handY = 116 - 48 * t;
    return (
      <>
        <Ground />
        <Head x={80} y={28} />
        <path d="M80 38v67M80 61L52 79M80 61L108 79M80 104L60 157M80 104L101 157" {...stroke} />
        <path d={`M52 79L59 ${handY}M108 79L101 ${handY}`} {...stroke} />
        <path d={`M48 ${handY}h22m20 0h22`} stroke="var(--accent)" strokeWidth="7" strokeLinecap="round" />
      </>
    );
  }

  const seatX = 108 - 42 * (1 - t);
  const handleX = 128 - 39 * t;
  return (
    <>
      <path d="M15 153h130M27 153l16-67h91" {...stroke} />
      <Head x={seatX} y={65 + 12 * (1 - t)} />
      <path d={`M${seatX - 4} ${74 + 12 * (1 - t)}L${seatX - 21} 112L${seatX + 4} 132`} {...stroke} />
      <path d={`M${seatX - 7} ${85 + 8 * (1 - t)}L${handleX} 105`} {...stroke} />
      <path d={`M${seatX - 21} 112L40 151M${seatX - 21} 112L131 151`} {...stroke} />
      <path d={`M${handleX} 105L143 78`} stroke="var(--accent)" strokeWidth="4" />
      <circle cx="144" cy="77" r="4.5" fill="var(--accent)" />
    </>
  );
}

const phaseLabels: Record<string, string[]> = {
  lunge: ["Départ", "Descendre", "Position basse", "Remonter"],
  squat: ["Départ", "Descendre", "Bas contrôlé", "Remonter"],
  pullup: ["Suspendu", "Tirer", "En haut", "Redescendre"],
  "row-dumbbell": ["Bras tendu", "Tirer", "Coude à la hanche", "Redescendre"],
  pushup: ["Planche haute", "Descendre", "Poitrine basse", "Repousser"],
  "floor-press": ["Coudes au sol", "Pousser", "Bras tendus", "Redescendre"],
  rdl: ["Debout", "Hanches arrière", "Bas confortable", "Se redresser"],
  bridge: ["Au sol", "Monter", "Bassin aligné", "Redescendre"],
  dip: ["Support haut", "Descendre", "Bas confortable", "Repousser"],
  "side-plank": ["Placement", "Monter", "Corps aligné", "Tenir"],
  row: ["Retour", "Pousser jambes", "Finir les bras", "Revenir"],
  lateral: ["Bras bas", "Monter", "Hauteur d’épaules", "Redescendre"],
  "rear-delt": ["Buste penché", "Écarter", "Omoplates stables", "Redescendre"],
};

const movementTips: Record<string, string> = {
  lunge: "Vue de profil : pied arrière à gauche, pied avant à droite. Les pieds restent à leur place pendant toute la série.",
  squat: "Les deux pieds restent parallèles. Les hanches descendent entre les jambes.",
  pullup: "Monte sans élan, puis redescends sous contrôle jusqu’aux bras tendus.",
  "row-dumbbell": "Garde le dos long et le bassin immobile ; le coude voyage vers la hanche.",
  pushup: "Le corps reste en bloc : poitrine vers le sol, puis repousse sans creuser le dos.",
  "floor-press": "Garde la tête, les omoplates et le bassin au sol ; pose doucement les bras sans faire rebondir les haltères.",
  rdl: "Ce n’est pas un squat : repousse les hanches derrière toi avec les genoux légèrement fléchis.",
  bridge: "Monte avec les fessiers jusqu’à aligner épaules, bassin et genoux, sans cambrer.",
  dip: "Descends seulement dans une amplitude confortable, épaules loin des oreilles.",
  "side-plank": "Aligne épaule, bassin et chevilles ; arrête avant que le bassin ne tombe.",
  row: "Jambes d’abord, buste ensuite, bras en dernier — puis l’ordre inverse au retour.",
  lateral: "Monte les bras sans élan ni haussement d’épaules, puis contrôle la descente.",
  "rear-delt": "Le buste ne bouge pas ; écarte les bras sans remonter les épaules vers les oreilles.",
};

const generatedAssets: Record<ExerciseArt, string> = {
  row: "/assets/exercise-rower-v1.webp",
  lunge: "/assets/exercise-split-squat-v1.webp",
  pushup: "/assets/exercise-pushup-v2.webp",
  pullup: "/assets/exercise-pullup-v1.webp",
  "row-dumbbell": "/assets/exercise-row-dumbbell-v1.webp",
  "floor-press": "/assets/exercise-floor-press-v2.webp",
  squat: "/assets/exercise-goblet-squat-v1.webp",
  rdl: "/assets/exercise-rdl-v1.webp",
  bridge: "/assets/exercise-bridge-v1.webp",
  dip: "/assets/exercise-dip-v1.webp",
  "side-plank": "/assets/exercise-side-plank-v1.webp",
  lateral: "/assets/exercise-lateral-raise-v1.webp",
  "rear-delt": "/assets/exercise-rear-delt-v1.webp",
};

export function ExerciseLoop({ kind, label }: FigureProps) {
  const asset = generatedAssets[kind];
  if (!asset) {
    return (
      <div className="exercise-loop fallback-loop" aria-label={`Aperçu du prochain mouvement : ${label}`}>
        <svg viewBox="0 0 160 170" aria-hidden="true">
          <Pose kind={kind} phase={2} />
        </svg>
      </div>
    );
  }

  return (
    <div className="exercise-loop" role="img" aria-label={`Mouvement en boucle : ${label}`}>
      {[0, 1, 2, 3].map((phase) => (
        <div className={`loop-frame loop-frame-${phase + 1}`} key={phase}>
          <img src={asset} alt="" />
        </div>
      ))}
    </div>
  );
}

export function ExerciseFigure({ kind, label }: FigureProps) {
  const labels = phaseLabels[kind] ?? ["Départ", "Mouvement", "Fin d’amplitude", "Retour"];
  const asset = generatedAssets[kind];

  if (asset) {
    return (
      <div className="exercise-figure generated-figure" role="img" aria-label={`Mouvement complet en quatre étapes : ${label}`}>
        <img className="movement-sheet" src={asset} alt="" aria-hidden="true" />
        <div className="phase-legend" aria-hidden="true">
          {labels.map((phaseLabel, phase) => (
            <span key={`${phaseLabel}-${phase}`}>
              <b>{phase + 1}</b>
              {phaseLabel}
            </span>
          ))}
        </div>
        <p className="movement-tip">{movementTips[kind] ?? "Observe la position de départ, l’amplitude contrôlée, puis le retour."}</p>
      </div>
    );
  }

  return (
    <div className="exercise-figure" role="img" aria-label={`Mouvement complet en quatre étapes : ${label}`}>
      <div className="movement-sequence" aria-hidden="true">
        {labels.map((phaseLabel, phase) => (
          <div className="motion-frame" key={`${phaseLabel}-${phase}`}>
            <span className="phase-number">{phase + 1}</span>
            <svg viewBox="0 0 160 170">
              <Pose kind={kind} phase={phase} />
            </svg>
            <strong>{phaseLabel}</strong>
          </div>
        ))}
      </div>
      <p className="movement-tip">{movementTips[kind] ?? "Observe la position de départ, l’amplitude contrôlée, puis le retour."}</p>
    </div>
  );
}
