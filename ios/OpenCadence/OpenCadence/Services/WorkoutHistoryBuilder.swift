import CadenceEngine
import Foundation

enum WorkoutHistoryBuilder {
    static func payload(
        from snapshot: ActiveWorkoutSnapshot,
        endedAt: Date? = nil
    ) -> CompletedWorkoutPayload {
        let resolvedEndedAt = endedAt ?? snapshot.endedAt ?? .now
        let feedback = snapshot.feedback ?? .empty
        let painScore = [feedback.discomfort, snapshot.maximumReportedPain]
            .compactMap { $0 }
            .max()
        let movements = snapshot.decision.movements ?? []
        let results = snapshot.recordedSets
        let lastWeightedExerciseKey = results.reversed().first { $0.perUnitWeightKg != nil }?.exerciseKey

        let exerciseRecords = movements.compactMap { movement -> ExerciseRecord? in
            let movementResults = results.filter { $0.exerciseKey == movement.exerciseKey }
            guard let lastResult = movementResults.last else { return nil }
            let requirement = movement.equipment.first {
                $0.category == "fixed_dumbbell" || $0.category == "adjustable_dumbbell"
            } ?? movement.equipment.first
            return ExerciseRecord(
                exerciseKey: movement.exerciseKey,
                configuration: requirement?.configuration,
                perUnitWeightKg: lastResult.perUnitWeightKg,
                topRangeReps: upperBound(in: movement.target),
                completedReps: lastResult.repetitions,
                lastSetRir: movement.exerciseKey == lastWeightedExerciseKey
                    ? feedback.repetitionsInReserve
                    : nil
            )
        }

        let completedExerciseKeys = movements.compactMap { movement in
            !snapshot.skippedExerciseKeys.contains(movement.exerciseKey)
                && results.filter { $0.exerciseKey == movement.exerciseKey }.count >= movement.sets
                ? movement.exerciseKey
                : nil
        }
        let history = HistorySession(
            sessionId: snapshot.sessionID,
            endedAt: isoDate(resolvedEndedAt),
            effort: feedback.effort,
            painScore: painScore,
            exerciseRecords: exerciseRecords,
            hardRowerFinisher: false,
            completedExerciseKeys: completedExerciseKeys,
            skippedExerciseKeys: snapshot.skippedExerciseKeys,
            conditioningCompleted: false,
            endedEarly: snapshot.endedEarly
        )
        return CompletedWorkoutPayload(
            endedAt: resolvedEndedAt,
            snapshot: snapshot,
            feedback: feedback,
            historySession: history
        )
    }

    private static func upperBound(in target: String) -> Int? {
        let values = target
            .split { !$0.isNumber }
            .compactMap { Int($0) }
        return values.count >= 2 ? values[1] : values.first
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
