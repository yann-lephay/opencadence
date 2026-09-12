#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultFixturePath = path.resolve(scriptDir, "../fixtures/ios-engine-v2/cases.json");
const fixturePath = path.resolve(process.cwd(), process.argv[2] ?? defaultFixturePath);
const errors = [];

function fail(scope, message) {
  errors.push(`${scope}: ${message}`);
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function unique(values) {
  return new Set(values).size === values.length;
}

function equal(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function scanBannedKeys(value, scope, bannedKeys) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => scanBannedKeys(item, `${scope}[${index}]`, bannedKeys));
    return;
  }
  if (!isObject(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (bannedKeys.has(key)) fail(scope, `ancienne clé pseudo-précise interdite : ${key}`);
    scanBannedKeys(child, `${scope}.${key}`, bannedKeys);
  }
}

function rowCost(exercise, sets) {
  const timing = exercise.timingSeconds;
  return timing.setup
    + timing.transition
    + sets * (timing.execution + timing.secondSide)
    + timing.rest * Math.max(0, sets - 1);
}

function inventoryItem(input, requirement) {
  return (input.todayInventory ?? []).find((item) => {
    if (item.category !== requirement.category || item.units < requirement.units) return false;
    if (requirement.configuration === "pair") return item.units >= 2;
    return requirement.configuration === "single";
  });
}

function supportsExercise(input, exercise) {
  const supports = new Set(input.todaySupports ?? []);
  const supportsPresent = exercise.supports.every((support) => supports.has(support));
  const equipmentPresent = exercise.equipment.every((requirement) => inventoryItem(input, requirement));
  return supportsPresent && equipmentPresent;
}

function refusedExercise(input, exerciseId, catalog) {
  const expectedContext = catalog[exerciseId]?.progressionContext;
  return (input.refusals ?? []).some((refusal) => {
    if (refusal.exerciseId !== exerciseId) return false;
    if (refusal.scope === "movement") return true;
    return refusal.scope === "configuration" && refusal.progressionContext === expectedContext;
  });
}

function planSignature(plan) {
  return plan.map((row) => [row.exerciseId, row.sets, row.targetReps, row.load?.kg ?? null]);
}

function validatePlan(scope, fixture, catalog, budgetSeconds) {
  const plan = fixture.expected.plan ?? [];
  let estimatedSeconds = 0;
  const seen = [];

  for (const [index, row] of plan.entries()) {
    const rowScope = `${scope}.expected.plan[${index}]`;
    const exercise = catalog[row.exerciseId];
    if (!exercise) {
      fail(rowScope, `mouvement inconnu : ${row.exerciseId}`);
      continue;
    }
    seen.push(row.exerciseId);
    if (!Number.isInteger(row.sets) || row.sets < exercise.sets.min || row.sets > exercise.sets.max) {
      fail(rowScope, `séries hors plage ${exercise.sets.min}-${exercise.sets.max}`);
    }
    if (!Number.isInteger(row.targetReps) || row.targetReps < exercise.repRange.min || row.targetReps > exercise.repRange.max) {
      fail(rowScope, `cible hors plage ${exercise.repRange.min}-${exercise.repRange.max}`);
    }
    if (row.progressionContext !== exercise.progressionContext) {
      fail(rowScope, "progressionContext absent ou différent du catalogue versionné");
    }
    if (row.restSeconds !== exercise.timingSeconds.rest) {
      fail(rowScope, `repos attendu : ${exercise.timingSeconds.rest}`);
    }
    if (!supportsExercise(fixture.input, exercise)) {
      fail(rowScope, "matériel ou support absent dans le contexte du jour");
    }

    if (exercise.loadMode === "bodyweight") {
      if (row.load !== undefined) fail(rowScope, "une configuration au poids du corps ne doit pas recevoir de charge");
    } else {
      if (!isObject(row.load) || row.load.mode !== exercise.loadMode || !Number.isFinite(row.load.kg)) {
        fail(rowScope, `charge ${exercise.loadMode} explicite requise`);
      } else {
        const requirement = exercise.equipment[0];
        const item = inventoryItem(fixture.input, requirement);
        if (!item?.perUnitWeightsKg?.includes(row.load.kg)) {
          fail(rowScope, `palier ${row.load.kg} kg absent de l'inventaire réel`);
        }
      }
    }

    if (typeof row.referenceStatus !== "string" || !row.referenceStatus) {
      fail(rowScope, "referenceStatus requis");
    }
    if (row.sourceExerciseId) {
      const relation = fixture.__manifest.substitutions.find((candidate) =>
        candidate.from === row.sourceExerciseId && candidate.to === row.exerciseId
      );
      if (!relation || relation.type !== "partial") {
        fail(rowScope, `substitution partielle éditoriale absente depuis ${row.sourceExerciseId}`);
      }
    }
    estimatedSeconds += rowCost(exercise, row.sets);
  }

  if (!unique(seen)) fail(scope, "un mouvement apparaît plusieurs fois dans le même plan");
  if (fixture.expected.estimatedSeconds !== estimatedSeconds) {
    fail(scope, `durée calculée ${estimatedSeconds}s, attendue ${fixture.expected.estimatedSeconds}s`);
  }
  if (Number.isFinite(budgetSeconds) && estimatedSeconds > budgetSeconds) {
    fail(scope, `plan de ${estimatedSeconds}s au-delà du budget de ${budgetSeconds}s`);
  }

  if (fixture.expected.coveredAnchors) {
    const anchors = plan.map((row) => catalog[row.exerciseId]?.anchor).filter(Boolean);
    if (!equal(anchors, fixture.expected.coveredAnchors)) {
      fail(scope, `ancrages couverts incohérents : ${JSON.stringify(anchors)}`);
    }
  }
  if (fixture.expected.omittedAnchors) {
    const covered = new Set(plan.map((row) => catalog[row.exerciseId]?.anchor));
    for (const anchor of fixture.expected.omittedAnchors) {
      if (covered.has(anchor)) fail(scope, `ancrage ${anchor} à la fois couvert et omis`);
    }
  }
}

