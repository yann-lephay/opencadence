#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultFixturePath = path.resolve(scriptDir, "../fixtures/ios-engine-v1/cases.json");
const fixturePath = path.resolve(process.cwd(), process.argv[2] ?? defaultFixturePath);
const errors = [];

function fail(scope, message) { errors.push(`${scope}: ${message}`); }
function isObject(value) { return Boolean(value) && typeof value === "object" && !Array.isArray(value); }
function unique(values) { return new Set(values).size === values.length; }
function isoMillis(value) { return typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && !Number.isNaN(Date.parse(value)); }
function hoursBetween(earlier, later) { return (Date.parse(later) - Date.parse(earlier)) / 3_600_000; }
function mergedInput(defaults, input) {
  return { ...defaults, ...input, calibrations: input.calibrations ?? defaults.calibrations, limitations: input.limitations ?? defaults.limitations };
}

function expectedReadiness(input, now) {
  const sessions = [...input.history]
    .filter((entry) => isoMillis(entry.endedAt) && Number.isFinite(entry.effort) && Number.isFinite(entry.painScore))
    .sort((a, b) => Date.parse(a.endedAt) - Date.parse(b.endedAt));
  let factor = 1;
  if (sessions.length) {
    const last = sessions.at(-1);
    const recent = sessions.slice(-3);
    const repeatedHighEffort = recent.filter((entry) => entry.effort >= 9).length >= 2;
    const hours = hoursBetween(last.endedAt, now);
    const days = hours / 24;
    if (last.painScore >= 5) factor = 0.55;
    else if (repeatedHighEffort) factor = 0.65;
    else if (hours < 24) factor = 0.55;
    else if (hours < 48 && last.effort >= 8) factor = 0.75;
    else if (days > 14) factor = 0.6;
    else if (days >= 8) factor = 0.75;
    else if (last.effort >= 9 || last.painScore >= 3) factor = 0.75;
  }
  if (input.symptomTracking?.enabled && input.symptomTracking.todayScore >= 6) factor = Math.min(factor, 0.65);
  return factor;
}

function expectedHardRower(input, now, factor) {
  if (input.durationMinutes !== 45 || factor !== 1) return false;
  if (!input.inventory.some((item) => item.category === "rower")) return false;
  if (input.symptomTracking?.enabled && input.symptomTracking.todayScore >= 3) return false;
  return !input.history.some((entry) => entry.hardRowerFinisher && isoMillis(entry.endedAt) && hoursBetween(entry.endedAt, now) >= 0 && hoursBetween(entry.endedAt, now) < 168);
}

function supportsConfiguration(item, configuration) {
  return item.supportedConfigurations?.includes(configuration) && !(configuration === "pair" && item.units < 2);
}

function supportsLoad(inventory, recommendation) {
  return inventory.some((item) => {
    if (item.category !== recommendation.category || !supportsConfiguration(item, recommendation.configuration)) return false;
    if (item.category === "fixed_dumbbell") return item.weightKg === recommendation.perUnitWeightKg;
    if (item.category === "adjustable_dumbbell") return item.perUnitWeightsKg?.includes(recommendation.perUnitWeightKg);
    return recommendation.perUnitWeightKg === undefined;
  });
}

function planEquipmentCategories(plan, catalog) {
  const categories = new Set();
  for (const row of plan) for (const requirement of catalog[row.exerciseKey]?.equipment ?? []) categories.add(requirement.category);
  return categories;
}

function compatiblePatterns(inventory, catalog) {
  const patterns = new Set();
  for (const exercise of Object.values(catalog)) {
    const compatible = exercise.equipment?.every((requirement) =>
      inventory.some((item) => item.category === requirement.category && supportsConfiguration(item, requirement.configuration))
    );
    if (compatible) patterns.add(exercise.pattern);
  }
  return patterns;
}

