import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptions: SubscriptionStore
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var sharing = SessionSharing.shared
    @AppStorage("sessionSharing.invitationHandled.v1") private var sharingInvitationHandled = false
    @State private var showingSharing = false

    @Query(sort: \UserSetupRecord.updatedAt, order: .reverse)
    private var setups: [UserSetupRecord]

    @Query(sort: \ActiveWorkoutRecord.updatedAt, order: .reverse)
    private var activeWorkouts: [ActiveWorkoutRecord]

    @Query(sort: \CompletedWorkoutRecord.endedAt, order: .reverse)
    private var completedWorkouts: [CompletedWorkoutRecord]

    @State private var started = false
    @State private var checkingAccess = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            if !started {
                WelcomeView(setup: setups.first, hasActiveWorkout: !activeWorkouts.isEmpty, onStart: { requestStart() }, showsTrialInformation: completedWorkouts.isEmpty)
                .overlay(alignment: .bottom) {
                    if checkingAccess {
                        ProgressView("Vérification de l’accès…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.bottom, 80)
                    }
                }
            } else if let activeWorkout = activeWorkouts.first {
                ActiveWorkoutView(record: activeWorkout)
            } else if let setup = setups.first {
                if setup.requiresSupportProfile {
                    EquipmentOnboardingView(existing: setup)
                } else if setup.requiresCalibration && WorkoutEngineRuntime.selectedVersion() == .productionV1 {
                    CalibrationView(setup: setup)
                } else {
                    HomeView(setup: setup, onBack: { started = false })
                }
            } else {
                EquipmentOnboardingView()
            }
        }
        .onChange(of: activeWorkouts.count) { oldCount, newCount in
            if oldCount > 0 && newCount == 0 { started = false }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(adaptationPreview: nil, onSubscribed: {
                showingPaywall = false
                requestStart()
            })
        }
        .tint(LBSBrand.controlTint)
        .safeAreaInset(edge: .bottom) {
            if !started && activeWorkouts.isEmpty && subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription
                && sharing.available && sharing.enrollment == nil && !sharingInvitationHandled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aider à améliorer les séances").font(.headline)
                    Text("Tu peux choisir de partager tes prochaines séances sous pseudonyme.").font(.subheadline)
                    HStack {
                        Button("En savoir plus") { showingSharing = true; sharingInvitationHandled = true }
                        Spacer()
                        Button("Non merci") { sharingInvitationHandled = true }
                    }.frame(minHeight: 44)
                }.padding().background(LBSBrand.cardBackground)
            }
        }
        .sheet(isPresented: $showingSharing) { NavigationStack { SessionSharingView(hasPaidAccess: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription) } }
        .onChange(of: completedWorkouts.count) { _, _ in syncSharing() }
        .onChange(of: sharing.enrollment) { _, _ in syncSharing() }
        .onChange(of: subscriptions.hasActiveSubscription) { _, _ in syncSharing() }
        .task {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-OpenCadencePersonalizationProof") && !ProcessInfo.processInfo.arguments.contains("-OpenCadenceWelcomeProof") { requestStart() }
#endif
            await subscriptions.start()
            syncSharing()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await subscriptions.refreshEntitlements(); syncSharing() }
        }
    }

    private func syncSharing() {
        Task { await sharing.sync(records: completedWorkouts, context: modelContext,
            paid: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription) }
    }

    private func requestStart() {
        guard !checkingAccess else { return }
        switch SubscriptionAccessPolicy.workoutStartAction(
            startRequested: true,
            hasActiveWorkout: !activeWorkouts.isEmpty,
            completedWorkoutCount: completedWorkouts.count,
            entitlementsLoaded: subscriptions.entitlementsLoaded,
            hasActiveSubscription: subscriptions.hasActiveSubscription
        ) {
        case .stay:
            break
        case .resume, .start:
            started = true
        case .paywall:
            showingPaywall = true
        case .checkAccess:
            checkingAccess = true
            Task {
                await subscriptions.refreshEntitlements()
                checkingAccess = false
                requestStart()
            }
        }
    }
}