let manifest;
try {
  manifest = JSON.parse(await readFile(fixturePath, "utf8"));
} catch (error) {
  console.error(`FAIL impossible de lire ${fixturePath}: ${error.message}`);
  process.exit(1);
}

if (manifest.version !== "2.0-draft.1") fail("manifest", "version attendue : 2.0-draft.1");
if (manifest.status !== "engine_preview_bridge_not_product_activated") {
  fail("manifest", "le statut doit distinguer la preview interne d'une activation produit");
}
if (manifest.catalogVersion !== "fixture-v2.0.0") fail("manifest", "catalogVersion inattendue");
if (manifest.decisionPolicyVersion !== "2.0.0") fail("manifest", "decisionPolicyVersion inattendue");
if (!isObject(manifest.policy) || !isObject(manifest.policyHypotheses) || !isObject(manifest.catalog) || !Array.isArray(manifest.substitutions) || !Array.isArray(manifest.cases)) {
  fail("manifest", "policy, policyHypotheses, catalog, substitutions et cases sont requis");
}

const contractPath = path.resolve(path.dirname(fixturePath), manifest.contract ?? "");
let contract = "";
try {
  contract = await readFile(contractPath, "utf8");
} catch (error) {
  fail("manifest", `contrat introuvable : ${error.message}`);
}
for (const scenario of ["S1", "S2", "S3", "S4", "S5"]) {
  if (!contract.includes(`### ${scenario}`)) fail("contract", `scénario normatif ${scenario} absent`);
}
for (const heading of ["## 5. Mode global", "## 6. Assemblage déterministe", "## 8. Temps", "## 9. Progression", "## 10. Branche conservatrice"]){
  if (!contract.includes(heading)) fail("contract", `section absente : ${heading}`);
}

const policy = manifest.policy ?? {};
const policyHypotheses = manifest.policyHypotheses ?? {};
if (!equal(policy.durationBudgetsSeconds, { "20": 1200, "30": 1800, "45": 2700 })) {
  fail("policy", "budgets 20/30/45 non versionnés comme attendu");
}
if (!Number.isInteger(policy.historyDepthCompletedSessions) || policy.historyDepthCompletedSessions < 1) {
  fail("policy", "profondeur d'historique entière positive requise");
}
if (!Number.isInteger(policy.returnQuestionAfterDaysWithoutComparableExposure) || policy.returnQuestionAfterDaysWithoutComparableExposure < 1) {
  fail("policy", "seuil produit de question de reprise requis");
}
if (!equal(policy.anchorTieOrder, ["pull", "push", "knee", "hinge"])) {
  fail("policy", "ordre stable des ancrages inattendu");
}
if (policy.rangeCeilingConfirmations !== 2) fail("policy", "deux confirmations au plafond attendues dans cette version");
if (policyHypotheses.progression?.rirAffectsAutomaticProgression !== false || policyHypotheses.progression?.globalEffortAffectsAutomaticProgression !== false) {
  fail("policyHypotheses", "RIR et effort global doivent rester hors progression automatique V2");
}

