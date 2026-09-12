#if DEBUG
import StoreKit
import SwiftUI

/// Visual preparation only. No product lookup, transaction or entitlement mutation.
struct PurchaseDesignPaywallView: View {
    let product: Product?
    let onPurchase: (Product) -> Void
    let onRestore: () -> Void

    private var availableProduct: Product? {
        guard let product, product.type == .nonConsumable else { return nil }
        return product
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LBSWordmark()
                    Image("paywall-selected-v5")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .blendMode(.multiply)
                        .accessibilityHidden(true)
                    Text("Ta bonne séance.\nQuand tu veux.")
                        .font(.archivoBlack(42, relativeTo: .largeTitle))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Des séances adaptées à toi, à ton matériel et à tes progrès.")
                        .font(.title3)
                    NavigationLink("Notre méthode") { MethodView() }
                        .frame(minHeight: 44)
                    VStack(alignment: .leading, spacing: 16) {
                        if let availableProduct {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 18) {
                                    price(availableProduct)
                                    paymentDescription
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    price(availableProduct)
                                    paymentDescription
                                }
                            }
                        } else {
                            Text("L’offre n’est pas encore disponible.")
                                .font(.headline)
                        }
                        Button {
                            guard let availableProduct else { return }
                            onPurchase(availableProduct)
                        } label: {
                            Text("Débloquer mes séances")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LBSBrand.orange)
                        .foregroundStyle(LBSBrand.ink)
                        .disabled(availableProduct == nil)
                        if availableProduct != nil {
                            Text("Accès permanent aux séances et à leur adaptation.")
                                .font(.footnote)
                        }
                        Button("Restaurer un achat", action: onRestore)
                            .frame(minHeight: 44)
                        Link("Conditions", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .frame(minHeight: 44)
                        Link("Confidentialité", destination: URL(string: "https://labonneseance.com/confidentialite")!)
                            .frame(minHeight: 44)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(LBSBrand.cream.ignoresSafeArea())
            .foregroundStyle(LBSBrand.ink)
            .tint(LBSBrand.ink)
        }
        .preferredColorScheme(.light)
    }

    private func price(_ product: Product) -> some View {
        Text(product.displayPrice)
            .font(.archivoBlack(40, relativeTo: .largeTitle))
    }

    private var paymentDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Un seul paiement.").font(.headline)
            Text("Aucun abonnement.").font(.subheadline)
        }
    }
}

struct PurchaseDesignSuccessView: View {
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LBSWordmark()
                VStack(alignment: .leading, spacing: 14) {
                    Text("C’est à toi.\nOn bouge ?")
                        .font(.archivoBlack(44, relativeTo: .largeTitle))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Ta bonne séance t’attend.\nEt les suivantes aussi.")
                        .font(.title3)
                    Image("purchase-selected-v5")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 380)
                        .frame(maxWidth: .infinity)
                        .blendMode(.multiply)
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.08),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                        .accessibilityHidden(true)
                }
                Button(action: onStart) {
                    Text("Commencer ma séance")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(LBSBrand.orange)
                .foregroundStyle(LBSBrand.ink)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(LBSBrand.ink)
        .background(LBSBrand.cream.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
#endif
