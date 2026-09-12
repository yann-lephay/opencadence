import Testing
@testable import OpenCadence

struct PaywallTimingTests {
    @Test("Loading the home or saving a summary never presents an offer")
    func noAutomaticOffer() {
        for count in [0, 1, 3] {
            #expect(SubscriptionAccessPolicy.workoutStartAction(
                startRequested: false, hasActiveWorkout: false,
                completedWorkoutCount: count, entitlementsLoaded: true,
                hasActiveSubscription: false
            ) == .stay)
        }
    }

    @Test("The next explicit start requires access after the existing free allowance")
    func nextAttempt() {
        #expect(action(count: 0) == .start)
        #expect(action(count: 1) == .paywall)
        #expect(action(count: 5) == .paywall)
    }

    @Test("An active session can always resume without a new access gate")
    func resumePriority() {
        for loaded in [true, false] {
            #expect(SubscriptionAccessPolicy.workoutStartAction(
                startRequested: true, hasActiveWorkout: true,
                completedWorkoutCount: 3, entitlementsLoaded: loaded,
                hasActiveSubscription: false
            ) == .resume)
        }
    }

    @Test("Unloaded entitlements wait instead of treating a subscriber as unpaid")
    func entitlementCheck() {
        #expect(action(count: 1, loaded: false) == .checkAccess)
        #expect(action(count: 1, loaded: true, subscribed: true) == .start)
        #expect(action(count: 1, loaded: true, subscribed: false) == .paywall)
        #expect(action(count: 0, loaded: false) == .start)
    }

    private func action(count: Int, loaded: Bool = true, subscribed: Bool = false) -> SubscriptionAccessPolicy.WorkoutStartAction {
        SubscriptionAccessPolicy.workoutStartAction(
            startRequested: true, hasActiveWorkout: false,
            completedWorkoutCount: count, entitlementsLoaded: loaded,
            hasActiveSubscription: subscribed
        )
    }
}
