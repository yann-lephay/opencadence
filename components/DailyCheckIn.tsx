"use client";

import { Check, LoaderCircle, X } from "lucide-react";
import { useState } from "react";
import type { DailyCheckIn as DailyCheckInValue } from "@/lib/types";

const symptomChoices = ["Crampes", "Fatigue", "Migraine", "Saignements inhabituels", "Autre gêne"];

type DailyCheckInProps = {
  onCancel: () => void;
  onSubmit: (checkIn: DailyCheckInValue) => Promise<void>;
};

export function DailyCheckIn({ onCancel, onSubmit }: DailyCheckInProps) {
  const [symptoms, setSymptoms] = useState(0);
  const [tags, setTags] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  function toggleTag(tag: string) {
    setTags((current) =>
      current.includes(tag) ? current.filter((entry) => entry !== tag) : [...current, tag],
    );
  }

  async function submit() {
    setSaving(true);
    try {
      await onSubmit({
        date: new Date().toISOString().slice(0, 10),
        menstrualSymptoms: symptoms,
        symptomTags: tags,
      });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="checkin-overlay" role="dialog" aria-modal="true" aria-labelledby="checkin-title">
      <section className="checkin-card">
        <button className="checkin-close" type="button" onClick={onCancel} aria-label="Fermer">
          <X size={19} />
        </button>
        <p className="eyebrow">Check-in facultatif</p>
        <h2 id="checkin-title">Comment sont tes symptômes aujourd’hui ?</h2>
        <p>On mesure ton ressenti, pas une phase supposée du cycle. Une bonne journée reste une journée normale.</p>

        <div className="symptom-scale" role="group" aria-label="Intensité des symptômes de 0 à 10">
          {Array.from({ length: 11 }, (_, value) => (
            <button
              type="button"
              key={value}
              className={symptoms === value ? "active" : ""}
              onClick={() => setSymptoms(value)}
            >
              {value}
            </button>
          ))}
        </div>
        <div className="scale-legend">
          <span>Aucun</span>
          <span>Important</span>
        </div>

        {symptoms > 0 && (
          <div className="symptom-tags">
            {symptomChoices.map((tag) => (
              <button
                type="button"
                key={tag}
                className={tags.includes(tag) ? "active" : ""}
                onClick={() => toggleTag(tag)}
              >
                {tags.includes(tag) ? <Check size={13} /> : null}
                {tag}
              </button>
            ))}
          </div>
        )}

        <div className="checkin-impact">
          {symptoms <= 2 && "Séance normale."}
          {symptoms >= 3 && symptoms <= 5 && "On commence normalement ; les premiers mouvements servent de test."}
          {symptoms >= 6 && "OpenCadence proposera une séance nettement réduite, sans rameur intense."}
        </div>

        <button className="primary-button large" type="button" onClick={submit} disabled={saving}>
          {saving ? <LoaderCircle className="spin" size={18} /> : <Check size={18} />}
          Continuer vers la séance
        </button>
      </section>
    </div>
  );
}
