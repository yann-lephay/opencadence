export type ExerciseMode = "reps" | "time" | "distance";
export type ExerciseArt =
  | "row"
  | "pullup"
  | "row-dumbbell"
  | "pushup"
  | "floor-press"
  | "lunge"
  | "squat"
  | "rdl"
  | "bridge"
  | "lateral"
  | "rear-delt"
  | "side-plank"
  | "dip";

export type LoadOption = {
  label: string;
  totalKg: number;
};
export type MovementPattern =
  | "warmup"
  | "pull"
  | "push"
  | "knee"
  | "hinge"
  | "shoulders"
  | "core"
  | "conditioning";

export type MuscleGroup =
  | "back"
  | "chest"
  | "quads"
  | "hamstrings"
  | "glutes"
  | "delts"
  | "core";

export type WorkoutItem = {
  id: string;
  exercise: string;
  art: ExerciseArt;
  variantId: string;
  pattern: MovementPattern;
  muscleCredits: Partial<Record<MuscleGroup, number>>;
  anchor: boolean;
  superset: string | null;
  mode: ExerciseMode;
  sets: number;
  target: string;
  targetValue: number;
  targetValues?: number[];
  restSeconds: number;
  restBand: string;
  rirTarget: string;
  hardRower?: boolean;
  equipment: string;
  purpose: string;
  cues: string[];
  loadOptions?: LoadOption[];
  recommendedLoadLabel?: string;
  recommendedLoadKg?: number;
  loadReason?: string;
};

export type Workout = {
  id: string;
  title: string;
  subtitle: string;
  kind: string;
  estimatedMinutes: number;
  intensity: string;
  focus: string[];
  coachNote: string;
  items: WorkoutItem[];
};

export type SetResult = {
  value: number;
  completedAt: string;
  rir?: number;
  loadKg?: number;
  loadLabel?: string;
  resistance?: number;
  strokeCount?: number;
  distanceUnknown?: boolean;
};

export type ActiveSession = {
  workout: Workout;
  startedAt: string;
  itemIndex: number;
  setIndex: number;
  progress: Record<string, SetResult[]>;
};

export type CompletedSession = {
  id: string;
  workout: Workout;
  startedAt: string;
  completedAt: string;
  durationMinutes: number;
  progress: Record<string, SetResult[]>;
  effort: number;
  pain: number;
  painLocation: string;
  hardRowingFinisher: boolean;
  note: string;
};

export type PhysiologicalContext =
  | "not-specified"
  | "cycle-natural"
  | "hormonal-contraception"
  | "pregnancy"
  | "postpartum"
  | "perimenopause"
  | "postmenopause";

export type Profile = {
  name: string;
  goal: string;
  experience: string;
  sessionMinutes: number;
  heightCm: number;
  weightKg: number;
  limitations: string;
  equipment: string[];
  otherEquipment?: string;
  offerPublicContributions?: boolean;
  pushupLevel?: "none" | "one-to-five" | "six-plus";
  pullupLevel?: "none" | "one-to-three" | "four-plus";
  physiologicalContext?: PhysiologicalContext;
  trackMenstrualSymptoms?: boolean;
  physicalBalance: {
    assessedAt: string;
    strengths: string[];
    priorities: string[];
    unknowns: string[];
  };
};

export type DailyCheckIn = {
  date: string;
  menstrualSymptoms: number;
  symptomTags: string[];
};

export type CadenceState = {
  version: number;
  onboardingComplete: boolean;
  profile: Profile;
  queue: Workout[];
  activeSession: ActiveSession | null;
  history: CompletedSession[];
  dailyCheckIn?: DailyCheckIn | null;
};

export type StateAction =
  | { action: "startSession" }
  | { action: "completeOnboarding"; profile: Profile }
  | { action: "saveDailyCheckIn"; checkIn: DailyCheckIn }
  | {
      action: "saveProgress";
      itemIndex: number;
      setIndex: number;
      progress: Record<string, SetResult[]>;
    }
  | {
      action: "completeSession";
      effort: number;
      pain: number;
      painLocation: string;
      hardRowingFinisher: boolean;
      note: string;
      progress: Record<string, SetResult[]>;
    }
  | { action: "updateProfile"; profile: Partial<Profile> }
  | { action: "abandonSession" };