const catalog = manifest.catalog ?? {};
const exerciseIds = Object.keys(catalog);
if (exerciseIds.length !== 7 || !unique(exerciseIds)) fail("catalog", "sept identifiants uniques sont attendus");
for (const [exerciseId, exercise] of Object.entries(catalog)) {
  const scope = `catalog.${exerciseId}`;
  if (!["pull", "push", "knee", "hinge"].includes(exercise.anchor)) fail(scope, "ancrage invalide");
  if (exercise.catalogStatus !== "published_in_fixture_catalog") fail(scope, "configuration non activée dans le catalogue de fixture");
  if (!["candidate_validation_required", "validation_required_before_product"].includes(exercise.productPublicationStatus)) {
    fail(scope, "statut produit prudent requis");
  }
  if (!["bodyweight", "single_total_kg", "central_total_kg", "pair_each_kg"].includes(exercise.loadMode)) fail(scope, "loadMode invalide");
  if (!Array.isArray(exercise.equipment) || !Array.isArray(exercise.supports)) fail(scope, "equipment et supports requis");
  if (!Number.isInteger(exercise.repRange?.min) || !Number.isInteger(exercise.repRange?.max) || exercise.repRange.min >= exercise.repRange.max) {
    fail(scope, "plage de répétitions invalide");
  }
  if (exercise.repRange?.entry !== exercise.repRange?.min) fail(scope, "la cible d'entrée doit être le bas de plage");
  if (!Number.isInteger(exercise.sets?.min) || !Number.isInteger(exercise.sets?.max) || exercise.sets.min < 1 || exercise.sets.min > exercise.sets.max) {
    fail(scope, "plage de séries invalide");
  }
  for (const field of ["setup", "execution", "secondSide", "rest", "transition"]) {
    if (!Number.isInteger(exercise.timingSeconds?.[field]) || exercise.timingSeconds[field] < 0) fail(scope, `temps ${field} invalide`);
  }
  if (exercise.timingSeconds?.rest < 60) fail(scope, "repos inférieur à la convention prudente de cette fixture");
  if (!Number.isInteger(exercise.difficultyRank) || !Number.isInteger(exercise.selectionRank)) fail(scope, "rangs éditoriaux entiers requis");
  if (!equal(exercise.primaryContributions, [exercise.anchor])) fail(scope, "contribution principale catégorielle incohérente");
  if (!Array.isArray(exercise.secondaryContributions)) fail(scope, "contributions secondaires requises");
  if (typeof exercise.progressionContext !== "string" || !exercise.progressionContext.startsWith(`${exerciseId}|`)) fail(scope, "progressionContext stable requis");
  if (exercise.loadMode === "bodyweight" && exercise.equipment.length) fail(scope, "le poids du corps ne doit pas inventer un équipement");
  if (exercise.loadMode !== "bodyweight" && exercise.equipment.length !== 1) fail(scope, "une exigence matérielle explicite est requise");
}
if (catalog.incline_pushup?.supports?.[0] !== "wall_or_stable_plane") {
  fail("catalog.incline_pushup", "le support réel ne doit plus être implicite");
}
if (catalog.one_arm_row?.supports?.[0] !== "stable_hand_support") {
  fail("catalog.one_arm_row", "l'appui stable réel ne doit plus être implicite");
}
if (catalog.bodyweight_hinge?.productPublicationStatus !== "validation_required_before_product") {
  fail("catalog.bodyweight_hinge", "ce mouvement doit rester explicitement à valider avant publication produit");
}

const relationKeys = [];
for (const [index, relation] of (manifest.substitutions ?? []).entries()) {
  const scope = `substitutions[${index}]`;
  relationKeys.push(`${relation.from}->${relation.to}`);
  if (!catalog[relation.from] || !catalog[relation.to]) fail(scope, "extrémité inconnue");
  if (relation.type !== "partial") fail(scope, "seules les substitutions partielles explicites sont attendues ici");
  if (!Number.isInteger(relation.rank) || relation.rank < 1) fail(scope, "rang éditorial positif requis");
  if (catalog[relation.from]?.anchor !== catalog[relation.to]?.anchor) fail(scope, "une substitution doit préserver l'ancrage dans ce premier lot");
}
if (!unique(relationKeys)) fail("substitutions", "relations dupliquées");
if (manifest.substitutions.some((relation) => relation.from === "one_arm_row")) {
  fail("substitutions", "le tirage ne doit pas recevoir une fausse substitution dans ce catalogue");
}

