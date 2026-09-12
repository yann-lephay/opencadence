import type {
  CadenceState,
  CompletedSession,
  MovementPattern,
  MuscleGroup,
  Profile,
  Workout,
  WorkoutItem,
} from "./types";
import { profileHasEquipment } from "./equipment";

type Variant = Omit<WorkoutItem, "id" | "sets" | "targetValue" | "superset" | "restSeconds"> & {
  repRange: [number, number];
  baseValue: number;
  timing: {
    setupSeconds: number;
    transitionSeconds: number;
    secondsPerRep?: number;
    sides?: 1 | 2;
    fixedWorkSeconds?: number;
    loggingSeconds: number;
  };
};

type Readiness = {
  factor: number;
  label: "Verte" | "Orange" | "Allégée" | "Reprise";
  rirTarget: string;
  hardRowerAllowed: boolean;
  note: string;
};

const DAY = 86_400_000;
const targetCredits: Record<MuscleGroup, number> = {
  back: 6,
  chest: 6,
  quads: 6,
  hamstrings: 6,
  glutes: 6,
  delts: 6,
  core: 4,
};

const variants: Record<MovementPattern, Variant[]> = {
  warmup: [
    {
      variantId: "row-easy",
      exercise: "Rameur facile",
      art: "row",
      pattern: "warmup",
      muscleCredits: {},
      anchor: false,
      mode: "time",
      target: "4–5 min · RPE 3–4",
      repRange: [240, 300],
      baseValue: 240,
      timing: {
        setupSeconds: 45,
        transitionSeconds: 20,
        fixedWorkSeconds: 300,
        loggingSeconds: 15,
      },
      restBand: "Transition",
      rirTarget: "Facile",
      equipment: "Rameur",
      purpose: "Monter en température sans fatiguer les jambes",
      cues: ["Allure facile et régulière", "Jambes puis bras", "Tu dois pouvoir parler normalement"],
    },
  ],
  pull: [
    {
      variantId: "pullup-strict",
      exercise: "Tractions strictes",
      art: "pullup",
      pattern: "pull",
      muscleCredits: { back: 1, delts: 0.5 },
      anchor: true,
      mode: "reps",
      target: "4–8 reps",
      repRange: [4, 8],
      baseValue: 5,
      timing: {
        setupSeconds: 20,
        transitionSeconds: 20,
        secondsPerRep: 4,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Barre de traction",
      loadOptions: [
        { label: "Poids du corps", totalKg: 0 },
        { label: "Gilet 10 kg", totalKg: 10 },
      ],
      purpose: "Ancrage de tirage vertical",
      cues: ["Pars sans élan", "Coudes vers les côtes", "Arrête avec 2 reps propres possibles"],
    },
    {
      variantId: "row-one-arm-9",
      exercise: "Rowing unilatéral",
      art: "row-dumbbell",
      pattern: "pull",
      muscleCredits: { back: 1, delts: 0.5 },
      anchor: true,
      mode: "reps",
      target: "8–15 reps / côté",
      repRange: [8, 15],
      baseValue: 10,
      timing: {
        setupSeconds: 35,
        transitionSeconds: 25,
        secondsPerRep: 3,
        sides: 2,
        loggingSeconds: 20,
      },
      restBand: "2 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Haltère 6 kg ou haltère déjà chargé",
      loadOptions: [
        { label: "1 × 6 kg", totalKg: 6 },
        { label: "1 × 15–16 kg", totalKg: 15.5 },
      ],
      purpose: "Ancrage de tirage horizontal",
      cues: ["Dos long", "Coude vers la hanche", "Pause brève en haut sans tourner le buste"],
    },
  ],
  push: [
    {
      variantId: "pushup-floor",
      exercise: "Pompes propres",
      art: "pushup",
      pattern: "push",
      muscleCredits: { chest: 1, delts: 0.5 },
      anchor: true,
      mode: "reps",
      target: "6–15 reps",
      repRange: [6, 15],
      baseValue: 10,
      timing: {
        setupSeconds: 15,
        transitionSeconds: 20,
        secondsPerRep: 3,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Poids du corps · gilet 10 kg si le cap devient facile",
      loadOptions: [
        { label: "Poids du corps", totalKg: 0 },
        { label: "Gilet 10 kg", totalKg: 10 },
      ],
      purpose: "Ancrage de poussée horizontale",
      cues: ["Corps en bloc", "Poitrine entre les mains", "Arrête avant que le bassin ou les épaules compensent"],
    },
    {
      variantId: "floor-press-fixed",
      exercise: "Développé au sol",
      art: "floor-press",
      pattern: "push",
      muscleCredits: { chest: 1, delts: 0.5 },
      anchor: true,
      mode: "reps",
      target: "6–12 reps",
      repRange: [6, 12],
      baseValue: 9,
      timing: {
        setupSeconds: 45,
        transitionSeconds: 25,
        secondsPerRep: 3,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Haltères déjà chargés",
      loadOptions: [
        { label: "2 × 6 kg", totalKg: 12 },
        { label: "2 × 15–16 kg", totalKg: 31 },
      ],
      purpose: "Poussée stable et facile à doser",
      cues: ["Omoplates posées au sol", "Avant-bras verticaux", "Garde 2 reps propres en réserve"],
    },
  ],
  knee: [
    {
      variantId: "split-squat",
      exercise: "Split squat",
      art: "lunge",
      pattern: "knee",
      muscleCredits: { quads: 1, glutes: 0.5 },
      anchor: true,
      mode: "reps",
      target: "8–12 reps / côté",
      repRange: [8, 12],
      baseValue: 9,
      timing: {
        setupSeconds: 25,
        transitionSeconds: 25,
        secondsPerRep: 3,
        sides: 2,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Poids du corps · gilet 10 kg si nécessaire",
      loadOptions: [
        { label: "Poids du corps", totalKg: 0 },
        { label: "Gilet 10 kg", totalKg: 10 },
      ],
      purpose: "Ancrage jambes unilatéral",
      cues: ["Pieds sur deux rails", "Genou arrière vers le sol", "Pousse dans tout le pied avant"],
    },
    {
      variantId: "goblet-squat-fixed",
      exercise: "Goblet squat avec pause",
      art: "squat",
      pattern: "knee",
      muscleCredits: { quads: 1, glutes: 0.5 },
      anchor: true,
      mode: "reps",
      target: "8–15 reps",
      repRange: [8, 15],
      baseValue: 10,
      timing: {
        setupSeconds: 30,
        transitionSeconds: 25,
        secondsPerRep: 4,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Un haltère tenu contre la poitrine",
      loadOptions: [
        { label: "1 × 6 kg", totalKg: 6 },
        { label: "1 × 15–16 kg", totalKg: 15.5 },
      ],
      purpose: "Ancrage de flexion de genou",
      cues: ["Tout le pied au sol", "Pause courte en bas", "Remonte sans perdre l’axe des genoux"],
    },
  ],
  hinge: [
    {
      variantId: "rdl-fixed",
      exercise: "Soulevé de terre roumain",
      art: "rdl",
      pattern: "hinge",
      muscleCredits: { hamstrings: 1, glutes: 1 },
      anchor: true,
      mode: "reps",
      target: "8–15 reps",
      repRange: [8, 15],
      baseValue: 10,
      timing: {
        setupSeconds: 35,
        transitionSeconds: 25,
        secondsPerRep: 4,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Deux haltères de 6 kg ou un haltère lourd tenu à deux mains",
      loadOptions: [
        { label: "2 × 6 kg", totalKg: 12 },
        { label: "1 × 15–16 kg centré", totalKg: 15.5 },
        { label: "2 × 15–16 kg", totalKg: 31 },
      ],
      purpose: "Ancrage de chaîne postérieure",
      cues: [
        "Hanches loin derrière",
        "Avec un seul haltère : tiens-le à deux mains, centré et près des jambes",
        "Première série prudente après une hausse de charge",
        "Arrête l’amplitude avant d’arrondir le dos",
      ],
    },
    {
      variantId: "bridge-vest",
      exercise: "Pont fessier",
      art: "bridge",
      pattern: "hinge",
      muscleCredits: { glutes: 1, hamstrings: 0.5 },
      anchor: true,
      mode: "reps",
      target: "12–20 reps",
      repRange: [12, 20],
      baseValue: 14,
      timing: {
        setupSeconds: 40,
        transitionSeconds: 25,
        secondsPerRep: 3,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "90 s localement",
      rirTarget: "2–3 RIR",
      equipment: "Gilet lesté 10 kg",
      loadOptions: [
        { label: "Poids du corps", totalKg: 0 },
        { label: "Gilet 10 kg", totalKg: 10 },
        { label: "1 × 15–16 kg", totalKg: 15.5 },
      ],
      purpose: "Charnière simple lorsque le dos a besoin de souffler",
      cues: ["Pieds stables", "Serre les fessiers en haut", "Ne cambre pas pour gagner de l’amplitude"],
    },
  ],
  shoulders: [
    {
      variantId: "lateral-raise-5",
      exercise: "Élévations latérales strictes",
      art: "lateral",
      pattern: "shoulders",
      muscleCredits: { delts: 1 },
      anchor: false,
      mode: "reps",
      target: "10–20 reps",
      repRange: [10, 20],
      baseValue: 12,
      timing: {
        setupSeconds: 20,
        transitionSeconds: 20,
        secondsPerRep: 3,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "60–90 s",
      rirTarget: "2–3 RIR",
      equipment: "Haltères 1, 5 ou 6 kg",
      loadOptions: [
        { label: "2 × 1 kg", totalKg: 2 },
        { label: "2 × 5 kg", totalKg: 10 },
        { label: "2 × 6 kg", totalKg: 12 },
      ],
      purpose: "Priorité largeur d’épaules",
      cues: ["Bras légèrement fléchis", "Monte sans hausser les épaules", "Aucun élan du buste"],
    },
    {
      variantId: "rear-delt-5",
      exercise: "Oiseau buste penché",
      art: "rear-delt",
      pattern: "shoulders",
      muscleCredits: { delts: 1, back: 0.5 },
      anchor: false,
      mode: "reps",
      target: "10–20 reps",
      repRange: [10, 20],
      baseValue: 12,
      timing: {
        setupSeconds: 30,
        transitionSeconds: 20,
        secondsPerRep: 3,
        sides: 1,
        loggingSeconds: 20,
      },
      restBand: "60–90 s",
      rirTarget: "2–3 RIR",
      equipment: "Haltères 5 ou 6 kg · 1 kg en tempo si nécessaire",
      loadOptions: [
        { label: "2 × 1 kg", totalKg: 2 },
        { label: "2 × 5 kg", totalKg: 10 },
        { label: "2 × 6 kg", totalKg: 12 },
      ],
      purpose: "Priorité arrière d’épaule et omoplates",
      cues: ["Buste incliné et dos long", "Écarte sans hausser les épaules", "Marque une courte pause en haut"],
    },
  ],
  core: [
    {
      variantId: "side-plank",
      exercise: "Gainage latéral",
      art: "side-plank",
      pattern: "core",
      muscleCredits: { core: 1 },
      anchor: false,
      mode: "time",
      target: "25–40 s / côté",
      repRange: [25, 40],
      baseValue: 30,
      timing: {
        setupSeconds: 20,
        transitionSeconds: 20,
        sides: 1,
        loggingSeconds: 10,
      },
      restBand: "60 s",
      rirTarget: "Avant compensation",
      equipment: "Poids du corps",
      purpose: "Tronc et symétrie",
      cues: ["Coude sous l’épaule", "Bassin haut", "Arrête avant de tourner ou de t’affaisser"],
    },
  ],
  conditioning: [
    {
      variantId: "row-intervals",
      exercise: "Rameur — intervalles",
      art: "row",
      pattern: "conditioning",
      muscleCredits: {},
      anchor: false,
      mode: "time",
      target: "4 × 30 s soutenu / 30 s facile",
      repRange: [240, 240],
      baseValue: 240,
      timing: {
        setupSeconds: 45,
        transitionSeconds: 20,
        fixedWorkSeconds: 240,
        loggingSeconds: 15,
      },
      restBand: "Intégré",
      rirTarget: "RPE 7–8",
      hardRower: true,
      equipment: "Rameur",
      purpose: "Cardio court, uniquement lorsque la récupération est verte",
      cues: ["Après la musculation", "Reste régulier", "Aucun sprint maximal"],
    },
  ],
};

const SESSION_FLOW_SECONDS = 90;

function variantTiming(variantId: string) {
  for (const family of Object.values(variants)) {
    const variant = family.find((candidate) => candidate.variantId === variantId);
    if (variant) return variant.timing;
  }
  return null;
}

function workoutSequence(items: WorkoutItem[]) {
  const sequence: Array<{ itemIndex: number; setIndex: number }> = [];
  const visitedPairs = new Set<string>();

  items.forEach((item, itemIndex) => {
    if (!item.superset) {
      for (let setIndex = 0; setIndex < item.sets; setIndex += 1) {
        sequence.push({ itemIndex, setIndex });
      }
      return;
    }
    if (visitedPairs.has(item.superset)) return;
    visitedPairs.add(item.superset);
    const pair = items
      .map((entry, index) => ({ entry, index }))
      .filter(({ entry }) => entry.superset === item.superset);
    const rounds = Math.max(...pair.map(({ entry }) => entry.sets));
    for (let setIndex = 0; setIndex < rounds; setIndex += 1) {
      for (const paired of pair) {
        if (setIndex < paired.entry.sets) {
          sequence.push({ itemIndex: paired.index, setIndex });
        }
      }
    }
  });

  return sequence;
}

export function estimateWorkoutSeconds(items: WorkoutItem[]) {
  const sequence = workoutSequence(items);
  let seconds = SESSION_FLOW_SECONDS;

  for (const item of items) {
    const timing = variantTiming(item.variantId);
    if (!timing) continue;
    seconds += timing.setupSeconds + timing.transitionSeconds;
  }

  sequence.forEach((step, sequenceIndex) => {
    const item = items[step.itemIndex];
    const timing = variantTiming(item.variantId);
    const target = item.targetValues?.[step.setIndex] ?? item.targetValue;
    const workSeconds = timing?.fixedWorkSeconds
      ?? (item.mode === "time"
        ? target
        : item.mode === "distance"
          ? 240
          : target * (timing?.secondsPerRep ?? 3) * (timing?.sides ?? 1));
    seconds += workSeconds + (timing?.loggingSeconds ?? 20);

    if (sequenceIndex + 1 < sequence.length) {
      const changingSide = item.variantId === "side-plank" && step.setIndex + 1 < item.sets;
      seconds += changingSide ? 15 : item.restSeconds;
    }
  });

  return seconds;
}

function resizeWorkoutItem(item: WorkoutItem, sets: number): WorkoutItem {
  return {
    ...item,
    sets,
    targetValues: item.targetValues?.slice(0, sets),
  };
}

function fitWorkoutToDuration(
  items: WorkoutItem[],
  durationMinutes: number,
  priorityScores: Partial<Record<MovementPattern, number>>,
) {
  const budgetSeconds = durationMinutes * 60;
  let fitted: WorkoutItem[] = items.map((item) => ({
    ...item,
    targetValues: item.targetValues?.slice(),
  }));

  if (estimateWorkoutSeconds(fitted) > budgetSeconds) {
    fitted = fitted.filter((item) => item.pattern !== "conditioning");
  }

  while (estimateWorkoutSeconds(fitted) > budgetSeconds) {
    const candidates = fitted
      .filter((item) => item.pattern !== "warmup" && item.sets > 1)
      .sort((a, b) => {
        if (a.sets !== b.sets) return b.sets - a.sets;
        return (priorityScores[a.pattern] ?? 0) - (priorityScores[b.pattern] ?? 0);
      });
    const candidate = candidates[0];
    if (!candidate) break;
    fitted = fitted.map((item) =>
      item.id === candidate.id ? resizeWorkoutItem(item, item.sets - 1) : item,
    );
  }

  return fitted;
}

function diagnosticItem(
  variant: Variant,
  id: string,
  sets: number,
  targetValue: number,
  restSeconds: number,
  purpose = variant.purpose,
): WorkoutItem {
  const { repRange: _repRange, baseValue: _baseValue, timing: _timing, ...base } = variant;
  const firstLoad = variant.loadOptions?.[0];
  return {
    ...base,
    id,
    sets,
    superset: null,
    restSeconds,
    targetValue,
    targetValues: Array.from({ length: sets }, () => targetValue),
    purpose,
    ...(firstLoad
      ? {
          recommendedLoadLabel: firstLoad.label,
          recommendedLoadKg: firstLoad.totalKg,
          loadReason: "Charge de calibration prudente pour la première séance.",
        }
      : {}),
  };
}

export function buildDiagnosticWorkout(profile: Profile): Workout {
  const declaredEquipment = [...profile.equipment, profile.otherEquipment ?? ""];
  const hasRower = profileHasEquipment(declaredEquipment, /rameur/);
  const hasDumbbells = profileHasEquipment(declaredEquipment, /haltère|dumbbell/);
  const hasPullupBar = profileHasEquipment(declaredEquipment, /barre de traction/);
  const pushVariant =
    profile.pushupLevel === "none" && hasDumbbells ? variants.push[1] : variants.push[0];
  const pullVariant =
    hasPullupBar && profile.pullupLevel !== "none"
      ? variants.pull[0]
      : hasDumbbells
        ? variants.pull[1]
        : null;
  const hingeVariant = hasDumbbells ? variants.hinge[0] : variants.hinge[1];
  const items: WorkoutItem[] = [];

  if (hasRower) {
    items.push(
      diagnosticItem(
        variants.warmup[0],
        "row-warmup",
        1,
        240,
        20,
        "Monter tranquillement en température",
      ),
    );
  }

  items.push(
    diagnosticItem(variants.knee[0], "split-squat-test", 2, 10, 90, "Calibrer l’ancrage jambes"),
    diagnosticItem(pushVariant, "push-test", 1, pushVariant.baseValue, 120, "Calibrer la poussée sans imposer une variante trop difficile"),
  );
  if (pullVariant) {
    items.push(
      diagnosticItem(pullVariant, "pull-test", 1, pullVariant.baseValue, 120, "Calibrer le tirage séparément du niveau des jambes"),
    );
  }
  items.push(
    diagnosticItem(hingeVariant, "hinge-test", 2, hingeVariant.baseValue, 120, "Calibrer la chaîne postérieure"),
    diagnosticItem(variants.core[0], "side-plank-test", 2, 30, 45, "Repère de gainage et d’asymétrie"),
  );

  if (hasRower) {
    items.push({
      id: "row-finish",
      exercise: "Rameur — référence 4 minutes",
      art: "row",
      variantId: "row-benchmark-4",
      pattern: "conditioning",
      muscleCredits: {},
      anchor: false,
      superset: null,
      mode: "distance",
      sets: 1,
      target: "Distance personnelle à effort 6–7/10",
      targetValue: 0,
      targetValues: [0],
      restSeconds: 0,
      restBand: "Fin",
      rirTarget: "RPE 6–7",
      hardRower: false,
      equipment: "Rameur",
      purpose: "Benchmark interne : même durée, résistance et effort à chaque comparaison",
      cues: [
        "Allure soutenue mais régulière",
        "Choisis une résistance et conserve-la aux prochains tests",
        "Note séparément les mètres et les coups de rame",
        "Ne termine pas en sprint maximal",
      ],
    });
  }

  return {
    id: `diagnostic-${Date.now()}`,
    title: "Point de départ",
    subtitle: pullVariant
      ? "Calibrer séparément jambes, poussée et tirage sans test maximal"
      : "Calibrer les mouvements compatibles sans test maximal",
    kind: "Diagnostic",
    estimatedMinutes: Math.min(45, Math.max(30, profile.sessionMinutes)),
    intensity: "Modérée",
    focus: [
      "Jambes",
      "Poussée",
      ...(pullVariant ? ["Tirage"] : []),
      "Chaîne postérieure",
      "Gainage",
    ],
    coachNote:
      `La variante vient de tes réponses et de ton matériel, pas de ton sexe. Arrête chaque série avec 2–3 répétitions propres encore possibles ; une variante facile à mesurer vaut mieux qu’un test maximal.${pullVariant ? "" : " Aucun tirage illustré n’est compatible avec le matériel déclaré : OpenCadence l’omet plutôt que d’en inventer un."}`,
    items,
  };
}

function completedSets(session: CompletedSession, item: WorkoutItem) {
  return session.progress[item.id]?.length ?? 0;
}

export function calculateRollingCredits(history: CompletedSession[], days: number) {
  const cutoff = Date.now() - days * DAY;
  const totals = Object.fromEntries(
    Object.keys(targetCredits).map((group) => [group, 0]),
  ) as Record<MuscleGroup, number>;

  for (const session of history) {
    if (new Date(session.completedAt).getTime() < cutoff) continue;
    for (const item of session.workout.items) {
      const sets = completedSets(session, item);
      for (const [group, credit] of Object.entries(item.muscleCredits ?? {})) {
        totals[group as MuscleGroup] += sets * (credit ?? 0);
      }
    }
  }
  return totals;
}

function daysSinceExposure(history: CompletedSession[], group: MuscleGroup, now: Date) {
  const exposure = history.find((session) =>
    session.workout.items.some(
      (item) => (item.muscleCredits?.[group] ?? 0) > 0 && completedSets(session, item) > 0,
    ),
  );
  if (!exposure) return 7;
  return Math.max(0, (now.getTime() - new Date(exposure.completedAt).getTime()) / DAY);
}

function getBaseReadiness(state: CadenceState, now: Date): Readiness {
  const recent = state.history.slice(0, 3);
  const last = recent[0];
  if (!last) {
    return {
      factor: 1,
      label: "Verte",
      rirTarget: "2–3 RIR",
      hardRowerAllowed: false,
      note: "On calibre sans chercher l’échec. Les quatre grands mouvements restent présents.",
    };
  }

  const days = Math.max(0, (now.getTime() - new Date(last.completedAt).getTime()) / DAY);
  const repeatedRed = recent.filter((session) => session.effort >= 9).length >= 2;
  if (last.pain >= 5) {
    return {
      factor: 0.55,
      label: "Allégée",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note: "Douleur importante signalée : volume réduit et amplitude confortable. Arrête tout mouvement douloureux.",
    };
  }
  if (repeatedRed) {
    return {
      factor: 0.65,
      label: "Allégée",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note: "Deux séances très dures sur les trois dernières : volume réduit, aucune série proche de l’échec.",
    };
  }
  if (days < 1) {
    return {
      factor: 0.55,
      label: "Allégée",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note: "Moins de 24 h depuis la dernière séance : passage technique et léger, sans finisher.",
    };
  }
  if (days < 2 && last.effort >= 8) {
    return {
      factor: 0.75,
      label: "Orange",
      rirTarget: "3 RIR",
      hardRowerAllowed: false,
      note: "Récupération courte après une séance exigeante : volume réduit sur les familles déjà sollicitées.",
    };
  }
  if (days > 14) {
    return {
      factor: 0.6,
      label: "Reprise",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note: "Reprise après plus de deux semaines : séance de recalibration, sans rattrapage de volume.",
    };
  }
  if (days > 7) {
    return {
      factor: 0.75,
      label: "Reprise",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note: "Reprise progressive : environ trois quarts du volume habituel, sans séance punitive.",
    };
  }
  if (last.effort >= 9 || last.pain >= 3) {
    return {
      factor: 0.75,
      label: "Orange",
      rirTarget: "3 RIR",
      hardRowerAllowed: false,
      note: "La dernière réponse invite à consolider : volume modéré et marge technique nette.",
    };
  }
  return {
    factor: 1,
    label: "Verte",
    rirTarget: "2–3 RIR",
    hardRowerAllowed: true,
    note: "État vert : progression sobre, une répétition à la fois, sans échec systématique.",
  };
}

function getReadiness(state: CadenceState, now: Date): Readiness {
  const base = getBaseReadiness(state, now);
  const today = now.toISOString().slice(0, 10);
  const checkIn = state.dailyCheckIn?.date === today ? state.dailyCheckIn : null;
  const symptoms = checkIn?.menstrualSymptoms ?? 0;

  if (symptoms >= 6) {
    return {
      factor: Math.min(base.factor, 0.65),
      label: "Allégée",
      rirTarget: "3–4 RIR",
      hardRowerAllowed: false,
      note:
        "Symptômes importants aujourd’hui : séance réduite, marge plus grande et aucun rameur intense. Arrête en cas de malaise, vertige ou douleur inhabituelle.",
    };
  }
  if (symptoms >= 3) {
    return {
      ...base,
      hardRowerAllowed: false,
      note: `Symptômes modérés : commence normalement et utilise le premier binôme comme test de préparation. ${base.note}`,
    };
  }
  return base;
}

function assessmentValue(state: CadenceState, variantId: string, fallback: number) {
  const diagnostic = state.history.find((session) => session.workout.kind === "Diagnostic");
  if (!diagnostic) return fallback;
  const item = diagnostic.workout.items.find((entry) => entry.variantId === variantId);
  const values = item ? diagnostic.progress[item.id]?.map((set) => set.value) ?? [] : [];
  return values.length ? Math.max(...values) : fallback;
}

function previousComparable(state: CadenceState, variantId: string) {
  return state.history
    .map((session) => {
      const item = session.workout.items.find((entry) => entry.variantId === variantId);
      return item ? { session, item, results: session.progress[item.id] ?? [] } : null;
    })
    .filter((entry): entry is NonNullable<typeof entry> => Boolean(entry?.results.length));
}

function nearFailureMarkers(session: CompletedSession) {
  return Object.values(session.progress)
    .flat()
    .filter((result) => result.rir !== undefined && result.rir <= 1).length;
}

function loadRecommendation(state: CadenceState, variant: Variant, readiness: Readiness) {
  const options = variant.loadOptions;
  if (!options?.length) return {};

  const comparable = previousComparable(state, variant.variantId);
  const latest = comparable[0];
  const latestLoad = latest?.results.at(-1)?.loadLabel;
  const currentIndex = Math.max(
    0,
    options.findIndex((option) => option.label === latestLoad),
  );
  let recommendedIndex = currentIndex;
  let reason = latest
    ? "Charge conservée pendant que les répétitions se consolident."
    : "Point de départ prudent, à confirmer après la première série.";

  if (latest) {
    const lastRir = latest.results.at(-1)?.rir;
    const belowRange = latest.results.some((result) => result.value < variant.repRange[0]);
    const hitCeiling = latest.results.every((result) => result.value >= variant.repRange[1]);
    const sameLoadSuccesses = comparable.filter((entry) => {
      const entryLoad = entry.results.at(-1)?.loadLabel ?? options[0].label;
      const entryRir = entry.results.at(-1)?.rir;
      return (
        entryLoad === options[currentIndex].label &&
        entry.results.every((result) => result.value >= variant.repRange[1]) &&
        (entryRir === undefined || entryRir >= 2) &&
        entry.session.effort <= 8 &&
        entry.session.pain <= 2
      );
    }).length;

    if ((belowRange || lastRir === 0 || latest.session.pain >= 3) && currentIndex > 0) {
      const previousOption = options[currentIndex - 1];
      const currentOption = options[currentIndex];
      const shoulderStepIsTooLarge =
        variant.pattern === "shoulders" &&
        previousOption.totalKg < currentOption.totalKg * 0.6;

      if (shoulderStepIsTooLarge) {
        reason =
          "Marge insuffisante, mais le palier inférieur est trop éloigné : charge conservée avec moins de répétitions et davantage de repos.";
      } else {
        recommendedIndex -= 1;
        reason = "Marge ou confort insuffisant : retour temporaire au palier précédent.";
      }
    } else if (
      readiness.factor >= 0.75 &&
      hitCeiling &&
      sameLoadSuccesses >= 2 &&
      currentIndex < options.length - 1
    ) {
      recommendedIndex += 1;
      reason =
        readiness.factor < 1
          ? "Haut de fourchette validé deux fois : palier suivant avec répétitions basses et première série prudente."
          : "Haut de fourchette validé deux fois avec une bonne marge : palier suivant proposé.";
    } else if (hitCeiling && currentIndex < options.length - 1) {
      reason = "Haut de fourchette atteint : encore une séance propre avant d’ajouter de la charge.";
    }
  }

  const recommendation = options[recommendedIndex];
  return {
    recommendedLoadLabel: recommendation.label,
    recommendedLoadKg: recommendation.totalKg,
    loadReason: reason,
    loadStepDelta: recommendedIndex - currentIndex,
  };
}

function baseTargetForVariant(state: CadenceState, variant: Variant) {
  let target = variant.baseValue;

  if (variant.variantId === "pullup-strict") {
    target = assessmentValue(state, "pullup-strict", variant.baseValue);
  } else if (variant.variantId === "pushup-floor") {
    target = assessmentValue(state, "pushup-floor", variant.baseValue);
  } else if (variant.variantId === "split-squat") {
    target = assessmentValue(state, "split-squat", variant.baseValue);
  } else if (variant.variantId === "rdl-fixed") {
    target = assessmentValue(state, "rdl-fixed", variant.baseValue);
  }

  return Math.min(variant.repRange[1], Math.max(variant.repRange[0], target));
}

function targetsForVariant(
  state: CadenceState,
  variant: Variant,
  readiness: Readiness,
  sets: number,
) {
  const comparable = previousComparable(state, variant.variantId);
  const latest = comparable[0];
  const previous = comparable[1];
  const fallback = baseTargetForVariant(state, variant);
  const targets = latest?.results.slice(0, sets).map((result) => result.value) ?? [];
  while (targets.length < sets) targets.push(targets.at(-1) ?? fallback);

  if (latest) {
    const latestTotal = latest.results.reduce((sum, result) => sum + result.value, 0);
    const previousTotal = previous?.results.reduce((sum, result) => sum + result.value, 0);
    const performanceDrop = previousTotal !== undefined && latestTotal < previousTotal * 0.85;
    const first = latest.results[0]?.value ?? 0;
    const last = latest.results.at(-1)?.value ?? first;
    const setDrop = first > 0 ? (first - last) / first : 0;
    const lastRir = latest.results.at(-1)?.rir;
    const stable =
      latest.session.effort <= 8 &&
      latest.session.pain <= 2 &&
      (lastRir === undefined || lastRir >= 2) &&
      !performanceDrop &&
      setDrop <= 0.2;

    if (stable && readiness.factor === 1) {
      const index = targets.findIndex((value) => value < variant.repRange[1]);
      if (index >= 0) targets[index] += 1;
    }
  }

  return targets.map((target) => {
    const adjusted = readiness.factor < 0.8 ? Math.floor(target * 0.9) : target;
    return Math.min(variant.repRange[1], Math.max(variant.repRange[0], adjusted));
  });
}

function variantSupported(profile: Profile, variant: Variant) {
  const declaredEquipment = [...profile.equipment, profile.otherEquipment ?? ""];
  if (variant.variantId === "row-easy" || variant.variantId === "row-intervals") {
    return profileHasEquipment(declaredEquipment, /rameur/);
  }
  if (variant.variantId === "pullup-strict") {
    return profileHasEquipment(declaredEquipment, /barre de traction/);
  }
  if (
    [
      "row-one-arm-9",
      "floor-press-fixed",
      "goblet-squat-fixed",
      "rdl-fixed",
      "lateral-raise-5",
      "rear-delt-5",
    ].includes(variant.variantId)
  ) {
    return profileHasEquipment(declaredEquipment, /haltère|dumbbell/);
  }
  return true;
}

function stableVariant(state: CadenceState, pattern: MovementPattern) {
  const supported = variants[pattern].filter((variant) => variantSupported(state.profile, variant));
  for (const session of state.history.slice(0, 8)) {
    const prior = session.workout.items.find(
      (item) => item.pattern === pattern && completedSets(session, item) > 0,
    );
    const match = prior && supported.find((variant) => variant.variantId === prior.variantId);
    if (match) return match;
  }
  return supported[0] ?? null;
}

function plannedVariant(state: CadenceState, pattern: MovementPattern, rotate: boolean) {
  const supported = variants[pattern].filter((variant) => variantSupported(state.profile, variant));
  const stable = stableVariant(state, pattern);
  if (!stable || supported.length < 2 || !rotate) {
    return stable;
  }

  let latestVariantId: string | null = null;
  let consecutiveExposures = 0;
  for (const session of state.history) {
    const item = session.workout.items.find(
      (entry) => entry.pattern === pattern && completedSets(session, entry) > 0,
    );
    if (!item) continue;
    if (!latestVariantId) latestVariantId = item.variantId;
    if (item.variantId !== latestVariantId) break;
    consecutiveExposures += 1;
  }

  const minimumExposures = pattern === "shoulders" ? 2 : pattern === "hinge" ? 1 : 3;
  if (!latestVariantId || consecutiveExposures < minimumExposures) return stable;
  const currentIndex = supported.findIndex((variant) => variant.variantId === latestVariantId);
  if (currentIndex < 0) return stable;
  return supported[(currentIndex + 1) % supported.length];
}

function workoutVariationIndex(state: CadenceState, now: Date) {
  const seed = `${now.toISOString().slice(0, 10)}-${state.history.length}-${state.history[0]?.id ?? "start"}`;
  let hash = 0;
  for (const character of seed) {
    hash = (hash * 31 + character.charCodeAt(0)) | 0;
  }
  return Math.abs(hash);
}

function latestCompletedVariantId(state: CadenceState, pattern: MovementPattern) {
  for (const session of state.history) {
    const item = session.workout.items.find(
      (entry) => entry.pattern === pattern && completedSets(session, entry) > 0,
    );
    if (item) return item.variantId;
  }
  return null;
}

function workoutItem(
  state: CadenceState,
  variant: Variant,
  sets: number,
  superset: string | null,
  restSeconds: number,
  readiness: Readiness,
  suffix: string,
): WorkoutItem {
  const loadPlan = loadRecommendation(state, variant, readiness);
  const targetValues =
    loadPlan.loadStepDelta && loadPlan.loadStepDelta > 0
      ? Array.from({ length: sets }, () => variant.repRange[0])
      : targetsForVariant(state, variant, readiness, sets);
  const { loadStepDelta: _loadStepDelta, ...recommendedLoad } = loadPlan;
  const targetValue = targetValues[0] ?? variant.baseValue;
  const unit = variant.mode === "reps" ? "reps" : variant.mode === "time" ? "s" : "m";
  const target =
    variant.pattern === "warmup" || variant.pattern === "conditioning"
      ? variant.target
      : `${variant.repRange[0]}–${variant.repRange[1]} ${unit}${variant.exercise.includes("côté") ? " / côté" : ""}`;
  const { timing: _timing, ...publicVariant } = variant;
  return {
    ...publicVariant,
    id: `${variant.variantId}-${suffix}`,
    sets,
    superset,
    restSeconds,
    targetValue,
    targetValues,
    target,
    ...recommendedLoad,
    rirTarget:
      variant.pattern === "warmup" || variant.pattern === "conditioning" || variant.pattern === "core"
        ? variant.rirTarget
        : readiness.rirTarget,
  };
}

function buildMakeupWorkout(state: CadenceState, now: Date): Workout | null {
  const last = state.history[0];
  const skipped = new Set(last?.skippedItemIds ?? []);
  if (!last || skipped.size === 0 || last.pain >= 3) return null;

  const age = now.getTime() - new Date(last.completedAt).getTime();
  if (age < 0 || age > 2 * DAY) return null;

  const unfinished = last.workout.items.filter(
    (item) =>
      skipped.has(item.id) &&
      !["warmup", "conditioning"].includes(item.pattern) &&
      completedSets(last, item) < item.sets,
  );
  if (unfinished.length === 0) return null;

  const readiness: Readiness = {
    factor: 0.85,
    label: "Orange",
    rirTarget: "2 RIR",
    hardRowerAllowed: false,
    note: "Complément volontairement ciblé après une séance arrêtée plus tôt.",
  };
  const timestamp = now.getTime();
  const items: WorkoutItem[] = [];
  const warmup = stableVariant(state, "warmup");
  if (warmup) {
    items.push(workoutItem(state, warmup, 1, null, 20, readiness, `${timestamp}-warmup`));
  }

  for (const priorItem of unfinished) {
    const variant = variants[priorItem.pattern].find(
      (candidate) => candidate.variantId === priorItem.variantId && variantSupported(state.profile, candidate),
    );
    if (!variant) continue;
    const missingSets = Math.max(1, priorItem.sets - completedSets(last, priorItem));
    const cap = priorItem.pattern === "shoulders" ? 3 : priorItem.pattern === "core" ? 2 : 2;
    const planned = workoutItem(
      state,
      variant,
      Math.min(missingSets, cap),
      null,
      Math.max(60, priorItem.restSeconds),
      readiness,
      `${timestamp}-${priorItem.pattern}`,
    );
    if (priorItem.pattern === "shoulders") {
      planned.cues = [
        ...planned.cues,
        "Le côté le plus faible donne le signal d’arrêt aux deux bras",
      ];
    }
    items.push(planned);
  }

  const shoulderWasUnfinished = unfinished.some((item) => item.pattern === "shoulders");
  const shoulderPriority = /épaule|deltoïde/i.test(
    state.profile.physicalBalance.priorities.join(" "),
  );
  if (shoulderWasUnfinished && shoulderPriority) {
    const plannedShoulderIds = new Set(items.map((item) => item.variantId));
    const alternate = variants.shoulders.find(
      (variant) =>
        !plannedShoulderIds.has(variant.variantId) && variantSupported(state.profile, variant),
    );
    if (alternate) {
      const accessory = workoutItem(
        state,
        alternate,
        2,
        null,
        75,
        readiness,
        `${timestamp}-shoulders-balance`,
      );
      accessory.cues = [
        ...accessory.cues,
        "Le côté le plus faible donne le signal d’arrêt aux deux bras",
      ];
      items.push(accessory);
    }
  }

  const focusLabels: Partial<Record<MovementPattern, string>> = {
    pull: "Dos",
    push: "Poussée",
    knee: "Jambes",
    hinge: "Chaîne postérieure",
    shoulders: "Épaules",
    core: "Gainage",
  };
  const focus = Array.from(
    new Set(
      items
        .map((item) => focusLabels[item.pattern])
        .filter((label): label is string => Boolean(label)),
    ),
  );
  const workingSets = items
    .filter((item) => item.pattern !== "warmup")
    .reduce((sum, item) => sum + item.sets, 0);

  return {
    id: `makeup-${timestamp}`,
    title: "Compléter sans rattraper",
    subtitle: `${workingSets} séries ciblées · ${focus.join(" · ")}`,
    kind: "Complément · Modéré",
    estimatedMinutes: 30,
    intensity: "Modérée",
    focus,
    coachNote:
      "On complète seulement les familles laissées de côté, sans doubler ce qui a déjà été bien travaillé. Pour les épaules, garde environ deux répétitions propres en réserve et arrête les deux bras quand le côté le plus faible perd sa trajectoire.",
    items,
  };
}

export function getNextSessionRecommendation(
  history: CompletedSession[],
  now = new Date(),
) {
  const last = history[0];
  if (!last) {
    return {
      relativeLabel: "Aujourd’hui",
      dateLabel: new Intl.DateTimeFormat("fr-FR", {
        weekday: "long",
        day: "numeric",
        month: "long",
      }).format(now),
      daysUntil: 0,
      reason: "Tu peux commencer par la séance de calibration.",
    };
  }

  const nearFailureCount = nearFailureMarkers(last);
  const recoveryDays =
    last.pain >= 5
      ? 3
      : last.pain >= 3 ||
          last.effort >= 9 ||
          nearFailureCount >= 3 ||
          (last.hardRowingFinisher && last.effort >= 8)
        ? 2
        : 1;
  const target = new Date(last.completedAt);
  target.setHours(0, 0, 0, 0);
  target.setDate(target.getDate() + recoveryDays);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const daysUntil = Math.max(0, Math.round((target.getTime() - today.getTime()) / DAY));
  const relativeLabel =
    daysUntil === 0 ? "Dès aujourd’hui" : daysUntil === 1 ? "Demain" : `Dans ${daysUntil} jours`;
  const reason =
    recoveryDays === 3
      ? "Trois jours conseillés après la gêne signalée ; reprends seulement si elle s’est calmée."
      : recoveryDays === 2
        ? nearFailureCount >= 3
          ? "Deux jours conseillés : plusieurs mouvements ont fini avec très peu de répétitions en réserve."
          : "Deux jours conseillés après une séance exigeante ou une gêne notable."
        : "Un jour suffit a priori ; la séance s’allégera encore si la récupération n’est pas bonne.";

  return {
    relativeLabel,
    dateLabel: new Intl.DateTimeFormat("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
    }).format(target),
    daysUntil,
    reason,
  };
}

function patternScore(
  pattern: MovementPattern,
  state: CadenceState,
  credits7: Record<MuscleGroup, number>,
  credits21: Record<MuscleGroup, number>,
  now: Date,
  readiness: Readiness,
) {
  const groups: Record<string, MuscleGroup[]> = {
    pull: ["back"],
    push: ["chest"],
    knee: ["quads"],
    hinge: ["hamstrings", "glutes"],
    shoulders: ["delts"],
  };
  const scores = (groups[pattern] ?? []).map((group) => {
    const target = targetCredits[group];
    const deficit7 = Math.max(0, Math.min(1, (target - credits7[group]) / target));
    const normalized21 = credits21[group] / 3;
    const deficit21 = Math.max(0, Math.min(1, (target - normalized21) / target));
    const stale = Math.max(0, Math.min(1, daysSinceExposure(state.history, group, now) / 7));
    const priorityText = state.profile.physicalBalance.priorities.join(" ").toLowerCase();
    const priorityPatterns: Record<MuscleGroup, RegExp> = {
      back: /dos|omoplate|tirage/,
      chest: /pector|poitrine|poussée/,
      quads: /quadriceps|cuisse|genou/,
      hamstrings: /ischio|postérieure|charnière/,
      glutes: /fessier|hanche/,
      delts: /épaule|deltoïde/,
      core: /gainage|abdo|tronc/,
    };
    const priority = priorityPatterns[group].test(priorityText) ? 0.1 : 0;
    return 0.6 * deficit7 + 0.25 * deficit21 + 0.15 * stale + priority;
  });
  if (!scores.length || readiness.label === "Allégée") return 0;
  return scores.reduce((sum, score) => sum + score, 0) / scores.length;
}

export function buildNextWorkout(state: CadenceState, now = new Date()): Workout {
  const makeup = buildMakeupWorkout(state, now);
  if (makeup) return makeup;

  const readiness = getReadiness(state, now);
  const duration = Math.min(45, Math.max(30, state.profile.sessionMinutes));
  const credits7 = calculateRollingCredits(state.history, 7);
  const credits21 = calculateRollingCredits(state.history, 21);
  const variationIndex = workoutVariationIndex(state, now);
  const rotatingMainPattern = (["knee", "hinge", "pull", "push"] as const)[variationIndex % 4];
  const selectedVariants: Partial<Record<MovementPattern, Variant>> = {
    pull: plannedVariant(state, "pull", rotatingMainPattern === "pull") ?? undefined,
    knee: plannedVariant(state, "knee", rotatingMainPattern === "knee") ?? undefined,
    push: plannedVariant(state, "push", rotatingMainPattern === "push") ?? undefined,
    hinge: plannedVariant(state, "hinge", rotatingMainPattern === "hinge") ?? undefined,
    shoulders: plannedVariant(state, "shoulders", true) ?? undefined,
    warmup: stableVariant(state, "warmup") ?? undefined,
    conditioning: stableVariant(state, "conditioning") ?? undefined,
  };
  const corePatterns: MovementPattern[] = (["pull", "knee", "push", "hinge"] as const).filter(
    (pattern) => Boolean(selectedVariants[pattern]),
  );
  const maximumSets = readiness.factor >= 0.9 ? 3 : readiness.factor >= 0.7 ? 2 : 1;
  const sets: Record<string, number> = Object.fromEntries(
    corePatterns.map((pattern) => [pattern, maximumSets]),
  );
  const shoulderSets = selectedVariants.shoulders ? maximumSets : 0;

  const timestamp = now.getTime();
  const plannedRotations = (["pull", "knee", "push", "hinge", "shoulders"] as const)
    .filter(
      (pattern) =>
        selectedVariants[pattern] &&
        latestCompletedVariantId(state, pattern) !== selectedVariants[pattern]?.variantId,
    )
    .map((pattern) => selectedVariants[pattern]?.exercise)
    .filter((exercise): exercise is string => Boolean(exercise));

  const items: WorkoutItem[] = [];
  if (selectedVariants.warmup) {
    items.push(workoutItem(state, selectedVariants.warmup, 1, null, 20, readiness, `${timestamp}-warmup`));
  }
  const coreOrderTemplates: Array<Array<"pull" | "knee" | "push" | "hinge">> = [
    ["pull", "knee", "push", "hinge"],
    ["push", "hinge", "pull", "knee"],
    ["knee", "pull", "hinge", "push"],
  ];
  const coreOrder = coreOrderTemplates[variationIndex % coreOrderTemplates.length];
  const shoulderItem =
    shoulderSets > 0 && selectedVariants.shoulders
      ? workoutItem(
          state,
          selectedVariants.shoulders,
          shoulderSets,
          null,
          60,
          readiness,
          `${timestamp}-shoulders`,
        )
      : null;
  const shoulderInsertAfter = variationIndex % 3 === 0 ? 0 : 2;
  if (shoulderItem && shoulderInsertAfter === 0) items.push(shoulderItem);
  for (const [index, pattern] of coreOrder.entries()) {
    const variant = selectedVariants[pattern];
    if (!variant) continue;
    const superset = pattern === "pull" || pattern === "knee" ? "A" : "B";
    const restSeconds = pattern === "pull" || pattern === "push" ? 25 : 70;
    items.push(
      workoutItem(
        state,
        variant,
        sets[pattern],
        superset,
        restSeconds,
        readiness,
        `${timestamp}-${pattern}`,
      ),
    );
    if (shoulderItem && index + 1 === shoulderInsertAfter) items.push(shoulderItem);
  }
  items.push(
    workoutItem(
      state,
      variants.core[0],
      readiness.factor < 0.7 ? 1 : 2,
      null,
      60,
      readiness,
      `${timestamp}-core`,
    ),
  );

  const hadHardRowerRecently = state.history.some(
    (session) =>
      now.getTime() - new Date(session.completedAt).getTime() < 7 * DAY &&
      session.hardRowingFinisher,
  );
  if (
    selectedVariants.conditioning &&
    duration >= 37 &&
    readiness.hardRowerAllowed &&
    !hadHardRowerRecently
  ) {
    items.push(
      workoutItem(
        state,
        selectedVariants.conditioning,
        1,
        null,
        0,
        readiness,
        `${timestamp}-finisher`,
      ),
    );
  }

  const priorityScores: Partial<Record<MovementPattern, number>> = Object.fromEntries(
    ([...corePatterns, "shoulders"] as MovementPattern[]).map((pattern) => [
      pattern,
      patternScore(pattern, state, credits7, credits21, now, readiness),
    ]),
  );
  const fittedItems = fitWorkoutToDuration(items, duration, priorityScores);
  const estimatedMinutes = Math.ceil(estimateWorkoutSeconds(fittedItems) / 60);
  const coreSetCount = fittedItems
    .filter((item) => corePatterns.includes(item.pattern))
    .reduce((sum, item) => sum + item.sets, 0);
  return {
    id: `adaptive-${timestamp}`,
    title: readiness.label === "Reprise" ? "Reprendre le fil" : "Le socle complet",
    subtitle: `${coreSetCount} séries sur ${corePatterns.length} ancrage${corePatterns.length > 1 ? "s" : ""} compatible${corePatterns.length > 1 ? "s" : ""} · environ ${estimatedMinutes} min`,
    kind: `Full body · ${readiness.label}`,
    estimatedMinutes,
    intensity: readiness.label === "Verte" ? "Soutenue maîtrisée" : "Modérée",
    focus: [
      ...(selectedVariants.pull ? ["Dos"] : []),
      "Jambes",
      "Poussée",
      "Chaîne postérieure",
      ...(selectedVariants.shoulders ? ["Épaules"] : []),
    ],
    coachNote: `${readiness.note} La séance est calibrée sur ta fenêtre de ${duration} minutes, installation, repos et saisie compris. OpenCadence utilise seulement les variantes compatibles avec le matériel déclaré.${selectedVariants.pull ? " Les séries disponibles vont aux groupes les moins exposés récemment et aux priorités de ton profil." : " Aucun tirage illustré compatible n’est encore disponible : ajoute du matériel ou demande à Codex de proposer une nouvelle variante."}${plannedRotations.length ? ` Variation planifiée aujourd’hui : ${plannedRotations.join(" et ")}. Les autres repères restent stables pour mesurer la progression.` : ""}`,
    items: fittedItems,
  };
}