function rollingPriorityFirst(rollingState) {
  const order = ["pull", "push", "knee", "hinge"];
  return [...order].sort((a, b) => {
    const tuple = (pattern) => {
      const target7 = rollingState.targets7[pattern];
      const target21 = rollingState.targets21[pattern];
      return [
        Math.max(0, target7 - rollingState.credits7[pattern]) / target7,
        Math.max(0, target21 - rollingState.credits21[pattern]) / target21,
        rollingState.profilePriorities[pattern],
        rollingState.daysSinceExposure[pattern],
        -order.indexOf(pattern)
      ];
    };
    const left = tuple(a);
    const right = tuple(b);
    for (let i = 0; i < left.length; i += 1) if (left[i] !== right[i]) return right[i] - left[i];
    return 0;
  })[0];
}

function scanBannedKeys(value, scope, bannedKeys) {
  if (Array.isArray(value)) return value.forEach((item, index) => scanBannedKeys(item, `${scope}[${index}]`, bannedKeys));
  if (!isObject(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (bannedKeys.has(key)) fail(scope, `cle personnelle interdite: ${key}`);
    scanBannedKeys(child, `${scope}.${key}`, bannedKeys);
  }
}

let manifest;
try { manifest = JSON.parse(await readFile(fixturePath, "utf8")); }
catch (error) { console.error(`FAIL impossible de lire ${fixturePath}: ${error.message}`); process.exit(1); }

if (manifest.version !== "1.0") fail("manifest", "version attendue: 1.0");
if (!Array.isArray(manifest.requiredRuleIds) || !manifest.requiredRuleIds.length) fail("manifest", "requiredRuleIds non vide requis");
if (!Array.isArray(manifest.candidateEquipmentCategories) || !manifest.candidateEquipmentCategories.length) fail("manifest", "candidateEquipmentCategories non vide requis");
if (!Array.isArray(manifest.heldEquipmentCategories)) fail("manifest", "heldEquipmentCategories doit etre un tableau");
if (!isObject(manifest.inputDefaults?.calibrations) || !Array.isArray(manifest.inputDefaults?.limitations)) fail("manifest", "inputDefaults doit fournir calibrations et limitations");
if (!isObject(manifest.exerciseCatalog) || !Object.keys(manifest.exerciseCatalog).length) fail("manifest", "exerciseCatalog non vide requis");
if (!isObject(manifest.calibratedExerciseCatalog) || !Object.keys(manifest.calibratedExerciseCatalog).length) fail("manifest", "calibratedExerciseCatalog non vide requis");
if (!isObject(manifest.conditioningCatalog) || !Object.keys(manifest.conditioningCatalog).length) fail("manifest", "conditioningCatalog non vide requis");
if (!isObject(manifest.planProfiles) || !Object.keys(manifest.planProfiles).length) fail("manifest", "planProfiles non vide requis");
if (!Array.isArray(manifest.equipmentConfigurationGates) || !manifest.equipmentConfigurationGates.length) fail("manifest", "equipmentConfigurationGates non vide requis");
if (!Array.isArray(manifest.cases) || !manifest.cases.length) fail("manifest", "cases non vide requis");

const rules = manifest.requiredRuleIds ?? [];
const candidates = manifest.candidateEquipmentCategories ?? [];
const held = (manifest.heldEquipmentCategories ?? []).map((entry) => entry.id);
const equipmentCatalog = new Set([...candidates, ...held]);
const exerciseCatalog = { ...(manifest.exerciseCatalog ?? {}), ...(manifest.calibratedExerciseCatalog ?? {}) };
const planProfiles = manifest.planProfiles ?? {};
const caseIds = (manifest.cases ?? []).map((entry) => entry.id);
if (!unique(rules)) fail("manifest", "requiredRuleIds dupliques");
if (!unique(candidates) || !unique(held) || !unique(caseIds)) fail("manifest", "categories ou cas dupliques");
for (const category of candidates) if (held.includes(category)) fail("manifest", `${category} candidate et retenue`);
for (const [index, entry] of (manifest.heldEquipmentCategories ?? []).entries()) {
  if (!isObject(entry) || typeof entry.id !== "string" || typeof entry.reason !== "string" || entry.reason.length < 20) fail(`heldEquipmentCategories[${index}]`, "id et raison explicite requis");
}

for (const [exerciseKey, exercise] of Object.entries(exerciseCatalog)) {
  const scope = `exerciseCatalog.${exerciseKey}`;
  if (!isObject(exercise) || !["pull", "push", "knee", "hinge"].includes(exercise.pattern)) fail(scope, "pattern invalide");
  if (typeof exercise.variant !== "string" || typeof exercise.target !== "string") fail(scope, "variant et target requis");
  if (!Number.isInteger(exercise.restSeconds) || exercise.restSeconds < 30) fail(scope, "restSeconds entier >=30 requis");
  if (!Array.isArray(exercise.equipment) || !exercise.equipment.length) fail(scope, "exigence materielle requise");
  for (const requirement of exercise.equipment ?? []) if (!equipmentCatalog.has(requirement.category)) fail(scope, `categorie inconnue: ${requirement.category}`);
  if (exerciseKey in manifest.calibratedExerciseCatalog && !["foundation", "established"].includes(exercise.calibrationBand)) fail(scope, "calibrationBand requis");
}

for (const [conditioningKey, conditioning] of Object.entries(manifest.conditioningCatalog ?? {})) {
  if (!equipmentCatalog.has(conditioning.category) || typeof conditioning.configuration !== "string" || typeof conditioning.target !== "string") fail(`conditioningCatalog.${conditioningKey}`, "categorie, configuration et target requis");
}

for (const [profileId, plan] of Object.entries(planProfiles)) {
  if (!Array.isArray(plan) || !plan.length) fail(`planProfiles.${profileId}`, "plan ordonne non vide requis");
  for (const [index, row] of (plan ?? []).entries()) {
    if (!exerciseCatalog[row.exerciseKey]) fail(`planProfiles.${profileId}[${index}]`, `exercice inconnu: ${row.exerciseKey}`);
    if (!Number.isInteger(row.sets) || row.sets < 1) fail(`planProfiles.${profileId}[${index}]`, "sets entier positif requis");
  }
  const setsByPattern = new Map();
  for (const row of plan ?? []) {
    const pattern = exerciseCatalog[row.exerciseKey]?.pattern;
    setsByPattern.set(pattern, (setsByPattern.get(pattern) ?? 0) + row.sets);
  }
  for (const [pattern, sets] of setsByPattern) if (sets > 4) fail(`planProfiles.${profileId}`, `${sets} series sur ${pattern}, plafond 4`);
}

const contractPath = path.resolve(path.dirname(fixturePath), manifest.contract ?? "");
let contract = "";
try { contract = await readFile(contractPath, "utf8"); }
catch (error) { fail("manifest", `contrat introuvable: ${error.message}`); }
for (const ruleId of rules) if (!contract.includes(`\`${ruleId}\``)) fail("contract", `regle absente: ${ruleId}`);

const gateKeys = new Set();
for (const [index, gate] of (manifest.equipmentConfigurationGates ?? []).entries()) {
  const scope = `equipmentConfigurationGates[${index}]`;
  const key = `${gate.category}:${gate.configuration}`;
  if (gateKeys.has(key)) fail(scope, `gate duplique: ${key}`);
  gateKeys.add(key);
  if (!candidates.includes(gate.category)) fail(scope, `categorie non candidate: ${gate.category}`);
  if (typeof gate.schemaId !== "string" || !gate.schemaId) fail(scope, "schemaId requis");
  if (!Array.isArray(gate.movementKeys)) fail(scope, "movementKeys doit etre un tableau");
  if (!gate.movementKeys?.length && !gate.conditioningKeys?.length) fail(scope, "movementKeys ou conditioningKeys requis");
  for (const movement of gate.movementKeys ?? []) if (!exerciseCatalog[movement]) fail(scope, `mouvement inconnu: ${movement}`);
  for (const conditioning of gate.conditioningKeys ?? []) if (!manifest.conditioningCatalog[conditioning]) fail(scope, `conditionnement inconnu: ${conditioning}`);
  if (!Array.isArray(gate.fixtureIds) || !gate.fixtureIds.length) fail(scope, "fixtureIds requis");
  for (const id of gate.fixtureIds ?? []) if (!caseIds.includes(id)) fail(scope, `fixture inconnue: ${id}`);
  if (gate.status !== "engine_ready_visual_pending" || gate.illustrationProof !== null) fail(scope, "doit rester engine_ready_visual_pending sans fausse preuve visuelle");
}

const allowedDecisions = new Set(["generate_workout", "generate_makeup", "resume_active_session", "block_standard_mode", "request_valid_input", "active_session_transition"]);
const nominalBudgets = new Map([[20, 8], [30, 12], [45, 16]]);
const bannedKeys = new Set(["name", "email", "note", "painLocation", "heightCm", "bodyWeightKg"]);
const coveredRules = new Set();
const positiveEquipment = new Set();

for (const [index, fixture] of (manifest.cases ?? []).entries()) {
  const scope = fixture.id ? `case ${fixture.id}` : `case[${index}]`;
  const input = mergedInput(manifest.inputDefaults ?? {}, fixture.input ?? {});
  const expected = fixture.expected ?? {};
  if (typeof fixture.id !== "string" || !fixture.id) fail(scope, "id requis");
  if (typeof fixture.description !== "string" || fixture.description.length < 20) fail(scope, "description explicite requise");
  if (!isoMillis(fixture.now)) fail(scope, "now ISO UTC avec millisecondes requis");
  if (!isObject(fixture.input) || !isObject(expected)) fail(scope, "input et expected objets requis");
  if (!Array.isArray(fixture.ruleIds) || !fixture.ruleIds.length) fail(scope, "ruleIds non vide requis");
  for (const ruleId of fixture.ruleIds ?? []) { if (!rules.includes(ruleId)) fail(scope, `regle non declaree: ${ruleId}`); coveredRules.add(ruleId); }
  if (!allowedDecisions.has(expected.decision)) fail(scope, `decision inconnue: ${expected.decision}`);
  if (!Array.isArray(expected.requiredReasonCodes) || !expected.requiredReasonCodes.length || !unique(expected.requiredReasonCodes ?? [])) fail(scope, "requiredReasonCodes non vide et unique requis");
  if (!nominalBudgets.has(input.durationMinutes)) fail(scope, "durationMinutes doit valoir 20, 30 ou 45");
  if (!Array.isArray(input.inventory) || !input.inventory.length) fail(scope, "inventaire non vide requis");
  if (!Array.isArray(input.history)) fail(scope, "history doit etre un tableau");
  if (!isObject(input.calibrations) || typeof input.calibrations.upper !== "string" || typeof input.calibrations.lower !== "string") fail(scope, "calibrations haut/bas requises");
  if (!Array.isArray(input.limitations)) fail(scope, "limitations explicites requises");
  if (!isObject(input.symptomTracking)) fail(scope, "symptomTracking requis");
  if (input.symptomTracking?.enabled === false && input.symptomTracking.todayScore !== null) fail(scope, "suivi desactive avec score");
  if (input.symptomTracking?.enabled === true && (!Number.isInteger(input.symptomTracking.todayScore) || input.symptomTracking.todayScore < 0 || input.symptomTracking.todayScore > 10)) fail(scope, "score active entre 0 et 10 requis");

  let pairWithOneUnit = false;
  for (const [equipmentIndex, item] of (input.inventory ?? []).entries()) {
    const itemScope = `${scope}.inventory[${equipmentIndex}]`;
    if (!equipmentCatalog.has(item.category)) fail(itemScope, `categorie inconnue: ${item.category}`);
    if (!Number.isInteger(item.units) || item.units < 1) fail(itemScope, "units entier positif requis");
    if (!Array.isArray(item.supportedConfigurations) || !item.supportedConfigurations.length) fail(itemScope, "supportedConfigurations requis");
    if (item.supportedConfigurations?.includes("pair") && item.units < 2) pairWithOneUnit = true;
    if (item.category === "fixed_dumbbell" && !(item.weightKg > 0)) fail(itemScope, "weightKg positif requis");
    if (item.category === "adjustable_dumbbell") {
      if (!Array.isArray(item.perUnitWeightsKg) || !item.perUnitWeightsKg.length) fail(itemScope, "perUnitWeightsKg requis");
      else if (!unique(item.perUnitWeightsKg) || item.perUnitWeightsKg.some((weight) => !(weight > 0))) fail(itemScope, "poids positifs uniques requis");
      else if (item.perUnitWeightsKg.some((weight, i, weights) => i > 0 && weight <= weights[i - 1])) fail(itemScope, "poids strictement croissants requis");
    }
  }
  if (pairWithOneUnit && expected.errorCode !== "equipment.pair_requires_two_units") fail(scope, "une paire exige deux unites ou une erreur explicite");

  const historyIds = [];
  let futureHistory = false;
  for (const entry of input.history ?? []) {
    if (typeof entry.sessionId !== "string" || !entry.sessionId) fail(scope, "chaque historique exige sessionId"); else historyIds.push(entry.sessionId);
    if (entry.endedAt && !isoMillis(entry.endedAt)) fail(scope, `endedAt invalide: ${entry.endedAt}`);
    if (entry.endedAt && Date.parse(entry.endedAt) > Date.parse(fixture.now)) futureHistory = true;
    if ("exerciseKey" in entry || "completedReps" in entry || "lastSetRir" in entry) fail(scope, "resultats d'exercice a imbriquer dans exerciseRecords");
    if (entry.exerciseRecords && !Array.isArray(entry.exerciseRecords)) fail(scope, "exerciseRecords doit etre un tableau");
  }
  if (!unique(historyIds)) fail(scope, "sessionId historique duplique");
  if (futureHistory && expected.errorCode !== "history.session_in_future") fail(scope, "historique futur sans erreur explicite");

  if (expected.decision === "request_valid_input") {
    const validError =
      (expected.errorCode === "equipment.pair_requires_two_units" && pairWithOneUnit) ||
      (expected.errorCode === "history.session_in_future" && futureHistory) ||
      (expected.errorCode === "session.snapshot_corrupt" && input.activeSession?.checksumValid === false && input.previousValidSnapshot?.checksumValid === true);
    if (!validError) fail(scope, `errorCode non prouve: ${expected.errorCode}`);
    if (expected.errorCode === "session.snapshot_corrupt") {
      if (expected.restoredVersion !== input.previousValidSnapshot?.version) fail(scope, "version restauree incoherente");
      if (input.activeSession?.sessionId !== input.previousValidSnapshot?.sessionId || !(input.previousValidSnapshot?.version < input.activeSession?.version)) fail(scope, "snapshot precedent doit appartenir a la meme seance et avoir une version anterieure");
    }
  }

  if (expected.decision === "generate_workout") {
    if (pairWithOneUnit || futureHistory) fail(scope, "entree invalide ne pouvant generer une seance");
    const factor = expectedReadiness(input, fixture.now);
    if (expected.readiness?.factor !== factor) fail(scope, `facteur attendu ${factor}, fixture ${expected.readiness?.factor}`);
    const baseBudget = nominalBudgets.get(input.durationMinutes);
    const patternCapacity = 4 * compatiblePatterns(input.inventory, exerciseCatalog).size;
    const finalBudget = Math.min(Math.max(4, Math.round(baseBudget * factor)), patternCapacity);
    if (expected.basePrimarySetBudget !== baseBudget) fail(scope, `budget nominal attendu ${baseBudget}`);
    if (expected.finalPrimarySetBudget !== finalBudget) fail(scope, `budget final attendu ${finalBudget}`);
    const hardRower = expectedHardRower(input, fixture.now, factor);
    if (expected.allowHardRower !== hardRower) fail(scope, `allowHardRower attendu ${hardRower}`);
    const plan = planProfiles[expected.planProfileId];
    if (!Array.isArray(plan)) fail(scope, `planProfileId inconnu: ${expected.planProfileId}`);
    else {
      const setCount = plan.reduce((sum, row) => sum + row.sets, 0);
      if (setCount !== finalBudget) fail(scope, `plan ${setCount} series pour budget ${finalBudget}`);
      const planKeys = plan.map((row) => row.exerciseKey);
      const patterns = new Set(planKeys.map((key) => exerciseCatalog[key]?.pattern));
      for (const key of expected.forbiddenExerciseKeys ?? []) if (planKeys.includes(key)) fail(scope, `exercice interdit present: ${key}`);
      for (const key of expected.stableExerciseKeys ?? []) if (!planKeys.includes(key)) fail(scope, `variante stable absente: ${key}`);
      for (const pattern of expected.requiredPatterns ?? []) if (!patterns.has(pattern)) fail(scope, `pattern requis absent: ${pattern}`);
      for (const pattern of expected.omittedPatterns ?? []) if (patterns.has(pattern)) fail(scope, `pattern annonce omis mais present: ${pattern}`);
      for (const row of plan) for (const requirement of exerciseCatalog[row.exerciseKey]?.equipment ?? []) {
        if (!input.inventory.some((item) => item.category === requirement.category && supportsConfiguration(item, requirement.configuration))) fail(scope, `${row.exerciseKey} exige ${requirement.category}:${requirement.configuration}`);
      }
      const used = planEquipmentCategories(plan, exerciseCatalog);
      if (hardRower) used.add("rower");
      const declaredUsed = new Set(expected.usedEquipmentCategories ?? []);
      for (const category of used) if (!declaredUsed.has(category)) fail(scope, `materiel du plan non declare utilise: ${category}`);
      for (const category of declaredUsed) if (!used.has(category)) fail(scope, `materiel declare utilise mais absent: ${category}`);
      for (const category of used) positiveEquipment.add(category);
    }
    if (input.rollingState) {
      const patterns = ["pull", "push", "knee", "hinge"];
      for (const field of ["credits7", "credits21", "targets7", "targets21", "profilePriorities", "daysSinceExposure"]) {
        if (!isObject(input.rollingState[field]) || patterns.some((pattern) => !Number.isFinite(input.rollingState[field][pattern]))) fail(scope, `rollingState.${field} incomplet`);
      }
      const first = rollingPriorityFirst(input.rollingState);
      if (expected.rollingPriorityFirst !== first) fail(scope, `priorite rolling attendue ${first}`);
      const planSets = new Map((planProfiles[expected.planProfileId] ?? []).map((row) => [exerciseCatalog[row.exerciseKey]?.pattern, row.sets]));
      const maxSets = Math.max(...planSets.values());
      if (planSets.get(first) !== maxSets) fail(scope, `le pattern prioritaire ${first} ne recoit pas la serie supplementaire`);
    }
  }

  if (expected.decision === "block_standard_mode") {
    if (!["pregnancy", "postpartum"].includes(input.physiologicalContext) || expected.blockReason !== "life_stage.dedicated_mode_required") fail(scope, "blocage grossesse/post-partum dedie requis");
    if ("finalPrimarySetBudget" in expected) fail(scope, "blocage avec budget interdit");
  }

  if (expected.decision === "resume_active_session") {
    if (!isObject(input.activeSession) || !isoMillis(input.activeSession.restDeadline)) fail(scope, "activeSession et restDeadline requis");
    if (expected.restTimer?.deadline !== input.activeSession.restDeadline) fail(scope, "echeance conservee requise");
    const remaining = Math.max(0, Math.ceil((Date.parse(input.activeSession.restDeadline) - Date.parse(fixture.now)) / 1000));
    if (expected.restTimer?.remainingSeconds !== remaining) fail(scope, `temps restant attendu ${remaining}`);
    if (remaining === expected.restTimer?.mustNotResetToSeconds) fail(scope, "timer reinitialise");
  }

  if (expected.decision === "generate_makeup") {
    const included = expected.makeup?.includedExerciseKeys ?? [];
    const excluded = expected.makeup?.excludedExerciseKeys ?? [];
    if (!included.length || included.some((key) => excluded.includes(key))) fail(scope, "rattrapage incoherent");
    if (expected.makeup?.includeConditioning !== false || expected.makeup?.createsDebt !== false) fail(scope, "rattrapage sans conditionnement et dette requis");
    for (const exerciseKey of included) {
      if (!exerciseCatalog[exerciseKey]) fail(scope, `exercice de rattrapage inconnu: ${exerciseKey}`);
      for (const requirement of exerciseCatalog[exerciseKey]?.equipment ?? []) {
        if (!input.inventory.some((item) => item.category === requirement.category && supportsConfiguration(item, requirement.configuration))) fail(scope, `${exerciseKey} de rattrapage exige ${requirement.category}:${requirement.configuration}`);
      }
    }
  }

  if (expected.decision === "active_session_transition") {
    const event = input.sessionEvent;
    const active = input.activeSession;
    if (!isObject(event) || !isObject(active) || typeof event.eventId !== "string") fail(scope, "event et activeSession requis");
    const duplicate = active?.processedEventIds?.includes(event?.eventId);
    if (duplicate && (expected.transition !== "duplicate_event_ignored" || expected.completedSetCount !== active.completedSetCount)) fail(scope, "evenement duplique non idempotent");
    if (event?.type === "pain_reported" && event.painScore >= 3 && event.painScore <= 4) {
      if (expected.transition !== "stop_current_set") fail(scope, "douleur 3-4 doit arreter la serie");
      if (JSON.stringify(expected.offeredActions) !== JSON.stringify(["reduce_range", "substitute_exercise", "stop_exercise"])) fail(scope, "douleur 3-4 exige les trois recoveries bornees");
    }
    if (event?.type === "pain_reported" && event.painScore >= 5 && expected.transition !== "stop_current_exercise") fail(scope, "douleur >=5 doit arreter l'exercice");
    if (event?.type === "alert_reported" && event.redFlags?.length) {
      const knownRedFlags = new Set(["chest_pressure", "syncope", "neurological_symptom", "unusual_severe_breathlessness"]);
      if (event.redFlags.some((flag) => !knownRedFlags.has(flag)) || expected.transition !== "stop_session_and_orient" || expected.mustNotDiagnose !== true) fail(scope, "signal d'alerte reconnu: arret, orientation et aucun diagnostic requis");
    }
    if (event?.type === "pause_rest") {
      const remaining = Math.max(0, Math.ceil((Date.parse(active.restDeadline) - Date.parse(fixture.now)) / 1000));
      if (expected.transition !== "rest_paused" || expected.pausedRemainingSeconds !== remaining || expected.restDeadline !== null) fail(scope, "pause doit figer le temps et retirer l'echeance");
    }
    if (event?.type === "resume_rest") {
      const deadline = new Date(Date.parse(fixture.now) + active.pausedRemainingSeconds * 1000).toISOString();
      if (expected.transition !== "rest_resumed" || expected.restDeadline !== deadline || expected.pausedRemainingSeconds !== null) fail(scope, "resume_rest doit creer l'echeance depuis le temps fige");
    }
    if (event?.type === "skip_rest" && (expected.transition !== "rest_completed" || expected.restDeadline !== null)) fail(scope, "skip_rest doit terminer le repos");
    if (event?.type === "restart_rest") {
      const deadline = new Date(Date.parse(fixture.now) + active.originalRestSeconds * 1000).toISOString();
      if (expected.transition !== "rest_restarted" || expected.restDeadline !== deadline) fail(scope, "restart_rest doit utiliser la duree prescrite");
    }
    if (event?.type === "persistence_failed" && (expected.transition !== "save_failed_visible" || expected.inMemoryStatePreserved !== true || expected.canRetry !== true || expected.canExportRecovery !== true || expected.completedSetCount !== active.completedSetCount)) fail(scope, "echec de persistance doit rester visible, en memoire, reessayable et exportable");
    if (Number.isInteger(active?.completedSetCount) && Number.isInteger(expected.completedSetCount) && !duplicate && expected.completedSetCount !== active.completedSetCount) fail(scope, "transition de securite modifie les series validees");
  }

  for (const category of expected.forbiddenEquipmentCategories ?? []) if (expected.usedEquipmentCategories?.includes(category)) fail(scope, `materiel utilise et interdit: ${category}`);
  for (const recommendation of expected.recommendedLoads ?? []) if (!supportsLoad(input.inventory, recommendation)) fail(scope, `charge hors inventaire: ${JSON.stringify(recommendation)}`);

  if (expected.progression) {
    const progression = expected.progression;
    const weights = input.inventory.flatMap((item) => item.category === "adjustable_dumbbell" ? item.perUnitWeightsKg ?? [] : item.category === "fixed_dumbbell" ? [item.weightKg] : []).sort((a, b) => a - b);
    if (!weights.includes(progression.perUnitWeightKg)) fail(scope, `charge progression hors inventaire: ${progression.perUnitWeightKg}`);
    const comparable = input.history.flatMap((session) => session.exerciseRecords ?? []).filter((record) => record.exerciseKey === progression.exerciseKey);
    const previousWeight = comparable.at(-1)?.perUnitWeightKg;
    if (progression.action === "increase_reps" && (JSON.stringify(progression.variablesChanged) !== JSON.stringify(["reps"]) || progression.perUnitWeightKg !== previousWeight)) fail(scope, "reps-first doit garder la charge");
    if (progression.action === "increase_load") {
      const nextWeight = weights.find((weight) => weight > previousWeight);
      if (progression.perUnitWeightKg !== nextWeight || JSON.stringify(progression.variablesChanged) !== JSON.stringify(["load", "reps_reset"])) fail(scope, "hausse atomique vers prochain palier requise");
    }
    if (progression.action === "hold_load" && (progression.variablesChanged?.length || progression.perUnitWeightKg !== previousWeight || weights.some((weight) => weight > previousWeight))) fail(scope, "hold_load incoherent");
  }

  if (expected.excludedExerciseKeys) {
    const requested = [...new Set(input.limitations.flatMap((entry) => entry.excludedExerciseKeys ?? []))].sort();
    if (JSON.stringify(expected.excludedExerciseKeys) !== JSON.stringify(requested)) fail(scope, "exclusions appliquees differentes de la saisie");
    for (const key of requested) if (!expected.forbiddenExerciseKeys?.includes(key)) fail(scope, `exclusion non verifiee dans le plan: ${key}`);
  }

  if (expected.forbidProgression === true) {
    const last = [...input.history].sort((a, b) => Date.parse(a.endedAt) - Date.parse(b.endedAt)).at(-1);
    if (!(last?.painScore >= 5)) fail(scope, "forbidProgression sans douleur precedente >=5");
  }
  for (const [exerciseKey, calibration] of Object.entries(expected.calibrationAssertions ?? {})) {
    if (!planProfiles[expected.planProfileId]?.some((row) => row.exerciseKey === exerciseKey)) fail(scope, `calibration hors plan: ${exerciseKey}`);
    const pattern = exerciseCatalog[exerciseKey]?.pattern;
    const wanted = ["pull", "push"].includes(pattern) ? input.calibrations.upper : input.calibrations.lower;
    if (calibration !== wanted) fail(scope, `calibration attendue ${wanted} pour ${exerciseKey}`);
    if (exerciseCatalog[exerciseKey]?.calibrationBand !== calibration) fail(scope, `la variante ${exerciseKey} ne declare pas la bande ${calibration}`);
  }
  if (expected.substitutionAssertion) {
    const assertion = expected.substitutionAssertion;
    const comparison = manifest.cases.find((entry) => entry.id === assertion.comparisonFixtureId);
    const currentPlan = planProfiles[expected.planProfileId] ?? [];
    const comparisonPlan = planProfiles[comparison?.expected?.planProfileId] ?? [];
    if (!comparison || comparison.now !== fixture.now || comparison.input.durationMinutes !== fixture.input.durationMinutes) fail(scope, "fixture temoin comparable requise pour la substitution");
    if (!comparisonPlan.some((row) => row.exerciseKey === assertion.fromExerciseKey)) fail(scope, "la variante remplacee doit exister dans le cas temoin");
    if (currentPlan.some((row) => row.exerciseKey === assertion.fromExerciseKey) || !currentPlan.some((row) => row.exerciseKey === assertion.toExerciseKey)) fail(scope, "la substitution attendue n'est pas observable dans le plan");
  }
  scanBannedKeys(input, `${scope}.input`, bannedKeys);
}

for (const ruleId of rules) if (!coveredRules.has(ruleId)) fail("coverage", `aucune fixture ne reference ${ruleId}`);
for (const category of candidates) if (!positiveEquipment.has(category)) fail("coverage", `aucun plan positif ne couvre ${category}`);

if (errors.length) {
  console.error(`FAIL ${errors.length} erreur(s) dans ${path.relative(process.cwd(), fixturePath)}`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`PASS ${manifest.cases.length} fixtures structurelles, ${rules.length} regles referencees, ${manifest.equipmentConfigurationGates.length} configurations moteur candidates; preuves visuelles encore en attente`);