const requiredCaseIds = [
  "S1_BEGINNER_20_NO_EQUIPMENT",
  "S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT",
  "S3_RETURN_30_RECALIBRATION_SELECTED",
  "S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED",
  "S5_PERSISTENT_REFUSAL_NO_PAIN",
  "L1_LIGHT_COMPONENTWISE_REDUCTION",
  "L2_RETURN_QUESTION_UNANSWERED",
  "L3_ALL_CLEAN_OPTIONS_REFUSED",
  "L4_PROGRESS_REPETITIONS_ONLY",
  "L5_PROGRESS_NEXT_REAL_LOAD",
  "L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK",
  "L7_HEALTH_SIGNAL_BEFORE_SESSION",
  "L8_HEALTH_SIGNAL_DURING_ACTIVE_SESSION"
];
const cases = manifest.cases ?? [];
const caseIds = cases.map((fixture) => fixture.id);
if (!unique(caseIds)) fail("cases", "identifiants dupliqués");
for (const requiredId of requiredCaseIds) if (!caseIds.includes(requiredId)) fail("cases", `cas requis absent : ${requiredId}`);
if (cases.length !== requiredCaseIds.length) fail("cases", `exactement ${requiredCaseIds.length} cas bornés sont attendus`);

const bannedKeys = new Set([
  "readinessFactor",
  "readiness",
  "painScore",
  "symptomScore",
  "credits7",
  "credits21",
  "makeup",
  "rirTarget",
  "lastSetRir",
  "globalEffort",
  "effort",
  "planProfileId",
  "basePrimarySetBudget",
  "finalPrimarySetBudget"
]);
scanBannedKeys(manifest, "manifest", bannedKeys);

