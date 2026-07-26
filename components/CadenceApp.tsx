"use client";

import {
  Activity,
  ArrowRight,
  CalendarDays,
  CheckCircle2,
  Clock3,
  Coffee,
  Dumbbell,
  Gauge,
  GitPullRequest,
  History,
  Home,
  LoaderCircle,
  Play,
  Ruler,
  Scale,
  Settings2,
  Sparkles,
  Target,
  Timer,
  TriangleAlert,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { equipmentChoices } from "@/lib/equipment";
import type { CadenceState, Profile } from "@/lib/types";
import { calculateRollingCredits, getNextSessionRecommendation } from "@/lib/workouts";
import { DailyCheckIn } from "./DailyCheckIn";
import { Onboarding } from "./Onboarding";
import { WorkoutRunner } from "./WorkoutRunner";

type View = "home" | "history" | "profile";
const supportUrl =
  process.env.NEXT_PUBLIC_SUPPORT_URL?.trim() ||
  "https://buy.stripe.com/00w00jeYH06O8si4662VG0c";

async function patchState(payload: unknown) {
  const response = await fetch("/api/state", {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Action impossible");
  return response.json() as Promise<CadenceState>;
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "short",
    day: "numeric",
    month: "short",
  }).format(new Date(value));
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

function Navigation({ view, setView }: { view: View; setView: (view: View) => void }) {
  const entries = [
    { id: "home" as const, label: "Aujourd’hui", icon: Home },
    { id: "history" as const, label: "Historique", icon: History },
    { id: "profile" as const, label: "Profil", icon: Settings2 },
  ];
  return (
    <nav className="app-nav" aria-label="Navigation principale">
      <div className="brand-lockup">
        <span className="brand-mark">O</span>
        <div>
          <strong>OpenCadence</strong>
          <small>entraînement adaptatif</small>
        </div>
      </div>
      <div className="nav-links">
        {entries.map((entry) => {
          const Icon = entry.icon;
          return (
            <button
              key={entry.id}
              className={view === entry.id ? "active" : ""}
              onClick={() => setView(entry.id)}
            >
              <Icon size={18} />
              <span>{entry.label}</span>
            </button>
          );
        })}
      </div>
      <div className="nav-footer">
        <a href={supportUrl} target="_blank" rel="noreferrer">
          <Coffee size={16} />
          <span>Offrir un café</span>
        </a>
        <div className="nav-status">
          <span className="status-dot" />
          Données locales
        </div>
      </div>
    </nav>
  );
}

function Dashboard({
  state,
  startSession,
  starting,
}: {
  state: CadenceState;
  startSession: () => void;
  starting: boolean;
}) {
  const [showLoadAnalysis, setShowLoadAnalysis] = useState(false);
  const next = state.queue[0];
  const sessions14Days = state.history.filter(
    (session) => Date.now() - new Date(session.completedAt).getTime() < 14 * 86400000
  ).length;
  const last = state.history[0];
  const credits7 = calculateRollingCredits(state.history, 7);
  const sessionRecommendation = getNextSessionRecommendation(state.history);
  const loadRecommendations = next.items.filter((item) => item.recommendedLoadLabel);
  const dedicatedLifeStage =
    state.profile.physiologicalContext === "pregnancy" ||
    state.profile.physiologicalContext === "postpartum";

  return (
    <div className="page dashboard">
      <header className="page-heading">
        <div>
          <p className="eyebrow">Ta prochaine séance</p>
          <h1>On s’adapte à ta vraie semaine.</h1>
        </div>
        <div className="date-chip">
          <CalendarDays size={16} />
          {new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date())}
        </div>
      </header>

      {state.profile.limitations === "" && state.history.length === 0 && (
        <div className="profile-nudge">
          <TriangleAlert size={17} />
          <span>Avant la première séance, ajoute dans Profil toute blessure, douleur ou contre-indication connue.</span>
        </div>
      )}

      <section className="hero-workout">
        <img src="/assets/opencadence-training.png" alt="" className="hero-art" />
        <div className="hero-copy">
          <div className="next-session-guide">
            <span className="icon-tile"><CalendarDays size={18} /></span>
            <div>
              <small>Prochaine séance conseillée</small>
              <strong>{sessionRecommendation.relativeLabel}</strong>
              <span>{sessionRecommendation.dateLabel}</span>
            </div>
            <p>{sessionRecommendation.reason}</p>
          </div>
          <div className="workout-meta">
            <span>{next.kind}</span>
            <span><Clock3 size={14} /> {next.estimatedMinutes} min</span>
            <span><Gauge size={14} /> {next.intensity}</span>
          </div>
          <h2>{next.title}</h2>
          <p>{next.subtitle}</p>
          <div className="focus-pills">
            {next.focus.map((focus) => <span key={focus}>{focus}</span>)}
          </div>
          <button className="primary-button hero-button" onClick={startSession} disabled={starting || dedicatedLifeStage}>
            {starting ? <LoaderCircle className="spin" size={19} /> : <Play size={18} fill="currentColor" />}
            {dedicatedLifeStage
              ? "Mode dédié nécessaire"
              : state.activeSession
                ? "Reprendre la séance"
                : "Lancer la séance"}
            <ArrowRight size={18} />
          </button>
          {dedicatedLifeStage && (
            <p className="life-stage-warning">
              Grossesse et post-partum nécessitent un accompagnement et un mode spécifiques que cette version ne prétend pas remplacer.
            </p>
          )}
        </div>
      </section>

      <section className="dashboard-grid">
        <article className="coach-card">
          <div className="card-title">
            <span className="icon-tile"><Sparkles size={18} /></span>
            <div>
              <small>Note du coach</small>
              <h3>Le cap du jour</h3>
            </div>
          </div>
          <blockquote>{next.coachNote}</blockquote>
          <div className="coach-rule">
            <span>Règle simple</span>
            <p>La technique décide de la fin de la série, pas l’ego.</p>
          </div>
          {loadRecommendations.length > 0 && (
            <div className="load-analysis">
              <button type="button" onClick={() => setShowLoadAnalysis((visible) => !visible)}>
                <Target size={16} />
                {showLoadAnalysis ? "Masquer l’analyse des charges" : "Analyser les charges proposées"}
              </button>
              {showLoadAnalysis && (
                <div className="load-analysis-results">
                  <p>Le moteur utilise une double progression prudente : deux séances au haut de la fourchette avant de proposer le palier suivant. Tu confirmes toujours la charge réelle.</p>
                  {loadRecommendations.map((item) => (
                    <div key={item.id}>
                      <span>{exerciseName(item.exercise)}</span>
                      <strong>{item.recommendedLoadLabel}</strong>
                      <small>{item.loadReason}</small>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </article>

        <article className="stats-card">
          <div className="card-title">
            <span className="icon-tile dark"><Activity size={18} /></span>
            <div>
              <small>Rythme réel</small>
              <h3>14 derniers jours</h3>
            </div>
          </div>
          <div className="big-stat">
            <strong>{sessions14Days}</strong>
            <span>séance{sessions14Days > 1 ? "s" : ""}</span>
          </div>
          <div className="stat-strip">
            <div>
              <span>Dernier effort</span>
              <strong>{last ? `${last.effort}/10` : "—"}</strong>
            </div>
            <div>
              <span>Temps cumulé</span>
              <strong>{state.history.reduce((sum, session) => sum + session.durationMinutes, 0)} min</strong>
            </div>
          </div>
          <div className="exposure-strip">
            <span>Crédits sur 7 jours</span>
            <div>
              <small>Dos <strong>{credits7.back}</strong></small>
              <small>Épaules <strong>{credits7.delts}</strong></small>
              <small>Cuisses <strong>{credits7.quads}</strong></small>
              <small>Charnière <strong>{Math.max(credits7.hamstrings, credits7.glutes)}</strong></small>
            </div>
          </div>
        </article>
      </section>

      <section className="session-preview">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Déroulé</p>
            <h2>{next.items.length} mouvements, guidés un par un</h2>
          </div>
          <span><Timer size={16} /> Repos automatique</span>
        </div>
        <div className="preview-list">
          {next.items.map((item, index) => (
            <div key={item.id} className="preview-row">
              <span className="preview-index">{item.superset ?? String(index + 1).padStart(2, "0")}</span>
              <div>
                <strong>{exerciseName(item.exercise)}</strong>
                <small>{item.purpose}{item.superset ? ` · paire ${item.superset}` : ""}</small>
              </div>
              <span className="preview-target">
                {item.sets} × {explainRir(item.target)}
                <small>{explainRir(item.rirTarget)}</small>
              </span>
              <span className="preview-equipment">
                {item.recommendedLoadLabel ?? item.equipment}
                {item.recommendedLoadLabel && <small>charge conseillée</small>}
              </span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function HistoryPage({ state }: { state: CadenceState }) {
  return (
    <div className="page">
      <header className="page-heading compact">
        <div>
          <p className="eyebrow">Journal d’entraînement</p>
          <h1>Ce que tu as vraiment fait.</h1>
        </div>
        <div className="history-total">{state.history.length} séance{state.history.length > 1 ? "s" : ""}</div>
      </header>

      {state.history.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon"><History size={28} /></span>
          <h2>Le journal attend ta première séance.</h2>
          <p>Les répétitions, durées, mètres, effort et notes apparaîtront ici automatiquement.</p>
        </div>
      ) : (
        <div className="history-list">
          {state.history.map((session) => (
            <article key={session.id} className="history-card">
              <div className="history-date">
                <strong>{new Date(session.completedAt).getDate()}</strong>
                <span>{new Intl.DateTimeFormat("fr-FR", { month: "short" }).format(new Date(session.completedAt))}</span>
              </div>
              <div className="history-main">
                <span>{formatDate(session.completedAt)} · {session.workout.kind}</span>
                <h2>{session.workout.title}</h2>
                <div className="history-tags">
                  <span><Clock3 size={14} /> {session.durationMinutes} min</span>
                  <span><Gauge size={14} /> effort {session.effort}/10</span>
                  <span className={session.pain >= 3 ? "pain" : ""}>gêne {session.pain}/10</span>
                </div>
                {session.painLocation && <p className="pain-location">Zone : {session.painLocation}</p>}
                {session.note && <blockquote>“{session.note}”</blockquote>}
              </div>
              <div className="history-results">
                {session.workout.items.map((item) => {
                  const results = session.progress[item.id] ?? [];
                  const values = results.map((set) => set.value);
                  const formattedValues = values.map((value) => {
                    if (item.mode !== "time") return String(value);
                    if (value >= 60 && value % 60 === 0) return `${value / 60} min`;
                    return `${value} s`;
                  });
                  const lastResult = results.at(-1);
                  const rir = lastResult?.rir;
                  const load = lastResult?.loadLabel;
                  const rowerResult =
                    item.variantId === "row-benchmark-4" && lastResult
                      ? lastResult.distanceUnknown
                        ? `${lastResult.strokeCount ?? "—"} coups de rame · résistance ${lastResult.resistance ?? "—"} · distance non relevée`
                        : `${lastResult.value} m · résistance ${lastResult.resistance ?? "—"}`
                      : null;
                  return (
                    <div key={item.id}>
                      <span>{exerciseName(item.exercise)}</span>
                      <strong>
                        {rowerResult ?? (formattedValues.length ? formattedValues.join(" · ") : "—")}
                        {rir !== undefined ? ` · ${rir === 4 ? "4+" : rir} reps en réserve` : ""}
                        {load ? ` · ${load}` : ""}
                      </strong>
                    </div>
                  );
                })}
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

function ProfilePage({ state, onState }: { state: CadenceState; onState: (state: CadenceState) => void }) {
  const [form, setForm] = useState<Profile>(state.profile);
  const [saved, setSaved] = useState(false);

  function toggleEquipment(item: string) {
    setForm((current) => ({
      ...current,
      equipment: current.equipment.includes(item)
        ? current.equipment.filter((entry) => entry !== item)
        : [...current.equipment, item],
    }));
  }

  async function saveProfile() {
    const nextState = await patchState({ action: "updateProfile", profile: form });
    onState(nextState);
    setSaved(true);
    window.setTimeout(() => setSaved(false), 1800);
  }

  return (
    <div className="page">
      <header className="page-heading compact">
        <div>
          <p className="eyebrow">Réglages utiles</p>
          <h1>Ton contexte, sans questionnaire interminable.</h1>
        </div>
      </header>

      <div className="profile-layout">
        <section className="profile-form">
          <div className="form-grid">
            <label>
              <span>Prénom</span>
              <input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} />
            </label>
            <label>
              <span>Durée cible</span>
              <select value={form.sessionMinutes} onChange={(event) => setForm({ ...form, sessionMinutes: Number(event.target.value) })}>
                <option value="30">30 minutes</option>
                <option value="35">35 minutes</option>
                <option value="40">40 minutes</option>
                <option value="45">45 minutes</option>
              </select>
            </label>
          </div>
          <div className="form-grid">
            <label>
              <span>Taille</span>
              <div className="input-with-unit">
                <input
                  type="number"
                  min="120"
                  max="230"
                  value={form.heightCm}
                  onChange={(event) => setForm({ ...form, heightCm: Number(event.target.value) })}
                />
                <span>cm</span>
              </div>
            </label>
            <label>
              <span>Poids actuel</span>
              <div className="input-with-unit">
                <input
                  type="number"
                  min="35"
                  max="250"
                  step="0.1"
                  value={form.weightKg}
                  onChange={(event) => setForm({ ...form, weightKg: Number(event.target.value) })}
                />
                <span>kg</span>
              </div>
            </label>
          </div>
          <label>
            <span>Objectif principal</span>
            <input value={form.goal} onChange={(event) => setForm({ ...form, goal: event.target.value })} />
          </label>
          <label>
            <span>Expérience actuelle</span>
            <select value={form.experience} onChange={(event) => setForm({ ...form, experience: event.target.value })}>
              <option>À jauger</option>
              <option>Débutant</option>
              <option>Intermédiaire</option>
              <option>Avancé</option>
            </select>
          </label>
          <label>
            <span>Blessures, douleurs ou mouvements à éviter</span>
            <textarea
              value={form.limitations}
              onChange={(event) => setForm({ ...form, limitations: event.target.value })}
              placeholder="Ex. ancienne gêne à l’épaule droite, genou sensible… Écris “aucune” si tout va bien."
              rows={4}
            />
          </label>
          <fieldset className="profile-equipment-editor">
            <legend>Matériel disponible</legend>
            <div className="equipment-choices">
              {equipmentChoices.map((item) => (
                <button
                  type="button"
                  key={item}
                  className={form.equipment.includes(item) ? "active" : ""}
                  onClick={() => toggleEquipment(item)}
                >
                  <span>{form.equipment.includes(item) ? <CheckCircle2 size={14} /> : null}</span>
                  {item}
                </button>
              ))}
            </div>
            <label>
              <span>Autre matériel, charges exactes ou contrainte d’espace</span>
              <textarea
                value={form.otherEquipment ?? ""}
                onChange={(event) => setForm({ ...form, otherEquipment: event.target.value })}
                placeholder="Ex. élastique fort, une kettlebell de 12 kg, pas de plafond haut…"
                rows={3}
              />
            </label>
            <p>Le moteur ne doit proposer que les mouvements compatibles avec ce qui est renseigné.</p>
          </fieldset>
          <div className="form-grid">
            <label>
              <span>Contexte physiologique facultatif</span>
              <select
                value={form.physiologicalContext ?? "not-specified"}
                onChange={(event) =>
                  setForm({
                    ...form,
                    physiologicalContext: event.target.value as Profile["physiologicalContext"],
                  })
                }
              >
                <option value="not-specified">Non renseigné / non concerné</option>
                <option value="cycle-natural">Cycle naturel</option>
                <option value="hormonal-contraception">Contraception hormonale</option>
                <option value="pregnancy">Grossesse</option>
                <option value="postpartum">Post-partum</option>
                <option value="perimenopause">Périménopause</option>
                <option value="postmenopause">Postménopause</option>
              </select>
            </label>
            <label className="tracking-choice compact">
              <input
                type="checkbox"
                checked={form.trackMenstrualSymptoms ?? false}
                onChange={(event) => setForm({ ...form, trackMenstrualSymptoms: event.target.checked })}
              />
              <span>
                <strong>Check-in symptômes</strong>
                <small>Avant chaque séance, facultatif.</small>
              </span>
            </label>
          </div>
          <label className="tracking-choice contribution-choice">
            <input
              type="checkbox"
              checked={form.offerPublicContributions ?? false}
              onChange={(event) => setForm({ ...form, offerPublicContributions: event.target.checked })}
            />
            <GitPullRequest size={19} />
            <span>
              <strong>Me proposer une contribution publique</strong>
              <small>Codex pourra suggérer une PR pour une amélioration réutilisable, mais devra montrer son contenu et redemander ton accord avant publication.</small>
            </span>
          </label>
          <button className="primary-button" onClick={saveProfile}>
            {saved ? <CheckCircle2 size={18} /> : <Settings2 size={18} />}
            {saved ? "Enregistré" : "Enregistrer le profil"}
          </button>
        </section>

        <div className="profile-sidebar">
          <aside className="balance-card">
            <div className="card-title">
              <span className="icon-tile"><Target size={18} /></span>
              <div>
                <small>Lecture actuelle</small>
                <h3>Équilibre physique</h3>
              </div>
            </div>
            <div className="body-metrics">
              <span><Ruler size={15} /><strong>{form.heightCm}</strong> cm</span>
              <span><Scale size={15} /><strong>{form.weightKg}</strong> kg</span>
            </div>
            <div className="balance-section">
              <small>Points déjà présents</small>
              <ul>
                {form.physicalBalance.strengths.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </div>
            <div className="balance-section priority">
              <small>Priorités provisoires</small>
              <ul>
                {form.physicalBalance.priorities.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </div>
            <p>Lecture visuelle du {new Intl.DateTimeFormat("fr-FR").format(new Date(form.physicalBalance.assessedAt))}. Les performances de la séance diagnostic restent prioritaires.</p>
          </aside>

          <aside className="equipment-card">
            <div className="card-title">
              <span className="icon-tile dark"><Dumbbell size={18} /></span>
              <div>
                <small>Déjà pris en compte</small>
                <h3>Ton matériel</h3>
              </div>
            </div>
            <ul>
              {form.equipment.map((item) => <li key={item}><CheckCircle2 size={16} /> {item}</li>)}
            </ul>
            {form.otherEquipment ? <p className="equipment-freeform">{form.otherEquipment}</p> : null}
            <p>Le moteur privilégie les charges déjà montées pour éviter les changements de disques en plein entraînement.</p>
          </aside>
        </div>
      </div>
    </div>
  );
}

export function CadenceApp() {
  const [state, setState] = useState<CadenceState | null>(null);
  const [view, setView] = useState<View>("home");
  const [runnerOpen, setRunnerOpen] = useState(false);
  const [starting, setStarting] = useState(false);
  const [checkInOpen, setCheckInOpen] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch("/api/state", { cache: "no-store" })
      .then((response) => response.json())
      .then((data: CadenceState) => {
        setState(data);
        if (data.activeSession) setRunnerOpen(true);
      })
      .catch(() => setError("OpenCadence n’arrive pas à lire le journal local."));
  }, []);

  const greeting = useMemo(() => {
    const hour = new Date().getHours();
    if (hour < 12) return "Bonjour";
    if (hour < 18) return "Bon après-midi";
    return "Bonsoir";
  }, []);

  async function launchSession() {
    if (!state) return;
    setStarting(true);
    try {
      const nextState = await patchState({ action: "startSession" });
      setState(nextState);
      setRunnerOpen(true);
    } catch {
      setError("Impossible de démarrer la séance.");
    } finally {
      setStarting(false);
    }
  }

  async function completeOnboarding(profile: Profile) {
    const nextState = await patchState({ action: "completeOnboarding", profile });
    setState(nextState);
  }

  async function startSession() {
    if (!state) return;
    if (state.activeSession) {
      setRunnerOpen(true);
      return;
    }
    const today = new Date().toISOString().slice(0, 10);
    const hasFreshCheckIn = state.dailyCheckIn?.date === today;
    if (state.profile.trackMenstrualSymptoms && !hasFreshCheckIn) {
      setCheckInOpen(true);
      return;
    }
    await launchSession();
  }

  async function submitCheckIn(checkIn: NonNullable<CadenceState["dailyCheckIn"]>) {
    const checkedState = await patchState({ action: "saveDailyCheckIn", checkIn });
    setState(checkedState);
    setCheckInOpen(false);
    setStarting(true);
    try {
      const nextState = await patchState({ action: "startSession" });
      setState(nextState);
      setRunnerOpen(true);
    } finally {
      setStarting(false);
    }
  }

  if (error) {
    return <div className="fatal-error"><TriangleAlert size={24} /><p>{error}</p></div>;
  }

  if (!state) {
    return (
      <div className="loading-screen">
        <span className="brand-mark">O</span>
        <LoaderCircle className="spin" size={22} />
      </div>
    );
  }

  if (!state.onboardingComplete) {
    return <Onboarding onComplete={completeOnboarding} />;
  }

  if (runnerOpen && state.activeSession) {
    return (
      <WorkoutRunner
        session={state.activeSession}
        onState={setState}
        onClose={() => setRunnerOpen(false)}
      />
    );
  }

  return (
    <>
      <div className="app-shell">
        <Navigation view={view} setView={setView} />
        <main className="app-content">
          <div className="mobile-brand">
            <span className="brand-mark small">O</span>
            <strong>OpenCadence</strong>
            <span>{greeting}, {state.profile.name}</span>
          </div>
          {view === "home" && <Dashboard state={state} startSession={startSession} starting={starting} />}
          {view === "history" && <HistoryPage state={state} />}
          {view === "profile" && <ProfilePage state={state} onState={setState} />}
        </main>
      </div>
      {checkInOpen && (
        <DailyCheckIn onCancel={() => setCheckInOpen(false)} onSubmit={submitCheckIn} />
      )}
    </>
  );
}
