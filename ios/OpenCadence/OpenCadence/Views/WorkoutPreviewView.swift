import CadenceEngine
import SwiftUI

struct WorkoutPreviewView: View {
    let decision: EngineDecision
    let onStart: () -> Void
    let onNormalWorkout: () -> Void
    let onAdapt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Ta prochaine séance")
                    .font(.archivoBlack(28, relativeTo: .title2))
                    .foregroundStyle(LBSBrand.brandText)
                Text(PresentationCopy.readinessTitle(decision.readiness))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LBSBrand.brandAccentText)
                Text(PresentationCopy.explanation(decision.reasonCodes))
                    .foregroundStyle(.secondary)
            }

            if decision.decision == "block_standard_mode" {
                Label("Le moteur standard n’est pas proposé dans cette situation", systemImage: "heart.text.square")
                    .font(.headline)
                Text("La Bonne Séance ne possède pas encore le mode dédié nécessaire. Cela ne signifie pas que l’activité physique est interdite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if decision.reasonCodes.contains("safety_stop_session") {
                Label("Pas de séance préparée aujourd’hui", systemImage: "pause.circle")
                    .font(.headline)
                Text("Le signal déclaré a arrêté le moteur standard. Aucun diagnostic ni contournement chargé n’est proposé.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if decision.decision == "request_valid_input" {
                Label("Aucune séance compatible avec ces choix", systemImage: "arrow.uturn.backward.circle")
                    .font(.headline)
                Text("Réintègre un mouvement, puis laisse le moteur recalculer le programme.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Modifier les mouvements écartés", action: onAdapt)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else if decision.decision == "generate_makeup", let makeup = decision.makeup {
                Label("Cette reprise est facultative. Rien n’est à rattraper pour rester à jour.", systemImage: "heart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(makeup.includedExerciseKeys, id: \.self) { exerciseKey in
                    Label(PresentationCopy.movementTitle(exerciseKey), systemImage: "circle")
                        .font(.subheadline.weight(.semibold))
                }
                Button("Préparer une séance normale", action: onNormalWorkout)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else if let movements = decision.movements {
                ForEach(Array(movements.enumerated()), id: \.element.exerciseKey) { index, movement in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 28, height: 28)
                            .foregroundStyle(LBSBrand.ink)
                            .background(LBSBrand.orange, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(PresentationCopy.movementTitle(movement.exerciseKey))
                                .fontWeight(.semibold)
                            Text("\(movement.sets) séries · \(movement.target)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let load = PresentationCopy.loadSummary(movement, decision: decision) {
                                Text(load)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let excluded = decision.excludedExerciseKeys, !excluded.isEmpty,
               decision.decision == "generate_workout" {
                Label(
                    excluded.count == 1
                        ? "1 mouvement écarté pour cette séance"
                        : "\(excluded.count) mouvements écartés pour cette séance",
                    systemImage: "slider.horizontal.3"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let progression = decision.progression {
                Label(PresentationCopy.progression(progression), systemImage: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            }

            if decision.decision == "generate_workout" {
                Button("Adapter les mouvements", action: onAdapt)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .tint(LBSBrand.controlTint)

                Button(action: onStart) {
                    Label("Commencer", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(LBSBrand.orange)
                .foregroundStyle(LBSBrand.ink)
            }
        }
        .padding()
        .background(LBSBrand.cardBackground, in: LBSChamferedRectangle(cut: 16))
        .overlay {
            LBSChamferedRectangle(cut: 16)
                .stroke(LBSBrand.border, lineWidth: 1)
        }
    }
}