for (const [index, fixture] of cases.entries()) {
  fixture.__manifest = manifest;
  const scope = fixture.id ? `case ${fixture.id}` : `cases[${index}]`;
  if (typeof fixture.id !== "string" || !fixture.id) fail(scope, "id requis");
  if (!["session_decision", "progression_transition", "active_session_transition"].includes(fixture.kind)) fail(scope, "kind invalide");
  if (typeof fixture.description !== "string" || fixture.description.length < 40) fail(scope, "description explicite requise");
  if (Number.isNaN(Date.parse(fixture.now))) fail(scope, "date now invalide");
  if (!isObject(fixture.input) || !isObject(fixture.expected)) fail(scope, "input et expected requis");
  if (!Array.isArray(fixture.expected.reasons) || !fixture.expected.reasons.length || !unique(fixture.expected.reasons.map((reason) => reason.code))) {
    fail(scope, "reasons non vide avec codes uniques requis");
  }
  for (const [reasonIndex, reason] of (fixture.expected.reasons ?? []).entries()) {
    const reasonScope = `${scope}.expected.reasons[${reasonIndex}]`;
    if (typeof reason.code !== "string" || !reason.code) fail(reasonScope, "code requis");
    if (!["session", "movement", "configuration"].includes(reason.scope)) fail(reasonScope, "scope invalide");
    if (!["user", "equipment", "history", "time", "product_scope", "safety"].includes(reason.source)) fail(reasonScope, "fait source invalide");
    if (reason.decisionPolicyVersion !== manifest.decisionPolicyVersion) fail(reasonScope, "version de politique requise");
    if (typeof reason.message !== "string" || reason.message.length < 25) fail(reasonScope, "phrase factuelle explicite requise");
  }
  if (fixture.expected.catalogVersion !== manifest.catalogVersion || fixture.expected.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
    fail(scope, "les versions du catalogue et de la politique doivent être exposées dans la sortie");
  }

  if (fixture.kind === "session_decision") {
    const allowed = new Set(["generate_session", "resume_or_adapt_active_session", "no_clean_session", "stop_standard_session"]);
    if (!allowed.has(fixture.expected.decision)) fail(scope, "décision de séance inconnue");
    const requestedMinutes = fixture.input.request?.durationMinutes;
    const nominalBudget = policy.durationBudgetsSeconds?.[String(requestedMinutes)];
    const effectiveBudget = fixture.input.request?.remainingSeconds ?? nominalBudget;
    if (![20, 30, 45].includes(requestedMinutes)) fail(scope, "durée 20, 30 ou 45 requise");
    if (!Array.isArray(fixture.input.todayInventory) || !Array.isArray(fixture.input.todaySupports)) fail(scope, "inventaire et supports du jour requis");
    if (!Array.isArray(fixture.input.history) || !Array.isArray(fixture.input.refusals)) fail(scope, "historique et refus explicites requis");
    for (const [historyIndex, historyEntry] of fixture.input.history.entries()) {
      const historyScope = `${scope}.input.history[${historyIndex}]`;
      if (historyEntry.catalogVersion !== manifest.catalogVersion || historyEntry.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
        fail(historyScope, "versions ayant produit l'historique requises");
      }
      for (const [referenceIndex, reference] of (historyEntry.references ?? []).entries()) {
        const expectedContext = catalog[reference.exerciseId]?.progressionContext;
        if (!expectedContext || reference.progressionContext !== expectedContext) {
          fail(`${historyScope}.references[${referenceIndex}]`, "référence non comparable faute de progressionContext exact");
        }
      }
    }
    for (const [refusalIndex, refusal] of fixture.input.refusals.entries()) {
      const refusalScope = `${scope}.input.refusals[${refusalIndex}]`;
      if (!["movement", "configuration"].includes(refusal.scope)) fail(refusalScope, "scope movement|configuration requis");
      if (!["today", "persistent"].includes(refusal.temporalScope)) fail(refusalScope, "temporalScope today|persistent requis");
      if (!catalog[refusal.exerciseId]) fail(refusalScope, "exerciseId inconnu");
      if (refusal.scope === "configuration" && refusal.progressionContext !== catalog[refusal.exerciseId]?.progressionContext) {
        fail(refusalScope, "un refus de configuration doit porter sa progressionContext exacte");
      }
    }
    validatePlan(scope, fixture, catalog, effectiveBudget);
    if (["no_clean_session", "stop_standard_session"].includes(fixture.expected.decision) && fixture.expected.plan.length !== 0) {
      fail(scope, "une décision sans séance doit avoir un plan vide");
    }
  }

  if (fixture.kind === "progression_transition") {
    const previous = fixture.input.previousPrescription;
    const next = fixture.expected.nextPrescription;
    const exercise = catalog[previous?.exerciseId];
    if (fixture.expected.decision !== "update_prescription" || !exercise || next?.exerciseId !== previous?.exerciseId) fail(scope, "transition de progression invalide");
    if (!supportsExercise(fixture.input, exercise)) fail(scope, "matériel ou support de la progression absent");
    const progressionInventory = inventoryItem(fixture.input, exercise?.equipment?.[0] ?? {});
    for (const [label, loadKg] of [["précédente", previous?.load?.kg], ["suivante", next?.load?.kg]]) {
      if (!progressionInventory?.perUnitWeightsKg?.includes(loadKg)) fail(scope, `charge ${label} absente de l'inventaire réel`);
    }
    if (previous?.progressionContext !== exercise?.progressionContext || next?.progressionContext !== exercise?.progressionContext) {
      fail(scope, "progressionContext comparable requis avant et après progression");
    }
    if (previous?.catalogVersion !== manifest.catalogVersion || previous?.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
      fail(scope, "versions de la prescription précédente requises");
    }
    if (!fixture.input.exposures?.every((entry) => entry.allPrescribedSetsConfirmed === true)) fail(scope, "expositions admissibles requises");
    for (const [exposureIndex, exposure] of (fixture.input.exposures ?? []).entries()) {
      if (exposure.progressionContext !== exercise?.progressionContext || exposure.catalogVersion !== manifest.catalogVersion || exposure.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
        fail(`${scope}.input.exposures[${exposureIndex}]`, "contexte et versions comparables requis");
      }
      if (!Array.isArray(exposure.confirmedReps) || exposure.confirmedReps.length !== previous.sets) {
        fail(`${scope}.input.exposures[${exposureIndex}]`, "une répétition confirmée est requise pour chaque série prescrite");
      }
      if (exposure.confirmedReps?.some((repetitions) => !Number.isInteger(repetitions) || repetitions < 1)) {
        fail(`${scope}.input.exposures[${exposureIndex}]`, "les répétitions confirmées doivent être des entiers positifs");
      }
      if (exposure.confirmedReps?.some((repetitions) => repetitions < previous.targetReps)) {
        fail(`${scope}.input.exposures[${exposureIndex}]`, "chaque série doit atteindre la cible avant progression");
      }
      if (exposure.loadKg !== previous.load.kg) {
        fail(`${scope}.input.exposures[${exposureIndex}]`, "la charge confirmée doit être identique à la prescription comparable");
      }
    }
    if (fixture.id === "L4_PROGRESS_REPETITIONS_ONLY") {
      if (!equal(fixture.expected.changedFields, ["targetReps"])) fail(scope, "seule la cible de répétitions doit changer");
      if (previous.targetReps >= exercise.repRange.max || next.targetReps > exercise.repRange.max) fail(scope, "la progression par répétitions doit rester strictement sous le plafond de plage");
      if (next.targetReps !== previous.targetReps + 1 || next.load.kg !== previous.load.kg || next.sets !== previous.sets) fail(scope, "progression par répétitions incohérente");
    }
    if (fixture.id === "L5_PROGRESS_NEXT_REAL_LOAD") {
      const weights = fixture.input.todayInventory[0]?.perUnitWeightsKg ?? [];
      const nextRealLoad = weights.filter((weight) => weight > previous.load.kg).sort((a, b) => a - b)[0];
      if (fixture.input.exposures.length !== policy.rangeCeilingConfirmations) fail(scope, "nombre de confirmations au plafond incohérent");
      if (previous.targetReps !== exercise.repRange.max) fail(scope, "le passage de charge exige une prescription exactement au plafond de plage");
      if (next.load.kg !== nextRealLoad || next.targetReps !== exercise.repRange.min) fail(scope, "palier réel ou retour au bas de plage incorrect");
      if (fixture.expected.atomicChange !== "load_step_with_range_reset") fail(scope, "transition atomique non déclarée");
    }
  }

  if (fixture.kind === "active_session_transition") {
    if (fixture.input.catalogVersion !== manifest.catalogVersion || fixture.input.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
      fail(scope, "un snapshot actif doit porter les versions exactes du catalogue et de la politique");
    }
    if (!fixture.expected.confirmedImmutable) fail(scope, "les séries confirmées doivent rester immuables");
    if (!equal(fixture.expected.confirmed, fixture.input.confirmed)) fail(scope, "les séries confirmées doivent être répétées exactement dans la sortie");
    if (fixture.expected.plan) validatePlan(scope, fixture, catalog, fixture.input.remainingSeconds);
  }
}

