import SwiftData
import SwiftUI

@main
struct OpenCadenceApp: App {
    @StateObject private var subscriptions = SubscriptionStore()

    private let container: ModelContainer?

    init() {
        BrandFontRegistry.register()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-LBSSharingProof") || ProcessInfo.processInfo.arguments.contains("-LBSReviewProof") {
            container = nil
            return
        }
        if AppStoreScreenshotState.launchArgumentValue != nil || ProcessInfo.processInfo.arguments.contains("-OpenCadencePersonalizationProof") {
            container = nil
            return
        }
#endif
        do {
            container = try ModelContainer(
                for: UserSetupRecord.self,
                ActiveWorkoutRecord.self,
                CompletedWorkoutRecord.self
            )
        } catch {
            container = nil
        }
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-LBSSharingProof") {
                SessionSharingProofView()
            } else if ProcessInfo.processInfo.arguments.contains("-LBSReviewProof") {
                SessionReviewProofView()
            } else if ProcessInfo.processInfo.arguments.contains("-OpenCadencePersonalizationProof") {
                PersonalizationProofView().environmentObject(subscriptions)
            } else if let screenshotState = AppStoreScreenshotState.launchArgumentValue {
                AppStoreScreenshotHarnessView(state: screenshotState)
            } else if ProcessInfo.processInfo.arguments.contains("-OpenCadenceBrandLogoProof") {
                BrandLogoSizeProofView()
            } else if let container {
                AppRootView()
                    .modelContainer(container)
                    .environmentObject(subscriptions)
            } else {
                storageUnavailableView
            }
#else
            if let container {
                AppRootView()
                    .modelContainer(container)
                    .environmentObject(subscriptions)
            } else {
                storageUnavailableView
            }
#endif
        }
    }

    private var storageUnavailableView: some View {
        ContentUnavailableView {
            Label("Stockage indisponible", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("La Bonne Séance ne peut pas ouvrir ses données locales. Ferme puis relance l’app. Tes données ne seront pas remplacées automatiquement.")
        }
    }
}
