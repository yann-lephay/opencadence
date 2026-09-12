import SwiftUI

struct WelcomeView: View {
    let setup: UserSetupRecord?
    let hasActiveWorkout: Bool
    let onStart: () -> Void
    var showsTrialInformation = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        LBSWordmark()
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Paramètres")
                    }
                    if isLandscape {
                        HStack(alignment: .center, spacing: 28) {
                            welcomeCopy(isLandscape: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            hero(height: max(280, geometry.size.height - 118))
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            welcomeTitle(isLandscape: false)
                            hero(height: max(260, min(380, geometry.size.height * 0.44)))
                        }
                        welcomeActions
                    }
                }
                .padding(.horizontal, isLandscape ? 32 : 22)
                .padding(.vertical, isLandscape ? 16 : 22)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
        .foregroundStyle(LBSBrand.brandText)
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView(setup: setup) } }
    }

    private func welcomeCopy(isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            welcomeTitle(isLandscape: isLandscape)
            welcomeActions
        }
    }

    private func welcomeTitle(isLandscape: Bool) -> some View {
        Text((hasActiveWorkout ? String(localized: "On reprend ?") : String(localized: "On bouge ?"))
            .replacingOccurrences(of: " ?", with: "\u{00a0}?"))
            .font(.archivoBlack(isLandscape ? 50 : (hasActiveWorkout ? 54 : 64), relativeTo: .largeTitle))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .tracking(-2)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 340, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, isLandscape ? 0 : 12)
            .accessibilityAddTraits(.isHeader)
    }

    private func hero(height: CGFloat) -> some View {
        Image("home-art")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .accessibilityHidden(true)
    }

    private var welcomeActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasActiveWorkout {
                Text("Ta séance t’attend.").font(.body)
            }
            Button(action: onStart) {
                Text(hasActiveWorkout ? "Reprendre ma séance" : "Découvrir")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LBSBrand.cream)
            .background(LBSBrand.ink, in: RoundedRectangle(cornerRadius: 16))
            if !hasActiveWorkout && showsTrialInformation {
                Text("Première séance gratuite. Ensuite, un achat unique pour continuer.")
                    .font(.footnote)
                    .foregroundStyle(LBSBrand.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