const byId = Object.fromEntries(cases.map((fixture) => [fixture.id, fixture]));
const requiredReasonCodes = {
  S1_BEGINNER_20_NO_EQUIPMENT: ["anchor_omitted_no_compatible_movement"],
  S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT: ["equipment_temporarily_unavailable", "partial_substitution_new_reference", "anchor_omitted_no_compatible_movement"],
  S3_RETURN_30_RECALIBRATION_SELECTED: ["recalibration_user_selected"],
  S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED: ["active_session_revalidated", "equipment_temporarily_unavailable", "partial_substitution_new_reference"],
  S5_PERSISTENT_REFUSAL_NO_PAIN: ["refusal_persistent", "partial_substitution_new_reference"],
  L1_LIGHT_COMPONENTWISE_REDUCTION: ["light_mode_user_selected"],
  L2_RETURN_QUESTION_UNANSWERED: ["progression_held_reference_to_reconfirm"],
  L3_ALL_CLEAN_OPTIONS_REFUSED: ["all_compatible_configurations_refused"],
  L4_PROGRESS_REPETITIONS_ONLY: ["progression_repetitions_increased"],
  L5_PROGRESS_NEXT_REAL_LOAD: ["progression_next_real_load"],
  L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK: ["time_budget_removed_unstarted_work"],
  L7_HEALTH_SIGNAL_BEFORE_SESSION: ["safety_stop_session"],
  L8_HEALTH_SIGNAL_DURING_ACTIVE_SESSION: ["safety_stop_movement"]
};
for (const [caseId, expectedCodes] of Object.entries(requiredReasonCodes)) {
  const actualCodes = byId[caseId]?.expected.reasons?.map((reason) => reason.code) ?? [];
  if (!equal(actualCodes, expectedCodes)) fail(`case ${caseId}`, `raisons normatives modifiées : ${JSON.stringify(actualCodes)}`);
}

const canonicalPlans = {
  S1_BEGINNER_20_NO_EQUIPMENT: [
    ["incline_pushup", 4, 6, null],
    ["bodyweight_squat", 4, 8, null],
    ["bodyweight_hinge", 3, 8, null]
  ],
  S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT: [
    ["incline_pushup", 4, 6, null],
    ["bodyweight_squat", 4, 8, null],
    ["bodyweight_hinge", 4, 8, null]
  ],
  S3_RETURN_30_RECALIBRATION_SELECTED: [
    ["one_arm_row", 3, 8, 6],
    ["floor_press", 4, 6, 6],
    ["goblet_squat", 3, 8, 8],
    ["romanian_deadlift", 3, 8, 8]
  ],
  S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED: [
    ["incline_pushup", 3, 6, null],
    ["bodyweight_squat", 2, 8, null],
    ["bodyweight_hinge", 2, 8, null]
  ],
  S5_PERSISTENT_REFUSAL_NO_PAIN: [
    ["one_arm_row", 4, 10, 8],
    ["incline_pushup", 3, 6, null],
    ["goblet_squat", 3, 10, 10],
    ["romanian_deadlift", 3, 10, 10]
  ]
};
for (const [caseId, expectedSignature] of Object.entries(canonicalPlans)) {
  const actualSignature = planSignature(byId[caseId]?.expected.plan ?? []);
  if (!equal(actualSignature, expectedSignature)) fail(`case ${caseId}`, `plan canonique modifié : ${JSON.stringify(actualSignature)}`);
}

