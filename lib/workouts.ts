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
      restBand: "2 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Haltère 9 kg ou haltère déjà chargé",
      loadOptions: [
        { label: "1 × 9 kg", totalKg: 9 },
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
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Haltères déjà chargés",
      loadOptions: [
        { label: "2 × 9 kg", totalKg: 18 },
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
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Un haltère tenu contre la poitrine",
      loadOptions: [
        { label: "1 × 9 kg", totalKg: 9 },
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
      restBand: "2–3 min localement",
      rirTarget: "2–3 RIR",
      equipment: "Haltères déjà chargés",
      loadOptions: [
        { label: "2 × 9 kg", totalKg: 18 },
        { label: "2 × 15–16 kg", totalKg: 31 },
      ],
      purpose: "Ancrage de chaîne postérieure",
      cues: ["Hanches loin derrière", "Haltères près des jambes", "Arrête l’amplitude avant d’arrondir le dos"],
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
      restBand: "90 s localement",
      rirTarget: "2–3 RIR",
      equipment: "Gilet lesté 10 kg",
      loadOptions: [
        { label: "Poids du corps", totalKg: 0 },
        { label: "Gilet 10 kg", totalKg: 10 },
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
      restBand: "60–90 s",
      rirTarget: "2–3 RIR",
      equipment: "Haltères 1, 5 ou 9 kg",
      loadOptions: [
        { label: "2 × 1 kg", totalKg: 2 },
        { label: "2 × 5 kg", totalKg: 10 },
        { label: "2 × 9 kg", totalKg: 18 },
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
      restBand: "60–90 s",
      rirTarget: "2–3 RIR",
      equipment: "Haltères 5 kg · 1 kg en tempo si nécessaire",
      loadOptions: [
        { label: "2 × 1 kg", totalKg: 2 },
        { label: "2 × 5 kg", totalKg: 10 },
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
      restBand: "Intégré",
      rirTarget: "RPE 7–8",
      hardRower: true,
      equipment: "Rameur",
      purpose: "Cardio court, uniquement lorsque la récupération est verte",
      cues: ["Après la musculation", "Reste régulier", "Aucun sprint maximal"],
    },
  ],
};

function diagnosticItem(
  variant: Variant,
  id: string,
  sets: number,
  targetValue: number,
  restSeconds: number,
  purpose = variant.purpose,
): WorkoutItem {
  const { repRange: _repRange, baseValue: _baseValue, ...base } = variant;
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
      recommendedIndex -= 1;
      reason = "Marge ou confort insuffisant : retour temporaire au palier précédent.";
    } else if (
      readiness.factor === 1 &&
      hitCeiling &&
      sameLoadSuccesses >= 2 &&
      currentIndex < options.length - 1
    ) {
      recommendedIndex += 1;
      reason = "Haut de fourchette validé deux fois avec une bonne marge : palier suivant proposé.";
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
    const prior = session.workout.items.find((item) => item.pattern === pattern && item.anchor);
    const match = prior && supported.find((variant) => variant.variantId === prior.variantId);
    if (match) return match;
  }
  return supported[0] ?? null;
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
  return {
    ...variant,
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

  const recoveryDays =
    last.pain >= 5
      ? 3
      : last.pain >= 3 || last.effort >= 9 || (last.hardRowingFinisher && last.effort >= 8)
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
        ? "Deux jours conseillés après une séance exigeante ou une gêne notable."
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

function baseBudget(minutes: number) {
  if (minutes <= 30) return 12;
  if (minutes <= 38) return 14;
  return 16;
}

export function buildNextWorkout(state: CadenceState, now = new Date()): Workout {
  const readiness = getReadiness(state, now);
  const duration = Math.min(45, Math.max(30, state.profile.sessionMinutes));
  const budget = Math.max(4, Math.round(baseBudget(duration) * readiness.factor));
  const credits7 = calculateRollingCredits(state.history, 7);
  const credits21 = calculateRollingCredits(state.history, 21);
  const selectedVariants: Partial<Record<MovementPattern, Variant>> = {
    pull: stableVariant(state, "pull") ?? undefined,
    knee: stableVariant(state, "knee") ?? undefined,
    push: stableVariant(state, "push") ?? undefined,
    hinge: stableVariant(state, "hinge") ?? undefined,
    shoulders: stableVariant(state, "shoulders") ?? undefined,
    warmup: stableVariant(state, "warmup") ?? undefined,
    conditioning: stableVariant(state, "conditioning") ?? undefined,
  };
  const corePatterns: MovementPattern[] = (["pull", "knee", "push", "hinge"] as const).filter(
    (pattern) => Boolean(selectedVariants[pattern]),
  );
  const sets: Record<string, number> = Object.fromEntries(corePatterns.map((pattern) => [pattern, budget >= 8 ? 2 : 1]));
  let remaining = Math.max(0, budget - Object.values(sets).reduce((sum, value) => sum + value, 0));
  const shoulderSets = readiness.factor < 0.7 ? 1 : duration >= 40 ? 3 : 2;
  const usableShoulderSets = selectedVariants.shoulders ? Math.min(shoulderSets, remaining) : 0;
  remaining -= usableShoulderSets;

  const ranked = [...corePatterns].sort(
    (a, b) =>
      patternScore(b, state, credits7, credits21, now, readiness) -
      patternScore(a, state, credits7, credits21, now, readiness),
  );
  for (const pattern of ranked) {
    if (remaining <= 0) break;
    sets[pattern] += 1;
    remaining -= 1;
  }

  const timestamp = now.getTime();

  const items: WorkoutItem[] = [];
  if (selectedVariants.warmup) {
    items.push(workoutItem(state, selectedVariants.warmup, 1, null, 20, readiness, `${timestamp}-warmup`));
  }
  if (selectedVariants.pull) {
    items.push(workoutItem(state, selectedVariants.pull, sets.pull, "A", 25, readiness, `${timestamp}-pull`));
  }
  if (selectedVariants.knee) {
    items.push(workoutItem(state, selectedVariants.knee, sets.knee, "A", 70, readiness, `${timestamp}-knee`));
  }
  if (selectedVariants.push) {
    items.push(workoutItem(state, selectedVariants.push, sets.push, "B", 25, readiness, `${timestamp}-push`));
  }
  if (selectedVariants.hinge) {
    items.push(workoutItem(state, selectedVariants.hinge, sets.hinge, "B", 70, readiness, `${timestamp}-hinge`));
  }

  if (usableShoulderSets > 0 && selectedVariants.shoulders) {
    items.push(
      workoutItem(state, selectedVariants.shoulders, usableShoulderSets, "C", 25, readiness, `${timestamp}-shoulders`),
    );
  }
  items.push(
    workoutItem(
      state,
      variants.core[0],
      2,
      usableShoulderSets > 0 ? "C" : null,
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

  const coreSetCount = corePatterns.reduce((sum, pattern) => sum + sets[pattern], 0);
  return {
    id: `adaptive-${timestamp}`,
    title: readiness.label === "Reprise" ? "Reprendre le fil" : "Le socle complet",
    subtitle: `${coreSetCount} séries sur ${corePatterns.length} ancrage${corePatterns.length > 1 ? "s" : ""} compatible${corePatterns.length > 1 ? "s" : ""} · supersets non concurrents`,
    kind: `Full body · ${readiness.label}`,
    estimatedMinutes: duration,
    intensity: readiness.label === "Verte" ? "Soutenue maîtrisée" : "Modérée",
    focus: [
      ...(selectedVariants.pull ? ["Dos"] : []),
      "Jambes",
      "Poussée",
      "Chaîne postérieure",
      ...(selectedVariants.shoulders ? ["Épaules"] : []),
    ],
    coachNote: `${readiness.note} OpenCadence utilise seulement les variantes compatibles avec le matériel déclaré.${selectedVariants.pull ? " Les séries disponibles vont aux groupes les moins exposés récemment et aux priorités de ton profil." : " Aucun tirage illustré compatible n’est encore disponible : ajoute du matériel ou demande à Codex de proposer une nouvelle variante."}`,
    items,
  };
}
