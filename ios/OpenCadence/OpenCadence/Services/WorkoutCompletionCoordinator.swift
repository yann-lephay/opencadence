import Foundation
import SwiftData

@MainActor
enum WorkoutCompletionCoordinator {
    static func save(
        snapshot: ActiveWorkoutSnapshot,
        activeRecord: ActiveWorkoutRecord,
        context: ModelContext,
        sharingEnrollmentID: String? = nil,
        sessionReview: SessionReview? = nil
    ) throws {
        do {
            let sessionID = snapshot.sessionID
            let descriptor = FetchDescriptor<CompletedWorkoutRecord>(
                predicate: #Predicate<CompletedWorkoutRecord> { $0.sessionID == sessionID }
            )
            let alreadySaved = try context.fetchCount(descriptor) > 0
            if !alreadySaved {
                let payload = WorkoutHistoryBuilder.payload(from: snapshot)
                let completed = try CompletedWorkoutRecord(payload: payload)
                completed.sharingEnrollmentID = sharingEnrollmentID
                if sharingEnrollmentID != nil, let sessionReview {
                    completed.sessionReviewData = try JSONEncoder().encode(sessionReview)
                }
                context.insert(completed)
            }
            context.delete(activeRecord)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
