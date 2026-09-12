import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var subscriptions: SubscriptionStore

    let adaptationPreview: String?
    let onSubscribed: () -> Void

    private let ink = LBSBrand.ink
    private let orange = LBSBrand.orange

    var body: some View {
        let isLandscape = verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        NavigationStack {
            ScrollView {
                Group {
                    if isLandscape {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 20) {
                                hero
                                valueProof
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 20) {
                                offers
                                purchaseStatus
                                legal
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            hero
                            valueProof
                            offers
                            purchaseStatus
                            legal
                        }
                    }
                }
                .frame(maxWidth: isLandscape ? 980 : 640)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(LBSBrand.screenBackground.ignoresSafeArea())
        }
        .presentationDragIndicator(.visible)
        .tint(LBSBrand.controlTint)
        .task {
            await subscriptions.loadProductsIfNeeded()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                LBSMark(style: colorScheme == .dark ? .onDark : .color)
                    .frame(width: 78, height: 82)

                VStack(alignment: .leading, spacing: 4) {
                    Text("LA BONNE SÉANCE")
                        .font(.caption.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(LBSBrand.brandAccentText)
                    Text("Ça y est.")
                        .font(.archivoBlack(38, relativeTo: .largeTitle))
                        .foregroundStyle(LBSBrand.brandText)
                        .lineSpacing(-5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Ta première séance est terminée. La prochaine est déjà ajustée à ce que tu viens d’accomplir.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LBSBrand.brandText.opacity(0.82))
        }
    }

    private var valueProof: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let adaptationPreview, !adaptationPreview.isEmpty {
                Label {
                    Text(adaptationPreview)
                } icon: {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .foregroundStyle(orange)
                }
                .font(.subheadline.weight(.semibold))
            }

            Divider().overlay(LBSBrand.border)

            benefit("Une séance adaptée à votre temps et à votre matériel", icon: "slider.horizontal.3")
            benefit("Une progression expliquée à partir de vos séries", icon: "chart.line.uptrend.xyaxis")
            benefit("Une reprise sans retard ni programme à rattraper", icon: "arrow.uturn.forward.circle")
        }
        .padding(18)
        .background(LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(LBSBrand.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var offers: some View {
        if subscriptions.productsReady, let lifetime = subscriptions.lifetimeProduct {
            offerButton(
                product: lifetime,
                title: "Débloquer mes séances à vie",
                detail: "\(lifetime.displayPrice) · paiement unique",
                recommended: true
            )
        } else {
            VStack(spacing: 14) {
                if subscriptions.productLoadState == .loading {
                    ProgressView("Chargement de l’offre Apple…")
                        .tint(LBSBrand.controlTint)
                } else {
                    Label(productLoadMessage, systemImage: "wifi.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(LBSBrand.brandText)
                    Button("Réessayer") {
                        Task { await subscriptions.loadProductsIfNeeded(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    private var purchaseStatus: some View {
        if let message = subscriptions.operationMessage {
            Label(message, systemImage: subscriptions.hasActiveSubscription ? "checkmark.circle.fill" : "info.circle")
                .font(.footnote)
                .foregroundStyle(LBSBrand.brandText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }

        if case .failed(let message) = subscriptions.purchaseState {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var legal: some View {
        VStack(spacing: 12) {
            Button("Restaurer mes achats") {
                Task {
                    if await subscriptions.restorePurchases() {
                        onSubscribed()
                        dismiss()
                    }
                }
            }
            .disabled(subscriptions.isWorking)

            Text("Un seul achat pour un accès à vie. Sans abonnement ni renouvellement automatique. Vous pouvez restaurer cet achat avec le même compte Apple.")
                .font(.caption)
                .foregroundStyle(LBSBrand.brandText.opacity(0.66))
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Link("Confidentialité", destination: URL(string: "https://labonneseance.com/confidentialite")!)
                Link("Conditions", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private func benefit(_ title: LocalizedStringKey, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(LBSBrand.brandText)
    }

    private func offerButton(
        product: Product,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        recommended: Bool
    ) -> some View {
        Button {
            Task {
                if await subscriptions.purchase(product) {
                    onSubscribed()
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .opacity(0.75)
                }
                Spacer()
                if case .purchasing(let productID) = subscriptions.purchaseState,
                   productID == product.id {
                    ProgressView()
                        .tint(recommended ? LBSBrand.cream : LBSBrand.controlTint)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .foregroundStyle(recommended ? LBSBrand.cream : LBSBrand.brandText)
            .background(recommended ? ink : LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(recommended ? ink : LBSBrand.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(subscriptions.isWorking)
        .accessibilityHint("Ouvre la confirmation d’achat Apple")
    }

    private var productLoadMessage: String {
        if case .failed(let message) = subscriptions.productLoadState {
            return message
        }
        return String(localized: "L’offre est indisponible pour le moment.")
    }
}
