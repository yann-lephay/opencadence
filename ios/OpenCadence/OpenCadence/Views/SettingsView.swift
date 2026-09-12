import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptions: SubscriptionStore
    @Query(sort: \CompletedWorkoutRecord.endedAt, order: .reverse)
    private var records: [CompletedWorkoutRecord]
    let setup: UserSetupRecord?
    @State private var destination: Destination?
    @ObservedObject private var sharing = SessionSharing.shared

    private enum Destination: String, Identifiable {
        case equipment, calibration, history, access
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                LBSWordmark()
                Text("Paramètres")
                    .font(.archivoBlack(40, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 14) {
                    Text(subscriptions.hasActiveSubscription ? String(localized: "Accès à vie") : String(localized: "Ton accès"))
                        .font(.archivoBlack(26, relativeTo: .title2))
                    if !subscriptions.entitlementsLoaded {
                        ProgressView("Vérification de l’accès…")
                    } else if subscriptions.hasActiveSubscription {
                        Text("Tes séances sont débloquées sans abonnement.")
                    } else {
                        Button("Voir les offres") { destination = .access }
                            .buttonStyle(.borderedProminent)
                            .tint(LBSBrand.orange)
                            .foregroundStyle(LBSBrand.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                VStack(spacing: 0) {
                    row("Mon matériel", subtitle: "Ajouter ou modifier ce que tu as", icon: "dumbbell") { destination = .equipment }
                    if let setup, setup.requiresCalibration || setup.usesExplicitCalibration {
                        row("Mes repères", subtitle: "Ajuster le départ du haut et du bas du corps", icon: "slider.horizontal.3") { destination = .calibration }
                    }
                    row("Dernières séances", subtitle: "Retrouver le travail enregistré", icon: "clock.arrow.circlepath") { destination = .history }
                    NavigationLink {
                        MethodView()
                    } label: {
                        rowLabel("Notre méthode", subtitle: "Ce qui guide ta bonne séance", icon: "book.closed")
                    }
                    Divider()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tes données").font(.archivoBlack(24, relativeTo: .title2))
                    if (subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription) || sharing.enrollment != nil {
                        NavigationLink("Partage de mes séances") { SessionSharingView(hasPaidAccess: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription) }
                            .frame(minHeight: 44)
                    }
                    Link("Confidentialité", destination: URL(string: "https://labonneseance.com/confidentialite")!)
                        .frame(minHeight: 44)
                    Link("Conditions", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .frame(minHeight: 44)
                }
                Button("Restaurer un achat") {
                    Task { _ = await subscriptions.restorePurchases() }
                }
                .frame(minHeight: 44)
                .disabled(subscriptions.isWorking)
                if let message = subscriptions.operationMessage {
                    Text(message).font(.subheadline).accessibilityAddTraits(.updatesFrequently)
                }
                if case .failed(let message) = subscriptions.purchaseState {
                    Text(message).font(.subheadline)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(LBSBrand.brandText)
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .tint(LBSBrand.controlTint)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $destination) { destination in
            switch destination {
            case .equipment:
                NavigationStack {
                    EquipmentOnboardingView(existing: setup, onSaved: { self.destination = nil })
                }
            case .calibration:
                if let setup { NavigationStack { CalibrationView(setup: setup) } }
            case .history:
                NavigationStack {
                    ScrollView {
                        if records.isEmpty {
                            ContentUnavailableView("Aucune séance enregistrée", systemImage: "clock")
                        } else {
                            RecentHistoryView(records: records).padding(24)
                        }
                    }
                    .background(LBSBrand.screenBackground.ignoresSafeArea())
                }
            case .access:
                PaywallView(adaptationPreview: nil, onSubscribed: { self.destination = nil })
            }
        }
    }

    private func row(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) { rowLabel(title, subtitle: subtitle, icon: icon) }
            Divider()
        }
    }

    private func rowLabel(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(LBSBrand.secondaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}