const canonicalSessionInvariants = {
  S1_BEGINNER_20_NO_EQUIPMENT: { decision: "generate_session", mode: "normal", automaticProgression: false },
  S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT: { decision: "generate_session", mode: "normal", automaticProgression: false, persistentInventoryChanged: false },
  S3_RETURN_30_RECALIBRATION_SELECTED: { decision: "generate_session", mode: "recalibration", automaticProgression: false },
  S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED: { decision: "resume_or_adapt_active_session", mode: "normal", automaticProgression: false, confirmedImmutable: true, createsDebt: false },
  S5_PERSISTENT_REFUSAL_NO_PAIN: { decision: "generate_session", mode: "normal", automaticProgression: false }
};
for (const [caseId, invariants] of Object.entries(canonicalSessionInvariants)) {
  for (const [field, expectedValue] of Object.entries(invariants)) {
    if (byId[caseId]?.expected[field] !== expectedValue) fail(`case ${caseId}`, `invariant ${field} attendu : ${expectedValue}`);
  }
}
if (Object.hasOwn(byId.S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT.input.request, "mode")) {
  fail("case S2_REGULAR_30_USUAL_EQUIPMENT_ABSENT", "le mode doit être absent pour tester le fallback normal");
}

const normal = byId.S1_BEGINNER_20_NO_EQUIPMENT;
const light = byId.L1_LIGHT_COMPONENTWISE_REDUCTION;
for (const normalRow of normal.expected.plan) {
  const lightRow = light.expected.plan.find((row) => row.exerciseId === normalRow.exerciseId);
  if (!lightRow) {
    fail("case L1_LIGHT_COMPONENTWISE_REDUCTION", `mouvement normal supprimé malgré le bloc minimal : ${normalRow.exerciseId}`);
    continue;
  }
  if (lightRow.sets > normalRow.sets || lightRow.targetReps > normalRow.targetReps) {
    fail("case L1_LIGHT_COMPONENTWISE_REDUCTION", `${normalRow.exerciseId} est plus exigeant que le plan normal`);
  }
}
if (!light.expected.plan.some((row) => row.sets < normal.expected.plan.find((candidate) => candidate.exerciseId === row.exerciseId).sets)) {
  fail("case L1_LIGHT_COMPONENTWISE_REDUCTION", "aucune réduction stricte observée");
}
if (light.expected.estimatedSeconds >= normal.expected.estimatedSeconds) fail("case L1_LIGHT_COMPONENTWISE_REDUCTION", "la durée doit être strictement réduite");

const noClean = byId.L3_ALL_CLEAN_OPTIONS_REFUSED;
const eligibleAfterRefusal = Object.entries(catalog).filter(([exerciseId, exercise]) =>
  supportsExercise(noClean.input, exercise) && !refusedExercise(noClean.input, exerciseId, catalog)
);
if (eligibleAfterRefusal.length) fail("case L3_ALL_CLEAN_OPTIONS_REFUSED", `configurations encore éligibles : ${eligibleAfterRefusal.map(([id]) => id).join(", ")}`);

const s4 = byId.S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED;
if (s4.expected.sessionId !== s4.input.activeSession.sessionId || s4.expected.mode !== s4.input.activeSession.mode) {
  fail("case S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED", "identité ou mode de la séance active modifié");
}
if (s4.input.activeSession.catalogVersion !== manifest.catalogVersion || s4.input.activeSession.decisionPolicyVersion !== manifest.decisionPolicyVersion) {
  fail("case S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED", "la séance active doit porter ses versions d'origine");
}
if (!equal(s4.expected.confirmed, s4.input.activeSession.confirmed)) {
  fail("case S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED", "les séries confirmées de la séance active ne sont pas répétées exactement dans la sortie");
}
const s4Sources = s4.expected.plan.map((row) => row.sourceExerciseId).sort();
const s4UnstartedIds = s4.input.activeSession.unstarted.map((row) => row.exerciseId).sort();
if (!equal(s4Sources, s4UnstartedIds)) {
  fail("case S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED", "le travail recomposé ne couvre pas exactement les lignes non commencées");
}
if (s4.expected.createsDebt !== false) fail("case S4_ACTIVE_INTERRUPTED_CONTEXT_CHANGED", "une reprise ne doit créer aucune dette");

