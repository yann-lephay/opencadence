import StoreKit
import StoreKitTest
import Testing
@testable import OpenCadence

@Suite(.serialized)
@MainActor
struct LifetimePurchaseTests {
    @Test("Lifetime purchase survives store recreation and is removed after refund")
    func purchaseRestoreAndRefund() async throws {
        let session = try SKTestSession(configurationFileNamed: "LaBonneSeance")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let store = SubscriptionStore()
        await store.refreshEntitlements()
        #expect(!store.hasActiveSubscription)
        await store.loadProductsIfNeeded()
        let product = try #require(store.lifetimeProduct)
        #expect(product.type == .nonConsumable)
        #expect(product.price == Decimal(string: "59.99"))
        #expect(store.products.count == 1)
        #expect(await store.purchase(product))
        #expect(store.hasActiveSubscription)

        let restored = SubscriptionStore()
        #expect(await restored.restorePurchases())
        #expect(restored.hasActiveSubscription)
        #expect(SubscriptionAccessPolicy.canPrepareWorkout(completedWorkoutCount: 5, hasActiveSubscription: restored.hasActiveSubscription))

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        await restored.refreshEntitlements()
        #expect(!restored.hasActiveSubscription)
        #expect(!SubscriptionAccessPolicy.canPrepareWorkout(completedWorkoutCount: 1, hasActiveSubscription: restored.hasActiveSubscription))
    }
}
