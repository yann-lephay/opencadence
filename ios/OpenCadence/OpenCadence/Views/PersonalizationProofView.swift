#if DEBUG
import CadenceEngine
import SwiftData
import SwiftUI

/// Explicit, disposable fixture; never opens the user's persistent store.
struct PersonalizationProofView: View {
    @State private var container: ModelContainer?
    @State private var setup: UserSetupRecord?
    @State private var active: ActiveWorkoutRecord?

    init() {
        do {
            let store = try ModelContainer(for: UserSetupRecord.self, ActiveWorkoutRecord.self, CompletedWorkoutRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let profile = try UserSetupRecord(inventory: [
                EquipmentItem(category: "bodyweight", units: 1, supportedConfigurations: ["bodyweight"])
            ], supportProfile: UserSupportProfile(floorAllowed: true, stableSeatOrBench: true, solidWall: true,
                overheadClearance: true, travelSpace: true, bandFootSetupAllowed: false, pullupClearance: false,
                pullupTopStartSupport: false, bandOnPullupBarAllowed: false, dipBarsRowSafe: false,
                floorGripSafe: true, stepUpApprovedSupport: false, hipThrustBenchApproved: false))
            store.mainContext.insert(profile)
            let recentProof = ProcessInfo.processInfo.arguments.contains("-OpenCadenceRecentWorkProof")
            let activeRecord: ActiveWorkoutRecord?
            if recentProof || ProcessInfo.processInfo.arguments.contains("-OpenCadencePersonalizationRestProof") || ProcessInfo.processInfo.arguments.contains("-OpenCadenceRepetitionProof") {
                var history: [CompletedWorkoutRecord] = []
                if recentProof || ProcessInfo.processInfo.arguments.contains("-OpenCadenceRepetitionProof") {
                    for day in (recentProof ? [2, 1] : [9, 6, 3]) {
                        let date = Date.now.addingTimeInterval(Double(-day * 86400))
                        let prior = WorkoutEngineBridge.prepareWorkout(inventory: profile.inventory, durationMinutes: 30,
                            completedWorkouts: history, engineVersion: .previewV2, todaySupports: profile.supportProfile!.engineSupportKeys,
                            person: .init(sessionId: "synthetic-gap-\(day)"), now: date)
                        var state = ActiveSessionCoordinator.start(decision: prior.decision, v2Context: prior.v2Context, now: date)
                        var clock = date
                        while !state.isFinished {
                            if state.restDeadline != nil { state = ActiveSessionCoordinator.completeRest(state, now: clock) }
                            state = ActiveSessionCoordinator.startSet(state, now: clock)
                            state = ActiveSessionCoordinator.recordSet(state, repetitions: 8, now: clock.addingTimeInterval(30))
                            clock = clock.addingTimeInterval(180)
                        }
                        let completed = try CompletedWorkoutRecord(payload: WorkoutHistoryBuilder.payload(from: state))
                        store.mainContext.insert(completed); history.append(completed)
                    }
                }
                let prepared = WorkoutEngineBridge.prepareWorkout(inventory: profile.inventory, durationMinutes: 30,
                    completedWorkouts: history, engineVersion: .previewV2, todaySupports: profile.supportProfile!.engineSupportKeys,
                    person: .init(sessionId: "synthetic-personalization-proof"))
                var snapshot = ActiveSessionCoordinator.start(decision: prepared.decision, v2Context: prepared.v2Context)
                if !recentProof {
                    snapshot = ActiveSessionCoordinator.startSet(snapshot)
                    snapshot = ActiveSessionCoordinator.recordSet(snapshot, repetitions: 8)
                }
                let record = try ActiveWorkoutRecord(snapshot: snapshot)
                store.mainContext.insert(record); activeRecord = record
            } else { activeRecord = nil }
            try store.mainContext.save()
            _container = State(initialValue: store); _setup = State(initialValue: profile); _active = State(initialValue: activeRecord)
        } catch { _container = State(initialValue: nil); _setup = State(initialValue: nil); _active = State(initialValue: nil) }
    }

    var body: some View {
        if let container, let setup {
            Group {
                if let active { NavigationStack { ActiveWorkoutView(record: active) } }
                else { AppRootView() }
            }.modelContainer(container)
                .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("-OpenCadenceLargeTypeProof") ? .accessibility3 : .large)
        } else { Text("Fixture unavailable") }
    }
}
#endif