const s3 = byId.S3_RETURN_30_RECALIBRATION_SELECTED;
const s3References = new Map(s3.input.history[0].references.map((reference) => [reference.exerciseId, reference]));
const s3Weights = s3.input.todayInventory[0].perUnitWeightsKg;
for (const row of s3.expected.plan) {
  const reference = s3References.get(row.exerciseId);
  const lowerSteps = s3Weights.filter((weight) => weight < reference.loadKg).sort((a, b) => a - b);
  const expectedLoad = lowerSteps.at(-1) ?? reference.loadKg;
  if (row.load.kg !== expectedLoad || row.targetReps !== catalog[row.exerciseId].repRange.min) {
    fail("case S3_RETURN_30_RECALIBRATION_SELECTED", `${row.exerciseId} ne suit pas le palier inférieur réel et le bas de plage`);
  }
}

const l2 = byId.L2_RETURN_QUESTION_UNANSWERED;
const lastL2HistoryAt = Math.max(...l2.input.history.map((entry) => Date.parse(entry.endedAt)));
const l2Days = (Date.parse(l2.now) - lastL2HistoryAt) / 86_400_000;
if (l2Days < policy.returnQuestionAfterDaysWithoutComparableExposure || Object.hasOwn(l2.input.request, "returnQuestionAnswer")) {
  fail("case L2_RETURN_QUESTION_UNANSWERED", "le seuil de reconfirmation doit être atteint sans exposer une réponse inutilisée");
}
const l2References = new Map(l2.input.history[0].references.map((reference) => [reference.exerciseId, reference]));
for (const row of l2.expected.plan) {
  const reference = l2References.get(row.exerciseId);
  if (row.referenceStatus !== "reconfirmation_pending" || row.load.kg !== reference.loadKg || row.targetReps !== reference.targetReps) {
    fail("case L2_RETURN_QUESTION_UNANSWERED", `${row.exerciseId} ne conserve pas exactement la référence en attente`);
  }
}

const finish = byId.L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK;
if (finish.expected.createsDebt !== false || finish.expected.estimatedSeconds > finish.input.remainingSeconds) {
  fail("case L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK", "la fin à l'heure doit tenir sans dette");
}
const countSets = (rows) => rows.reduce((counts, row) => {
  counts[row.exerciseId] = (counts[row.exerciseId] ?? 0) + row.sets;
  return counts;
}, {});
const beforeFinish = countSets(finish.input.unstarted);
const afterFinish = countSets([...(finish.expected.plan ?? []), ...(finish.expected.removed ?? [])]);
const sortedCounts = (counts) => Object.fromEntries(Object.entries(counts).sort(([left], [right]) => left.localeCompare(right)));
if (!equal(sortedCounts(beforeFinish), sortedCounts(afterFinish))) {
  fail("case L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK", "la partition restant + retiré ne correspond pas au travail initialement non commencé");
}
for (const [index, row] of finish.input.unstarted.entries()) {
  if (!Number.isInteger(row.targetReps) || !Number.isInteger(row.restSeconds) || typeof row.referenceStatus !== "string") {
    fail(`case L6_FINISH_ON_TIME_REMOVES_UNSTARTED_WORK.input.unstarted[${index}]`, "la prescription non commencée doit être complète");
  }
}

const safetyBefore = byId.L7_HEALTH_SIGNAL_BEFORE_SESSION;
if (safetyBefore.expected.decision !== "stop_standard_session" || safetyBefore.expected.plan.length !== 0 || safetyBefore.expected.differentiatedClinicalOrientation !== false) {
  fail("case L7_HEALTH_SIGNAL_BEFORE_SESSION", "arrêt standard conservateur exact requis");
}
const safetyDuring = byId.L8_HEALTH_SIGNAL_DURING_ACTIVE_SESSION;
if (safetyDuring.expected.decision !== "stop_current_movement" || !equal(safetyDuring.expected.confirmed, safetyDuring.input.confirmed) || safetyDuring.expected.loadedAlternative !== null || !equal(safetyDuring.expected.exposedActions, ["end_session"])) {
  fail("case L8_HEALTH_SIGNAL_DURING_ACTIVE_SESSION", "branche conservatrice pendant la séance incohérente");
}

for (const fixture of cases) delete fixture.__manifest;

if (errors.length) {
  console.error(`FAIL ${errors.length} erreur(s) dans ${fixturePath}`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`PASS ${cases.length} cas V2, ${exerciseIds.length} mouvements, ${manifest.substitutions.length} substitutions`);
console.log(`Versions : catalogue=${manifest.catalogVersion}, décision=${manifest.decisionPolicyVersion}`);
console.log("Statut : preview V2 interne vérifiable, non activée dans l’interface ni la persistance");
