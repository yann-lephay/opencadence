import { NextResponse } from "next/server";
import { buildDiagnosticWorkout, buildNextWorkout } from "@/lib/workouts";
import { readState, writeState } from "@/lib/store";
import type { CompletedSession, StateAction } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const state = await readState();
  if (!state.activeSession && state.history.length > 0 && state.queue[0]?.kind !== "Diagnostic") {
    state.queue[0] = buildNextWorkout(state);
  }
  return NextResponse.json(state);
}

export async function PATCH(request: Request) {
  const payload = (await request.json()) as StateAction;
  const state = await readState();

  if (payload.action === "completeOnboarding") {
    state.profile = payload.profile;
    state.queue = [buildDiagnosticWorkout(payload.profile)];
    state.activeSession = null;
    state.history = [];
    state.dailyCheckIn = null;
    state.onboardingComplete = true;
  }

  if (payload.action === "saveDailyCheckIn") {
    state.dailyCheckIn = payload.checkIn;
    if (!state.activeSession && state.history.length === 0) {
      const diagnostic = buildDiagnosticWorkout(state.profile);
      if (payload.checkIn.menstrualSymptoms >= 6) {
        diagnostic.items = diagnostic.items
          .filter((item) => item.variantId !== "row-benchmark-4")
          .map((item) => ({
            ...item,
            sets: 1,
            targetValues: [item.targetValue],
          }));
        diagnostic.intensity = "Légère";
        diagnostic.coachNote =
          "Symptômes importants aujourd’hui : diagnostic raccourci, aucune recherche de performance. Tu peux aussi reporter la séance.";
      } else if (payload.checkIn.menstrualSymptoms >= 3) {
        diagnostic.coachNote =
          "Symptômes modérés : commence doucement et utilise les deux premiers mouvements comme test. Arrête ou reporte si l’effort paraît anormalement élevé.";
      }
      state.queue = [diagnostic];
    } else if (!state.activeSession) {
      state.queue[0] = buildNextWorkout(state);
    }
  }

  if (payload.action === "startSession") {
    if (
      state.profile.physiologicalContext === "pregnancy" ||
      state.profile.physiologicalContext === "postpartum"
    ) {
      return NextResponse.json(
        { error: "Le mode grossesse ou post-partum nécessite un accompagnement dédié." },
        { status: 409 },
      );
    }
    if (!state.activeSession && state.history.length > 0 && state.queue[0]?.kind !== "Diagnostic") {
      state.queue[0] = buildNextWorkout(state);
    }
    if (!state.activeSession && state.queue[0]) {
      state.activeSession = {
        workout: state.queue[0],
        startedAt: new Date().toISOString(),
        itemIndex: 0,
        setIndex: 0,
        progress: {}
      };
    }
  }

  if (payload.action === "saveProgress" && state.activeSession) {
    state.activeSession.progress = payload.progress;
    state.activeSession.itemIndex = payload.itemIndex;
    state.activeSession.setIndex = payload.setIndex;
  }

  if (payload.action === "completeSession" && state.activeSession) {
    const completedAt = new Date();
    const startedAt = new Date(state.activeSession.startedAt);
    const completed: CompletedSession = {
      id: `session-${completedAt.getTime()}`,
      workout: state.activeSession.workout,
      startedAt: state.activeSession.startedAt,
      completedAt: completedAt.toISOString(),
      durationMinutes: Math.max(1, Math.round((completedAt.getTime() - startedAt.getTime()) / 60000)),
      progress: payload.progress,
      effort: payload.effort,
      pain: payload.pain,
      painLocation: payload.painLocation,
      hardRowingFinisher: payload.hardRowingFinisher,
      note: payload.note
    };
    state.history.unshift(completed);
    state.queue = state.queue.filter((workout) => workout.id !== completed.workout.id);
    state.queue.push(buildNextWorkout(state));
    state.activeSession = null;
  }

  if (payload.action === "updateProfile") {
    const previousEquipment = JSON.stringify({
      equipment: state.profile.equipment,
      otherEquipment: state.profile.otherEquipment ?? "",
      pushupLevel: state.profile.pushupLevel,
      pullupLevel: state.profile.pullupLevel,
    });
    state.profile = { ...state.profile, ...payload.profile };
    const nextEquipment = JSON.stringify({
      equipment: state.profile.equipment,
      otherEquipment: state.profile.otherEquipment ?? "",
      pushupLevel: state.profile.pushupLevel,
      pullupLevel: state.profile.pullupLevel,
    });
    if (!state.activeSession && previousEquipment !== nextEquipment) {
      state.queue = [
        state.history.length > 0
          ? buildNextWorkout(state)
          : buildDiagnosticWorkout(state.profile),
      ];
    }
  }

  if (payload.action === "abandonSession") {
    state.activeSession = null;
  }

  await writeState(state);
  return NextResponse.json(state);
}
