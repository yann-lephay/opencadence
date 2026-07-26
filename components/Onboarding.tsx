"use client";

import {
  ArrowLeft,
  ArrowRight,
  Check,
  Dumbbell,
  HeartPulse,
  GitPullRequest,
  LoaderCircle,
  Timer,
} from "lucide-react";
import { useState } from "react";
import { defaultProfile } from "@/lib/default-state";
import { equipmentChoices, originalEquipmentChoices } from "@/lib/equipment";
import type { PhysiologicalContext, Profile } from "@/lib/types";

const physiologicalOptions: { value: PhysiologicalContext; label: string }[] = [
  { value: "not-specified", label: "Non renseigné / non concerné" },
  { value: "cycle-natural", label: "Cycle naturel" },
  { value: "hormonal-contraception", label: "Contraception hormonale" },
  { value: "pregnancy", label: "Grossesse" },
  { value: "postpartum", label: "Post-partum" },
  { value: "perimenopause", label: "Périménopause" },
  { value: "postmenopause", label: "Postménopause" },
];

type OnboardingProps = {
  onComplete: (profile: Profile) => Promise<void>;
};

export function Onboarding({ onComplete }: OnboardingProps) {
  const [step, setStep] = useState(1);
  const [saving, setSaving] = useState(false);
  const [profile, setProfile] = useState<Profile>(defaultProfile());
  const dedicatedMode =
    profile.physiologicalContext === "pregnancy" ||
    profile.physiologicalContext === "postpartum";
  const canTrackSymptoms = [
    "cycle-natural",
    "hormonal-contraception",
    "perimenopause",
  ].includes(profile.physiologicalContext ?? "");

  function toggleEquipment(item: string) {
    setProfile((current) => ({
      ...current,
      equipment: current.equipment.includes(item)
        ? current.equipment.filter((entry) => entry !== item)
        : [...current.equipment, item],
    }));
  }

  async function finish() {
    setSaving(true);
    try {
      await onComplete(profile);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="onboarding-shell">
      <section className="onboarding-intro">
        <span className="brand-mark">O</span>
        <p className="eyebrow">Bienvenue dans OpenCadence</p>
        <h1>Quelques repères.<br />Puis on bouge.</h1>
        <p>Trois étapes courtes suffisent. Le programme apprendra ensuite de tes séances réelles.</p>
        <div className="onboarding-principle">
          <HeartPulse size={19} />
          <span>Même moteur pour tout le monde. Variantes, charges et récupération suivent tes performances — jamais un stéréotype.</span>
        </div>
      </section>

      <section className="onboarding-card">
        <div className="onboarding-progress" aria-label={`Étape ${step} sur 3`}>
          {[1, 2, 3].map((entry) => (
            <span key={entry} className={entry <= step ? "active" : ""} />
          ))}
        </div>

        {step === 1 && (
          <div className="onboarding-step">
            <span className="step-kicker"><Timer size={16} /> 1 · Ton cadre</span>
            <h2>Comment veux-tu commencer ?</h2>
            <label>
              <span>Ton prénom</span>
              <input
                autoFocus
                value={profile.name}
                placeholder="Camille"
                onChange={(event) => setProfile({ ...profile, name: event.target.value })}
              />
            </label>
            <label>
              <span>Durée maximale d’une séance</span>
              <div className="choice-row">
                {[30, 35, 40, 45].map((minutes) => (
                  <button
                    type="button"
                    key={minutes}
                    className={profile.sessionMinutes === minutes ? "active" : ""}
                    onClick={() => setProfile({ ...profile, sessionMinutes: minutes })}
                  >
                    {minutes} min
                  </button>
                ))}
              </div>
            </label>
          </div>
        )}

        {step === 2 && (
          <div className="onboarding-step">
            <span className="step-kicker"><Dumbbell size={16} /> 2 · Ton point de départ</span>
            <h2>Ce que tu peux faire aujourd’hui.</h2>
            <fieldset>
              <legend>Pompes propres au sol</legend>
              <div className="choice-row three">
                {[
                  ["none", "Aucune"],
                  ["one-to-five", "1 à 5"],
                  ["six-plus", "6 ou plus"],
                ].map(([value, label]) => (
                  <button
                    type="button"
                    key={value}
                    className={profile.pushupLevel === value ? "active" : ""}
                    onClick={() => setProfile({ ...profile, pushupLevel: value as Profile["pushupLevel"] })}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </fieldset>
            <fieldset>
              <legend>Tractions strictes sans élan</legend>
              <div className="choice-row three">
                {[
                  ["none", "Aucune"],
                  ["one-to-three", "1 à 3"],
                  ["four-plus", "4 ou plus"],
                ].map(([value, label]) => (
                  <button
                    type="button"
                    key={value}
                    className={profile.pullupLevel === value ? "active" : ""}
                    onClick={() => setProfile({ ...profile, pullupLevel: value as Profile["pullupLevel"] })}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </fieldset>
            <p className="onboarding-note">Ces réponses choisissent seulement la variante du diagnostic. Elles ne définissent pas ton « niveau général ».</p>
          </div>
        )}

        {step === 3 && (
          <div className="onboarding-step">
            <span className="step-kicker"><Check size={16} /> 3 · Matériel et sécurité</span>
            <h2>Ce qu’OpenCadence peut utiliser.</h2>
            <div className="equipment-quick-action">
              <button type="button" onClick={() => setProfile({ ...profile, equipment: [...originalEquipmentChoices] })}>
                J’ai la configuration OpenCadence d’origine
              </button>
              <span>{profile.equipment.length} sélectionné{profile.equipment.length > 1 ? "s" : ""}</span>
            </div>
            <div className="equipment-choices">
              {equipmentChoices.map((item) => (
                <button
                  type="button"
                  key={item}
                  className={profile.equipment.includes(item) ? "active" : ""}
                  onClick={() => toggleEquipment(item)}
                >
                  <span>{profile.equipment.includes(item) ? <Check size={14} /> : null}</span>
                  {item}
                </button>
              ))}
            </div>
            <label>
              <span>Autre matériel, poids exacts ou contrainte d’espace</span>
              <input
                value={profile.otherEquipment ?? ""}
                placeholder="Ex. deux kettlebells de 12 kg, plafond bas…"
                onChange={(event) => setProfile({ ...profile, otherEquipment: event.target.value })}
              />
              <small className="field-help">OpenCadence n’inventera pas un exercice incompatible. Codex pourra proposer une variante illustrée si ce matériel n’est pas encore couvert.</small>
            </label>
            <label>
              <span>Blessure, douleur ou contre-indication connue</span>
              <input
                value={profile.limitations}
                placeholder="Aucune, ou quelques mots"
                onChange={(event) => setProfile({ ...profile, limitations: event.target.value })}
              />
            </label>
            <label>
              <span>Contexte physiologique facultatif</span>
              <select
                value={profile.physiologicalContext}
                onChange={(event) => {
                  const physiologicalContext = event.target.value as PhysiologicalContext;
                  setProfile({
                    ...profile,
                    physiologicalContext,
                    trackMenstrualSymptoms: [
                      "cycle-natural",
                      "hormonal-contraception",
                      "perimenopause",
                    ].includes(physiologicalContext)
                      ? profile.trackMenstrualSymptoms
                      : false,
                  });
                }}
              >
                {physiologicalOptions.map((option) => (
                  <option value={option.value} key={option.value}>{option.label}</option>
                ))}
              </select>
            </label>
            {canTrackSymptoms && (
              <label className="tracking-choice">
                <input
                  type="checkbox"
                  checked={profile.trackMenstrualSymptoms}
                  onChange={(event) => setProfile({ ...profile, trackMenstrualSymptoms: event.target.checked })}
                />
                <span>
                  <strong>Proposer un check-in de symptômes avant la séance</strong>
                  <small>La phase du cycle ne change jamais automatiquement le programme.</small>
                </span>
              </label>
            )}
            {dedicatedMode && (
              <div className="dedicated-mode-note">
                OpenCadence standard ne couvre pas encore correctement la grossesse ou le post-partum. Le profil sera enregistré, mais le démarrage des séances restera désactivé.
              </div>
            )}
            <label className="tracking-choice contribution-choice">
              <input
                type="checkbox"
                checked={profile.offerPublicContributions ?? false}
                onChange={(event) => setProfile({ ...profile, offerPublicContributions: event.target.checked })}
              />
              <GitPullRequest size={19} />
              <span>
                <strong>Me proposer de partager les améliorations utiles</strong>
                <small>Cela autorise seulement la proposition. Chaque PR demandera encore ton accord, après aperçu, sans profil ni historique.</small>
              </span>
            </label>
          </div>
        )}

        <footer className="onboarding-actions">
          {step > 1 ? (
            <button type="button" className="secondary-button" onClick={() => setStep((current) => current - 1)}>
              <ArrowLeft size={17} /> Retour
            </button>
          ) : <span />}
          {step < 3 ? (
            <button
              type="button"
              className="primary-button"
              disabled={step === 1 && profile.name.trim().length < 2}
              onClick={() => setStep((current) => current + 1)}
            >
              Continuer <ArrowRight size={17} />
            </button>
          ) : (
            <button type="button" className="primary-button" disabled={saving} onClick={finish}>
              {saving ? <LoaderCircle className="spin" size={17} /> : <Check size={17} />}
              Préparer ma première séance
            </button>
          )}
        </footer>
      </section>
    </main>
  );
}
