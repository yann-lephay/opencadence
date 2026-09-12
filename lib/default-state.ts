import type { CadenceState, Profile } from "./types";

export function defaultProfile(): Profile {
  return {
    name: "",
    goal: "Force générale et physique athlétique",
    experience: "Débutant",
    sessionMinutes: 40,
    heightCm: 170,
    weightKg: 70,
    limitations: "",
    equipment: [],
    otherEquipment: "",
    offerPublicContributions: false,
    surpriseWorkouts: false,
    pushupLevel: "none",
    pullupLevel: "none",
    physiologicalContext: "not-specified",
    trackMenstrualSymptoms: false,
    physicalBalance: {
      assessedAt: new Date().toISOString().slice(0, 10),
      strengths: [],
      priorities: [],
      unknowns: [
        "Niveau de force à calibrer pendant la première séance",
        "Tolérance des mouvements à confirmer en pratique",
      ],
    },
  };
}

export function defaultCadenceState(): CadenceState {
  return {
    version: 2,
    onboardingComplete: false,
    profile: defaultProfile(),
    queue: [],
    activeSession: null,
    history: [],
    dailyCheckIn: null,
  };
}
