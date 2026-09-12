"use client";

import {
  ArrowLeft,
  Check,
  ChevronRight,
  CirclePause,
  CirclePlay,
  CircleStop,
  Minus,
  Plus,
  RotateCcw,
  SkipForward,
  TimerReset,
  TriangleAlert,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { ActiveSession, CadenceState, SetResult, WorkoutItem } from "@/lib/types";
import { ExerciseFigure, ExerciseLoop } from "./ExerciseFigure";

type RunnerProps = {
  session: ActiveSession;
  onState: (state: CadenceState) => void;
  onClose: () => void;
};

async function patchState(payload: unknown) {
  const response = await fetch("/api/state", {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Enregistrement impossible");
  return response.json() as Promise<CadenceState>;
}

function formatSeconds(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${minutes}:${String(rest).padStart(2, "0")}`;
}

function explainRir(value: string) {
  return value
    .replace(/(\d(?:[–-]\d)?) RIR/g, "$1 reps en réserve")
    .replace(/RPE (\d(?:[–-]\d)?)/g, "effort $1/10");
}

function exerciseName(value: string) {
  if (value === "Split squat") return "Fentes sur place";
  if (value === "Gainage latéral") return "Gainage latéral sur coude";
  return value;
}

function timerRange(item: WorkoutItem, setIndex: number) {
  const minuteRange = item.target.match(/(\d+)\s*[–-]\s*(\d+)\s*min/i);
  if (minuteRange) {
    return {
      min: Number(minuteRange[1]) * 60,
      max: Number(minuteRange[2]) * 60,
    };
  }

  const secondRange = item.target.match(/(\d+)\s*[–-]\s*(\d+)\s*s\b/i);
  if (secondRange) {
    return {
      min: Number(secondRange[1]),
      max: Number(secondRange[2]),
    };
  }

  const target = item.targetValues?.[setIndex] ?? item.targetValue;
  return { min: target, max: target };
}

function buildSequence(workout: ActiveSession["workout"], skippedItemIds: string[] = []) {
  const sequence: { itemIndex: number; setIndex: number }[] = [];
  const visitedPairs = new Set<string>();
  const skipped = new Set(skippedItemIds);

  workout.items.forEach((item, itemIndex) => {
    if (skipped.has(item.id)) return;
    if (!item.superset) {
      for (let setIndex = 0; setIndex < item.sets; setIndex += 1) {
        sequence.push({ itemIndex, setIndex });
      }
      return;
    }
    if (visitedPairs.has(item.superset)) return;
    visitedPairs.add(item.superset);
    const pair = workout.items
      .map((entry, index) => ({ entry, index }))
      .filter(({ entry }) => entry.superset === item.superset && !skipped.has(entry.id));
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

export function WorkoutRunner({ session, onState, onClose }: RunnerProps) {
  const workout = session.workout;
  const [itemIndex, setItemIndex] = useState(session.itemIndex);
  const [setIndex, setSetIndex] = useState(session.setIndex);
  const [progress, setProgress] = useState<Record<string, SetResult[]>>(session.progress);
  const [skippedItemIds, setSkippedItemIds] = useState(session.skippedItemIds ?? []);
  const [restSeconds, setRestSeconds] = useState(0);
  const [restPaused, setRestPaused] = useState(false);
  const [review, setReview] = useState(false);
  const [effort, setEffort] = useState(7);
  const [pain, setPain] = useState(0);
  const [painLocation, setPainLocation] = useState("");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [workTimer, setWorkTimer] = useState(0);
  const [workTimerOn, setWorkTimerOn] = useState(false);
  const [workTimerFinished, setWorkTimerFinished] = useState(false);
  const [autoStartAfterRest, setAutoStartAfterRest] = useState(false);
  const [rowerResistance, setRowerResistance] = useState(4);
  const [rowerStrokes, setRowerStrokes] = useState(0);
  const [endedEarly, setEndedEarly] = useState(false);
  const item = workout.items[itemIndex];
  const defaultValue = item?.targetValues?.[setIndex] ?? item?.targetValue ?? 0;
  const [actualValue, setActualValue] = useState(defaultValue);
  const [lastSetRir, setLastSetRir] = useState(2);
  const [loadLabel, setLoadLabel] = useState(
    item?.recommendedLoadLabel ?? item?.loadOptions?.[0]?.label ?? "",
  );
  const [loadKg, setLoadKg] = useState(
    item?.recommendedLoadKg ?? item?.loadOptions?.[0]?.totalKg ?? 0,
  );
  const sequence = useMemo(
    () => buildSequence(workout, skippedItemIds),
    [workout, skippedItemIds],
  );
  const sequenceIndex = sequence.findIndex(
    (step) => step.itemIndex === itemIndex && step.setIndex === setIndex
  );
  const countUpTimer = item?.mode === "time";
  const currentTimerRange = item ? timerRange(item, setIndex) : { min: 0, max: 0 };
  const timerGoalReached = countUpTimer && workTimer >= currentTimerRange.min;

  const completedSets = useMemo(
    () => Object.values(progress).reduce((sum, sets) => sum + sets.length, 0),
    [progress]
  );
  const totalSets = useMemo(
    () => workout.items.reduce((sum, entry) => sum + entry.sets, 0),
    [workout.items]
  );
  const completion = Math.round((completedSets / totalSets) * 100);

  useEffect(() => {
    const nextTarget = item?.targetValues?.[setIndex] ?? item?.targetValue ?? 0;
    const timerTarget = item?.variantId === "row-benchmark-4" ? 240 : 0;
    setActualValue(item?.mode === "time" || item?.variantId === "row-benchmark-4" ? 0 : nextTarget);
    setWorkTimer(timerTarget);
    setWorkTimerOn(false);
    setWorkTimerFinished(false);
    setLastSetRir(2);
    setRowerStrokes(0);
    if (item?.loadOptions?.length) {
      setLoadLabel(item.recommendedLoadLabel ?? item.loadOptions[0].label);
      setLoadKg(item.recommendedLoadKg ?? item.loadOptions[0].totalKg);
    } else {
      setLoadLabel("");
      setLoadKg(0);
    }
  }, [itemIndex, setIndex, item]);

  useEffect(() => {
    if (restSeconds <= 0 || restPaused) return;
    const interval = window.setInterval(() => {
      setRestSeconds((seconds) => Math.max(0, seconds - 1));
    }, 1000);
    return () => window.clearInterval(interval);
  }, [restSeconds, restPaused]);

  useEffect(() => {
    if (!workTimerOn) return;
    const interval = window.setInterval(() => {
      setWorkTimer((seconds) => {
        if (item?.mode === "time") {
          const elapsed = seconds + 1;
          setActualValue(elapsed);
          return elapsed;
        }
        if (seconds <= 1) {
          setWorkTimerOn(false);
          setWorkTimerFinished(true);
          return 0;
        }
        return seconds - 1;
      });
    }, 1000);
    return () => window.clearInterval(interval);
  }, [workTimerOn, item?.mode]);

  useEffect(() => {
    if (restSeconds === 0 && autoStartAfterRest) {
      setAutoStartAfterRest(false);
      setWorkTimerOn(true);
    }
  }, [restSeconds, autoStartAfterRest]);

  const savePosition = useCallback(
    async (
      nextItemIndex: number,
      nextSetIndex: number,
      nextProgress: Record<string, SetResult[]>,
      nextSkippedItemIds = skippedItemIds,
    ) => {
      try {
        const state = await patchState({
          action: "saveProgress",
          itemIndex: nextItemIndex,
          setIndex: nextSetIndex,
          progress: nextProgress,
          skippedItemIds: nextSkippedItemIds,
        });
        onState(state);
      } catch {
        // Le prochain clic retentera l’enregistrement avec tout le progrès local.
      }
    },
    [onState, skippedItemIds]
  );

  function skipExercise() {
    if (!item) return;
    setWorkTimerOn(false);
    const nextSkippedItemIds = Array.from(new Set([...skippedItemIds, item.id]));
    const currentSequence = buildSequence(workout, skippedItemIds);
    const currentStepIndex = currentSequence.findIndex(
      (step) => step.itemIndex === itemIndex && step.setIndex === setIndex,
    );
    const nextStep = currentSequence
      .slice(Math.max(0, currentStepIndex + 1))
      .find((step) => workout.items[step.itemIndex]?.id !== item.id);

    setSkippedItemIds(nextSkippedItemIds);
    if (!nextStep) {
      setEndedEarly(true);
      setReview(true);
      void savePosition(itemIndex, setIndex, progress, nextSkippedItemIds);
      return;
    }

    setItemIndex(nextStep.itemIndex);
    setSetIndex(nextStep.setIndex);
    setRestSeconds(15);
    setRestPaused(false);
    void savePosition(nextStep.itemIndex, nextStep.setIndex, progress, nextSkippedItemIds);
  }

  function stopSessionHere() {
    setWorkTimerOn(false);
    const unfinishedItemIds = workout.items
      .filter((entry) => (progress[entry.id]?.length ?? 0) < entry.sets)
      .map((entry) => entry.id);
    const nextSkippedItemIds = Array.from(new Set([...skippedItemIds, ...unfinishedItemIds]));
    setSkippedItemIds(nextSkippedItemIds);
    setEndedEarly(true);
    setReview(true);
    void savePosition(itemIndex, setIndex, progress, nextSkippedItemIds);
  }

  function completeSet() {
    if (!item) return;
    setWorkTimerOn(false);
    const isLastSet = setIndex + 1 >= item.sets;
    const nextProgress = {
      ...progress,
      [item.id]: [
        ...(progress[item.id] ?? []),
        {
          value: actualValue,
          completedAt: new Date().toISOString(),
          ...(isLastSet && item.mode === "reps"
            ? { rir: lastSetRir }
            : {}),
          ...(loadLabel ? { loadKg, loadLabel } : {}),
          ...(item.variantId.startsWith("row-") ? { resistance: rowerResistance } : {}),
          ...(item.variantId === "row-benchmark-4"
            ? {
                strokeCount: rowerStrokes || undefined,
                distanceUnknown: actualValue <= 0,
              }
            : {}),
        },
      ],
    };
    setProgress(nextProgress);

    const isLastStep = sequenceIndex < 0 || sequenceIndex + 1 >= sequence.length;
    const nextStep = isLastStep ? null : sequence[sequenceIndex + 1];

    if (isLastStep || !nextStep) {
      setReview(true);
      void savePosition(itemIndex, setIndex, nextProgress);
      return;
    }

    setItemIndex(nextStep.itemIndex);
    setSetIndex(nextStep.setIndex);
    const changingSide = item.variantId === "side-plank" && !isLastSet;
    setRestSeconds(changingSide ? 15 : item.restSeconds);
    setAutoStartAfterRest(changingSide);
    setRestPaused(false);
    void savePosition(nextStep.itemIndex, nextStep.setIndex, nextProgress);
  }

  async function finishSession() {
    setSaving(true);
    try {
      const state = await patchState({
        action: "completeSession",
        effort,
        pain,
        painLocation,
        hardRowingFinisher: workout.items.some(
          (entry) => entry.hardRower && (progress[entry.id]?.length ?? 0) > 0
        ),
        note,
        progress,
        skippedItemIds,
      });
      onState(state);
      onClose();
    } finally {
      setSaving(false);
    }
  }

  if (review) {
    return (
      <div className="runner-shell review-shell">
        <header className="runner-topbar">
          <span className="brand-mark small">O</span>
          <span>Séance terminée</span>
          <span className="runner-progress-text">{completion} %</span>
        </header>
        <main className="review-panel">
          <div className="review-kicker"><Check size={16} /> Enregistrée dès validation</div>
          <h1>{endedEarly || skippedItemIds.length ? "On s’arrête proprement." : "Comment ton corps a répondu\u00a0?"}</h1>
          <p>
            {endedEarly || skippedItemIds.length
              ? "Seules les séries réellement faites seront comptées. Le reste pourra nourrir une prochaine séance sans créer de dette d’entraînement."
              : "Ces repères pilotent le volume et le rameur de la prochaine séance."}
          </p>

          {skippedItemIds.length > 0 && (
            <div className="skipped-summary">
              <strong>Non terminé aujourd’hui</strong>
              <span>
                {workout.items
                  .filter((entry) => skippedItemIds.includes(entry.id))
                  .map((entry) => exerciseName(entry.exercise))
                  .join(" · ")}
              </span>
            </div>
          )}

          <label className="range-block">
            <span>
              Effort global
              <strong>{effort}/10</strong>
            </span>
            <input
              type="range"
              min="1"
              max="10"
              value={effort}
              onChange={(event) => setEffort(Number(event.target.value))}
            />
            <small>1 = promenade · 7 = solide · 10 = maximum</small>
          </label>

          <label className={`range-block ${pain >= 3 ? "warning" : ""}`}>
            <span>
              Gêne ou douleur
              <strong>{pain}/10</strong>
            </span>
            <input
              type="range"
              min="0"
              max="10"
              value={pain}
              onChange={(event) => setPain(Number(event.target.value))}
            />
            <small>0 = rien · 3 = à surveiller · 7+ = arrêt</small>
          </label>

          {pain > 0 && (
            <label className="note-field compact-field">
              <span>Où as-tu senti cette gêne&nbsp;?</span>
              <input
                value={painLocation}
                onChange={(event) => setPainLocation(event.target.value)}
                placeholder="Ex. avant de l’épaule droite"
              />
            </label>
          )}

          {pain >= 3 && (
            <div className="safety-note">
              <TriangleAlert size={18} />
              {pain >= 5
                ? "Arrête le mouvement concerné. Si la douleur est vive, électrique, s’accompagne d’une perte de force ou persiste, demande une évaluation appropriée."
                : "La prochaine séance sera allégée. Arrête la série si la douleur augmente, modifie l’amplitude ou remplace le mouvement concerné."}
            </div>
          )}

          <label className="note-field">
            <span>Une note pour ton futur toi — facultatif</span>
            <textarea
              value={note}
              onChange={(event) => setNote(event.target.value)}
              placeholder="Ex. Tractions faciles, épaule droite un peu raide…"
              rows={3}
            />
          </label>

          <button className="primary-button large" onClick={finishSession} disabled={saving}>
            {saving ? "Adaptation en cours…" : "Valider et préparer la suite"}
            <ChevronRight size={18} />
          </button>
        </main>
      </div>
    );
  }

  if (!item) return null;
  const side = item.variantId === "side-plank" ? (setIndex === 0 ? "gauche" : "droit") : null;
  const hasWorkTimer = item.mode === "time" || item.variantId === "row-benchmark-4";

  return (
    <div className="runner-shell">
      <header className="runner-topbar">
        <button className="icon-button" onClick={onClose} aria-label="Revenir au tableau de bord">
          <ArrowLeft size={19} />
        </button>
        <div className="runner-progress">
          <span style={{ width: `${Math.max(4, completion)}%` }} />
        </div>
        <span className="runner-progress-text">{completion} %</span>
      </header>

      <main className="runner-grid">
        <section className="runner-visual">
          <div className="exercise-count">
            {item.superset ? `Paire ${item.superset}` : "Mouvement seul"} · étape {sequenceIndex + 1}/{sequence.length}
          </div>
          <ExerciseFigure kind={item.art} label={exerciseName(item.exercise)} />
          <div className="visual-caption">
            <span>{item.equipment}</span>
            <span>{item.purpose}</span>
          </div>
        </section>

        <section className="runner-instructions">
          <div className="set-label">
            {side ? `Côté ${side} · ${setIndex + 1}/${item.sets}` : `Série ${setIndex + 1} sur ${item.sets}`}
          </div>
          <h1>{exerciseName(item.exercise)}</h1>
          <div className="target">{explainRir(item.target)}</div>
          <div className="prescription-line">
            <span>{explainRir(item.rirTarget)}</span>
            <span>{item.restBand}</span>
          </div>

          {item.loadOptions?.length ? (
            <div className="load-guidance">
              <div>
                <span>Charge conseillée</span>
                <strong>{item.recommendedLoadLabel}</strong>
              </div>
              <p>{item.loadReason}</p>
              <div className="load-options" role="group" aria-label={`Charge utilisée pour ${exerciseName(item.exercise)}`}>
                {item.loadOptions.map((option) => (
                  <button
                    type="button"
                    key={option.label}
                    className={loadLabel === option.label ? "active" : ""}
                    onClick={() => {
                      setLoadKg(option.totalKg);
                      setLoadLabel(option.label);
                    }}
                  >
                    {option.label}
                    <small>{option.label === item.recommendedLoadLabel ? "conseillé" : "autre palier"}</small>
                  </button>
                ))}
              </div>
              <p className="load-confirmation">Tu gardes la décision finale : sélectionne ici ce que tu utilises réellement.</p>
            </div>
          ) : null}

          {item.variantId === "row-benchmark-4" && (
            <div className="load-guidance rower-guidance">
              <div>
                <span>Réglage du rameur</span>
                <strong>Résistance {rowerResistance}</strong>
              </div>
              <p>Garde la même résistance que pendant l’échauffement : 4. Rame quatre minutes à un effort soutenu mais régulier, environ 6–7/10, puis recopie les mètres affichés.</p>
              <div className="compact-stepper" aria-label="Résistance du rameur">
                <button type="button" onClick={() => setRowerResistance((value) => Math.max(1, value - 1))}>−</button>
                <strong>{rowerResistance}</strong>
                <button type="button" onClick={() => setRowerResistance((value) => Math.min(10, value + 1))}>+</button>
              </div>
            </div>
          )}

          {hasWorkTimer && (
            <button
              className={`work-timer ${workTimerOn ? "active" : ""} ${workTimerFinished || timerGoalReached ? "finished" : ""}`}
              onClick={() => {
                if (item.mode === "time") {
                  setWorkTimerOn((running) => !running);
                } else if (workTimerFinished) {
                  setWorkTimer(240);
                  setWorkTimerFinished(false);
                  setWorkTimerOn(true);
                } else {
                  setWorkTimerOn((running) => !running);
                }
              }}
            >
              {workTimerOn ? <CirclePause size={21} /> : <CirclePlay size={21} />}
              <span>{formatSeconds(workTimer)}</span>
              <small>
                {item.mode === "time"
                  ? workTimerOn
                    ? side ? `côté ${side} · toucher pour arrêter` : "en cours · toucher pour arrêter"
                    : workTimer > 0
                      ? "en pause · toucher pour reprendre"
                      : side ? `lancer côté ${side} depuis 0` : "lancer depuis 0"
                  : workTimerFinished
                    ? "terminé · relancer"
                    : workTimerOn
                      ? "en cours"
                      : "lancer les 4 minutes"}
              </small>
            </button>
          )}

          {timerGoalReached && side && (
            <div className="timer-finished-note">
              <Check size={17} />
              {workTimer <= currentTimerRange.max
                ? `Minimum atteint côté ${side}. Tu peux terminer quand ta position commence à se dégrader.`
                : `Fourchette cible dépassée côté ${side}. Termine sans attendre la perte d’alignement.`}
            </div>
          )}

          {timerGoalReached && !side && item.mode === "time" && (
            <div className="timer-finished-note">
              <Check size={17} />
              {workTimer <= currentTimerRange.max
                ? `Minimum atteint. Tu peux continuer jusqu’à ${formatSeconds(currentTimerRange.max)}.`
                : "Fourchette cible atteinte. Tu peux arrêter le chronomètre."}
            </div>
          )}

          {workTimerFinished && item.variantId === "row-benchmark-4" && (
            <div className="timer-finished-note">
              <Check size={17} />
              Quatre minutes terminées : reporte maintenant les mètres affichés sur ton rameur.
            </div>
          )}

          <div className="cue-list">
            {item.cues.map((cue, index) => (
              <div key={cue}>
                <span>{index + 1}</span>
                <p>{cue}</p>
              </div>
            ))}
          </div>

          <div className="actual-entry">
            <div>
              <span>{item.variantId === "row-benchmark-4" ? "Distance affichée" : "Réalisé"}</span>
              <small>
                {item.mode === "reps" ? "répétitions" : item.mode === "distance" ? "mètres" : "secondes"}
              </small>
            </div>
            <div className="stepper">
              <button onClick={() => setActualValue((value) => Math.max(0, value - (item.mode === "distance" ? 10 : 1)))} aria-label="Réduire">
                <Minus size={18} />
              </button>
              <input
                type="number"
                min="0"
                value={actualValue}
                onChange={(event) => setActualValue(Math.max(0, Number(event.target.value)))}
              />
              <button onClick={() => setActualValue((value) => value + (item.mode === "distance" ? 10 : 1))} aria-label="Augmenter">
                <Plus size={18} />
              </button>
            </div>
          </div>

          {item.variantId === "row-benchmark-4" && (
            <div className="actual-entry secondary-entry">
              <div>
                <span>Coups de rame</span>
                <small>facultatif · ce ne sont pas les mètres</small>
              </div>
              <div className="stepper">
                <button onClick={() => setRowerStrokes((value) => Math.max(0, value - 1))} aria-label="Réduire les coups de rame">
                  <Minus size={18} />
                </button>
                <input
                  type="number"
                  min="0"
                  value={rowerStrokes}
                  onChange={(event) => setRowerStrokes(Math.max(0, Number(event.target.value)))}
                />
                <button onClick={() => setRowerStrokes((value) => value + 1)} aria-label="Augmenter les coups de rame">
                  <Plus size={18} />
                </button>
              </div>
            </div>
          )}

          {setIndex + 1 >= item.sets && item.mode === "reps" && (
            <div className="rir-entry">
              <div>
                <span>Répétitions encore possibles</span>
                <small>Seulement sur la dernière série · estimation rapide</small>
              </div>
              <div className="rir-options" role="group" aria-label="Répétitions en réserve">
                {[0, 1, 2, 3, 4].map((value) => (
                  <button
                    key={value}
                    className={lastSetRir === value ? "active" : ""}
                    onClick={() => setLastSetRir(value)}
                    type="button"
                  >
                    {value === 4 ? "4+" : value}
                  </button>
                ))}
              </div>
            </div>
          )}

          <button className="primary-button large" onClick={completeSet}>
            {side ? `Côté ${side} terminé` : item.variantId === "row-benchmark-4" ? "Enregistrer la distance" : "Série terminée"}
            <Check size={19} />
          </button>
          <div className="runner-secondary-actions">
            <button type="button" onClick={skipExercise}>
              <SkipForward size={17} />
              Exercice non réalisé
            </button>
            <button type="button" onClick={stopSessionHere}>
              <CircleStop size={17} />
              Arrêter la séance ici
            </button>
          </div>
          <p className="runner-hint">La technique décide de l’arrêt. Cible du jour&nbsp;: {explainRir(item.rirTarget)}.</p>
        </section>
      </main>

      {restSeconds > 0 && (
        <div className="rest-overlay" role="dialog" aria-modal="true" aria-label="Temps de récupération">
          <div className="rest-card">
            <div className="rest-preview">
              <ExerciseLoop kind={item.art} label={exerciseName(item.exercise)} />
              <div>
                <span>{side ? `Changement de côté` : "Mouvement suivant"}</span>
                <h2>{exerciseName(item.exercise)}</h2>
                <p>{side ? `Prépare le côté ${side}.` : `${item.target} · ${explainRir(item.rirTarget)}`}</p>
              </div>
            </div>
            <div className="rest-countdown">
              <div className="rest-icon"><TimerReset size={21} /></div>
              <div>
                <span>Récupération</span>
                <strong>{formatSeconds(restSeconds)}</strong>
              </div>
            </div>
            <div className="rest-actions">
              <button onClick={() => setRestPaused((paused) => !paused)}>
                {restPaused ? <CirclePlay size={17} /> : <CirclePause size={17} />}
                {restPaused ? "Reprendre" : "Pause"}
              </button>
              <button onClick={() => setRestSeconds(0)}>
                <SkipForward size={17} />
                Passer
              </button>
              <button onClick={() => setRestSeconds(side ? 15 : item.restSeconds)}>
                <RotateCcw size={17} />
                Refaire
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
