import Combine
import StoreKit
import SwiftUI

enum SubscriptionAccessPolicy {
    enum WorkoutStartAction: Equatable {
        case stay, resume, start, checkAccess, paywall
    }

    static func workoutStartAction(
        startRequested: Bool,
        hasActiveWorkout: Bool,
        completedWorkoutCount: Int,
        entitlementsLoaded: Bool,
        hasActiveSubscription: Bool
    ) -> WorkoutStartAction {
        guard startRequested else { return .stay }
        if hasActiveWorkout { return .resume }
        if completedWorkoutCount == 0 { return .start }
        guard entitlementsLoaded else { return .checkAccess }
        return hasActiveSubscription ? .start : .paywall
    }

    static let presentAfterFirstWorkoutKey = "subscription.presentAfterFirstWorkout"

    static func canPrepareWorkout(
        completedWorkoutCount: Int,
        hasActiveSubscription: Bool
    ) -> Bool {
        completedWorkoutCount == 0 || hasActiveSubscription
    }

    static func shouldPresentFirstPaywall(
        isPending: Bool,
        completedWorkoutCount: Int,
        entitlementsLoaded: Bool,
        hasActiveSubscription: Bool
    ) -> Bool {
        isPending
            && completedWorkoutCount > 0
            && entitlementsLoaded
            && !hasActiveSubscription
    }

    static func isLifetimeProduct(productID: String, type: Product.ProductType) -> Bool {
        productID == SubscriptionStore.lifetimeProductID && type == .nonConsumable
    }

}

@MainActor
final class SubscriptionStore: ObservableObject {
    enum ProductLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing(String)
        case pending
        case failed(String)

        var blocksFurtherPurchases: Bool {
            switch self {
            case .purchasing, .pending:
                true
            case .idle, .failed:
                false
            }
        }
    }

    nonisolated static let lifetimeProductID = "fr.labonneseance.lifetime"
    nonisolated static let productIDs: Set<String> = [lifetimeProductID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var productLoadState: ProductLoadState = .idle
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var entitlementsLoaded = false
    @Published private(set) var operationMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var lifetimeProduct: Product? {
        products.first { SubscriptionAccessPolicy.isLifetimeProduct(productID: $0.id, type: $0.type) }
    }

    var productsReady: Bool { lifetimeProduct != nil }

    var hasActiveSubscription: Bool {
        !activeProductIDs.isDisjoint(with: Self.productIDs)
    }

    var isWorking: Bool {
        purchaseState.blocksFurtherPurchases || productLoadState == .loading
    }

    func start() async {
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = observeTransactionUpdates()
        }
        await refreshEntitlements()
        await loadProductsIfNeeded()
    }

    func refreshEntitlements() async {
        var verifiedProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else {
                continue
            }
            verifiedProductIDs.insert(transaction.productID)
        }

        activeProductIDs = verifiedProductIDs
        entitlementsLoaded = true
    }

    func loadProductsIfNeeded(force: Bool = false) async {
        if productsReady && !force { return }

        productLoadState = .loading
        operationMessage = nil

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.filter { SubscriptionAccessPolicy.isLifetimeProduct(productID: $0.id, type: $0.type) }

            if productsReady {
                productLoadState = .loaded
            } else {
                productLoadState = .failed(String(localized: "L’achat à vie n’est pas encore disponible."))
            }
        } catch {
            products = []
            productLoadState = .failed(String(localized: "L’offre n’a pas pu être chargée."))
        }
    }

    func purchase(_ product: Product) async -> Bool {
        guard !isWorking, SubscriptionAccessPolicy.isLifetimeProduct(productID: product.id, type: product.type) else { return false }

        purchaseState = .purchasing(product.id)
        operationMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseState = .failed(String(localized: "La transaction n’a pas pu être vérifiée."))
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .idle
                return hasActiveSubscription

            case .pending:
                purchaseState = .pending
                operationMessage = String(localized: "L’achat attend encore la confirmation d’Apple. L’app vérifiera de nouveau ton accès automatiquement.")
                return false

            case .userCancelled:
                purchaseState = .idle
                return false

            @unknown default:
                purchaseState = .failed(String(localized: "La réponse de l’App Store n’est pas reconnue."))
                return false
            }
        } catch {
            purchaseState = .failed(String(localized: "L’achat n’a pas abouti. Rien n’a été débité par l’app."))
            return false
        }
    }

    func restorePurchases() async -> Bool {
        operationMessage = nil
        purchaseState = .purchasing("restore")

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = .idle
            operationMessage = hasActiveSubscription
                ? String(localized: "Accès à vie restauré.")
                : String(localized: "Aucun achat à vie n’a été trouvé sur ce compte Apple.")
            return hasActiveSubscription
        } catch {
            purchaseState = .failed(String(localized: "La restauration n’a pas abouti. Tu peux réessayer sans perdre tes séances."))
            return false
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

}
