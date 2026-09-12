import CadenceEngine
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var subscriptions: SubscriptionStore

    @Query(sort: \CompletedWorkoutRecord.endedAt, order: .reverse)
    private var completedWorkouts: [CompletedWorkoutRecord]

    let setup: UserSetupRecord
    var onBack: (() -> Void)? = nil

    @State private var decision: EngineDecision?
    @State private var v2Context: ActiveWorkoutV2Context?
    @State private var errorMessage: String?
    @State private var editingEquipment = false
    @State private var editingCalibration = false
    @State private var editingMovements = false
    @State private var adaptableMovementKeys: [String] = []
    @State private var excludedMovementKeys: Set<String> = []
    @State private var sessionMode: V2SessionMode = .normal
    @State private var unavailableEquipmentCategories: Set<String> = []
    @State private var declaredCurrentHealthSignal = false
    @State private var showingPaywall = false
    @State private var returning = false
    @State private var preparationPerson: V2Personalization?
    @State private var personalizationResult: V2PersonalizedSessionResult?
    @State private var adjustmentID: String?
    @State private var automaticPreparationAttempted = false


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let onBack {
                    Button("Retour", action: onBack)
                        .frame(minHeight: 44)
                }
                LBSWordmark()

                if WorkoutEngineRuntime.selectedVersion() == .productionV1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Composer la séance")
                        .font(.archivoBlack(22, relativeTo: .title2))
                        .foregroundStyle(LBSBrand.brandText)
                    if WorkoutEngineRuntime.selectedVersion() == .productionV1 {
                        Picker("Durée", selection: durationBinding) {
                            Text("20 min").tag(20); Text("30 min").tag(30); Text("45 min").tag(45)
                        }.pickerStyle(.segmented)
                    } else {
                        Text("Ta pratique du renforcement").font(.subheadline)
                        Picker("Ta pratique du renforcement", selection: Binding(
                            get: { setup.strengthPracticeRaw ?? "unknown" },
                            set: { value in
                                let old = setup.strengthPracticeRaw
                                setup.strengthPracticeRaw = value
                                do { try modelContext.save(); preparationPerson = nil; decision = nil }
                                catch { setup.strengthPracticeRaw = old; errorMessage = String(localized: "Enregistrement impossible. Réessaie.") }
                            })) {
                            Text("Sans repère pour le moment").tag("unknown")
                            Text("Je découvre").tag("discovering")
                            Text("De temps en temps").tag("occasional")
                            Text("Régulièrement").tag("regular")
                        }
                        Toggle("Je reprends après une pause", isOn: $returning)
                    }

                    Picker("Intention", selection: $sessionMode) {
                        Text("Normale").tag(V2SessionMode.normal)
                        Text("Allégée").tag(V2SessionMode.light)
                        Text("Retrouver mes repères").tag(V2SessionMode.recalibration)
                    }

                    DisclosureGroup("Adapter seulement aujourd’hui") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(Set(setup.inventory.map(\.category))).filter { $0 != "bodyweight" }.sorted(), id: \.self) { category in
                                Toggle(
                                    PresentationCopy.equipmentSummary(setup.inventory.filter { $0.category == category }),
                                    isOn: todayAvailabilityBinding(forEquipment: category)
                                )
                            }

                            Toggle("Un signal inhabituel me fait arrêter avant de commencer", isOn: $declaredCurrentHealthSignal)
                            Text("Cette option arrête simplement la préparation. Elle ne cherche pas à identifier ou diagnostiquer le signal.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    Button {
                        prepareWorkout()
                    } label: {
                        Label(
                            completedWorkouts.isEmpty
                                ? "Préparer ma première séance"
                                : (hasWorkoutAccess ? "Préparer ma séance" : "Voir la séance suivante"),
                            systemImage: hasWorkoutAccess ? "sparkles" : "lock.open"
                        )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(LBSBrand.orange)
                    .foregroundStyle(LBSBrand.ink)

                    if completedWorkouts.isEmpty {
                        Text("Ta première séance complète est gratuite. Ensuite, l’app affiche les offres et les prix locaux de l’App Store.")
                            .font(.footnote)
                            .foregroundStyle(LBSBrand.secondaryText)
                    }
                }
                .padding()
                .background(LBSBrand.cardBackground, in: LBSChamferedRectangle(cut: 16))
                .overlay {
                    LBSChamferedRectangle(cut: 16)
                        .stroke(LBSBrand.border, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ton matériel")
                            .font(.headline)
                        Spacer()
                        Button("Modifier") { editingEquipment = true }
                    }
                    Text(PresentationCopy.equipmentSummary(setup.inventory))
                        .foregroundStyle(.secondary)
                }

                if setup.usesExplicitCalibration && WorkoutEngineRuntime.selectedVersion() == .productionV1 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tes repères de départ")
                                .font(.headline)
                            Spacer()
                            Button("Modifier") { editingCalibration = true }
                        }
                        LabeledContent("Haut du corps") {
                            Text(PresentationCopy.calibrationTitle(setup.calibrations.upper))
                        }
                        LabeledContent("Bas du corps") {
                            Text(PresentationCopy.calibrationTitle(setup.calibrations.lower))
                        }
                        Text("Ces deux repères restent indépendants. Ils ne forment pas un niveau global.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }

                }
                if let decision {
                    if hasWorkoutAccess {
                        if let result = personalizationResult {
                            personalizedPreview(decision, result: result)
                        } else {
                            WorkoutPreviewView(decision: decision, onStart: { start(decision) },
                                onNormalWorkout: { prepareWorkout(allowOptionalMakeup: false) }, onAdapt: { editingMovements = true })
                        }
                    } else {
                        lockedContinuationCard(decision)
                    }
                }

                if !completedWorkouts.isEmpty {
                    RecentHistoryView(records: Array(completedWorkouts.prefix(3)))
                }

                if WorkoutEngineRuntime.selectedVersion() != .productionV1 {
                    if decision == nil && errorMessage == nil { ProgressView("Ta séance se prépare…") }
                    if decision?.decision != "generate_workout" {
                        Button("Vérifier mon matériel") { editingEquipment = true }.frame(minHeight: 44)
                        Button("Réessayer") {
                            prepareWorkout()
                        }.frame(minHeight: 44)
                    }
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard WorkoutEngineRuntime.selectedVersion() != .productionV1, !automaticPreparationAttempted else { return }
            automaticPreparationAttempted = true
            prepareWorkout()
        }
        .sheet(isPresented: Binding(get: { adjustmentID != nil }, set: { if !$0 { adjustmentID = nil } })) {
            if let id = adjustmentID, let result = personalizationResult {
                PersonalizationAdjustmentView(exerciseID: id,
                    options: result.optionsByExercise[id] ?? result.checks.first(where: { $0.exerciseId == id })?.alternatives ?? [],
                    inventory: v2Context?.inventory ?? WorkoutEngineBridge.previewInventory(from: setup.inventory.filter { $0.category == "bodyweight" || !unavailableEquipmentCategories.contains($0.category) }, configuration: WorkoutEngineRuntime.selectedVersion() == .releaseV2 ? .releaseV2 : .productPreview), currentSets: v2Context?.plan.first(where: { $0.exerciseId == id })?.sets ?? 2,
                    releaseConfiguration: WorkoutEngineRuntime.selectedVersion() == .releaseV2) { id, choice, scope, declaration in
                    let oldPerson = preparationPerson, oldDecision = decision, oldContext = v2Context, oldResult = personalizationResult
                    var committed = false
                    defer {
                        if !committed {
                            preparationPerson = oldPerson; decision = oldDecision; v2Context = oldContext; personalizationResult = oldResult
                        }
                    }
                    var knowledge = try preparationPerson?.knowledge ?? setup.movementKnowledge()
                    if let declaration { knowledge.removeAll { $0.exerciseId == declaration.exerciseId }; knowledge.append(declaration) }
                    let sessionID = preparationPerson?.sessionId ?? UUID().uuidString
                    var choices = preparationPerson?.choices.filter { $0.exerciseId != id } ?? []
                    if let choice {
                        let commandScope: V2ChoiceScope = { if case .variant = choice { return .today }; return scope }()
                        choices.append(.init(sessionId: sessionID, exerciseId: id, choice: choice, scope: commandScope, at: .now))
                    }
                    preparationPerson = .init(sessionId: sessionID, practice: setup.strengthPractice, returning: returning,
                        knowledge: knowledge, choices: choices)
                    prepareWorkout()
                    guard personalizationResult?.decision.decision == .generateSession else {
                        throw NativePersonalization.AdjustmentError.invalidDecision
                    }
                    if scope == .usual, let updated = personalizationResult {
                        let old = setup.movementKnowledgeData
                        setup.movementKnowledgeData = try JSONEncoder().encode(NativePersonalization.durableKnowledge(try setup.movementKnowledge(), exerciseID: id, choice: choice, declaration: declaration, result: updated.knowledge))
                        do { try modelContext.save() } catch { setup.movementKnowledgeData = old; throw error }
                    }
                    committed = true
                }
            }
        }
        .sheet(isPresented: $editingEquipment) {
            NavigationStack {
                EquipmentOnboardingView(existing: setup)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $editingCalibration) {
            NavigationStack {
                CalibrationView(setup: setup)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $editingMovements) {
            NavigationStack {
                MovementAdjustmentView(
                    movementKeys: Array(Set(adaptableMovementKeys + setup.persistentRefusals)).sorted(),
                    initiallyExcluded: excludedMovementKeys,
                    initiallyPersistent: Set(setup.persistentRefusals)
                ) { selected, persistent in
                    excludedMovementKeys = selected
                    setup.persistentRefusals = Array(persistent)
                    try? modelContext.save()
                    editingMovements = false
                    prepareWorkout(allowOptionalMakeup: false)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                adaptationPreview: decision.map {
                    PresentationCopy.explanation($0.reasonCodes)
                },
                onSubscribed: {
                    prepareWorkout()
                }
            )
            .presentationDragIndicator(.visible)
        }
    }

    private var hasWorkoutAccess: Bool {
        SubscriptionAccessPolicy.canPrepareWorkout(
            completedWorkoutCount: completedWorkouts.count,
            hasActiveSubscription: subscriptions.hasActiveSubscription
        )
    }

    private func verifyAccessForAttempt() -> Bool {
        switch SubscriptionAccessPolicy.workoutStartAction(
            startRequested: true,
            hasActiveWorkout: false,
            completedWorkoutCount: completedWorkouts.count,
            entitlementsLoaded: subscriptions.entitlementsLoaded,
            hasActiveSubscription: subscriptions.hasActiveSubscription
        ) {
        case .start, .resume:
            return true
        case .checkAccess:
            errorMessage = String(localized: "Vérification de l’accès en cours. Réessaie dans un instant.")
            Task { await subscriptions.refreshEntitlements() }
            return false
        case .paywall:
            showingPaywall = true
            return false
        case .stay:
            return false
        }
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { setup.selectedDuration },
            set: { value in
                setup.selectedDuration = value
                setup.updatedAt = .now
                do {
                    try modelContext.save()
                    decision = nil
                    v2Context = nil
                    adaptableMovementKeys = []
                    excludedMovementKeys = []
                    errorMessage = nil
                } catch {
                    errorMessage = String(localized: "La durée n’a pas pu être enregistrée. Réessaie avant de démarrer.")
                }
            }
        )
    }

    private func start(_ decision: EngineDecision) {
        guard verifyAccessForAttempt() else { return }
        guard decision.decision == "generate_workout", decision.movements?.isEmpty == false else {
            errorMessage = String(localized: "Cette proposition ne peut pas encore être démarrée. Vérifie ton matériel.")
            return
        }
        do {
            let snapshot = ActiveSessionCoordinator.start(
                decision: decision,
                v2Context: v2Context
            )
            let active = try ActiveWorkoutRecord(snapshot: snapshot)
            modelContext.insert(active)
            do { try modelContext.save() }
            catch { modelContext.delete(active); throw error }
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "La séance n’a pas pu être sauvegardée. Rien n’a été perdu : tu peux réessayer.")
        }
    }

    private func prepareWorkout(allowOptionalMakeup: Bool = true) {
        guard verifyAccessForAttempt() else { return }
        let limitations = excludedMovementKeys.isEmpty
            ? []
            : [
                Limitation(
                    id: "session_movement_exclusion",
                    excludedExerciseKeys: excludedMovementKeys.sorted()
                )
            ]
        let person: V2Personalization?
        do {
            let prior = preparationPerson
            person = WorkoutEngineRuntime.selectedVersion() == .productionV1 ? nil : V2Personalization(
                sessionId: prior?.sessionId ?? UUID().uuidString, practice: setup.strengthPractice,
                returning: returning, knowledge: try prior?.knowledge ?? setup.movementKnowledge(), choices: prior?.choices ?? [])
        } catch { errorMessage = String(localized: "Les repères enregistrés ne peuvent pas être lus. Tes données sont conservées."); return }
        preparationPerson = person
        let prepared = WorkoutEngineBridge.prepareWorkout(
            inventory: setup.inventory,
            todayInventory: setup.inventory.filter {
                $0.category == "bodyweight" || !unavailableEquipmentCategories.contains($0.category)
            },
            durationMinutes: setup.selectedDuration,
            completedWorkouts: completedWorkouts,
            calibrations: setup.usesExplicitCalibration ? setup.calibrations : nil,
            calibrationIsExplicit: setup.usesExplicitCalibration,
            limitations: limitations,
            persistentRefusals: setup.persistentRefusals,
            allowOptionalMakeup: allowOptionalMakeup,
            engineVersion: WorkoutEngineRuntime.selectedVersion(),
            todaySupports: setup.supportProfile?.engineSupportKeys ?? [],
            previewMode: sessionMode,
            declaredCurrentHealthSignal: declaredCurrentHealthSignal,
            declaredScope: setup.declaredScope,
            person: person
        )
        let nextDecision = prepared.decision
        decision = nextDecision
        v2Context = prepared.v2Context
        personalizationResult = prepared.personalizationResult
        if excludedMovementKeys.isEmpty, nextDecision.decision == "generate_workout" {
            adaptableMovementKeys = nextDecision.movements?.map(\.exerciseKey) ?? []
        }
        errorMessage = nil
    }

    @ViewBuilder
    private func personalizedPreview(_ decision: EngineDecision, result: V2PersonalizedSessionResult) -> some View {
        let isLandscape = verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 18) {
            if let first = decision.movements?.first {
                Text(completedWorkouts.isEmpty ? "TA PREMIÈRE SÉANCE" : "TA PROCHAINE SÉANCE")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(LBSBrand.brandAccentText)
                Text("Prête quand tu l’es.")
                    .font(.archivoBlack(36, relativeTo: .largeTitle))
                    .foregroundStyle(LBSBrand.brandText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Label("\(max(1, Int(ceil(Double(result.decision.estimatedSeconds) / 60)))) min", systemImage: "clock")
                    Label("\(decision.movements?.count ?? 0) mouvements", systemImage: "figure.strengthtraining.traditional")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LBSBrand.secondaryText)
                if isLandscape {
                    HStack(alignment: .top, spacing: 24) {
                        MovementDemonstrationView(exerciseID: first.exerciseKey)
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                        personalizedPreviewActions(first: first, decision: decision)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    MovementDemonstrationView(exerciseID: first.exerciseKey)
                        .frame(height: 220)
                    personalizedPreviewActions(first: first, decision: decision)
                }
            }
            ForEach(result.checks, id: \.exerciseId) { check in
                Button { adjustmentID = check.exerciseId } label: {
                    Text("Préciser : \(PresentationCopy.movementTitle(check.exerciseId))")
                }
            }
            if !result.coverage.missingPrimary.isEmpty {
                Text("La couverture musculaire est partielle avec les mouvements actuellement disponibles.").font(.footnote)
            }
            if decision.movements?.isEmpty != false && result.checks.isEmpty {
                Text(PresentationCopy.explanation(decision.reasonCodes))
            }
        }
        .padding(20)
        .background(LBSBrand.cardBackground, in: LBSChamferedRectangle(cut: 18))
        .overlay {
            LBSChamferedRectangle(cut: 18)
                .stroke(LBSBrand.border, lineWidth: 1)
        }
    }

    private func personalizedPreviewActions(first: PrescribedMovement, decision: EngineDecision) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pour commencer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBSBrand.brandAccentText)
                Text(PresentationCopy.movementTitle(first.exerciseKey))
                    .font(.title3.bold())
            }
            Button { start(decision) } label: {
                Label("Lancer la séance", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(LBSBrand.orange)
            .foregroundStyle(LBSBrand.ink)
            Button("Adapter ce mouvement") { adjustmentID = first.exerciseKey }
                .frame(minHeight: 44)
            DisclosureGroup("Voir la séance") {
                ForEach(decision.movements ?? [], id: \.exerciseKey) { movement in
                    HStack {
                        Text(PresentationCopy.movementTitle(movement.exerciseKey))
                        Spacer()
                        Text("\(movement.sets) séries")
                        Button("Adapter") { adjustmentID = movement.exerciseKey }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func todayAvailabilityBinding(forEquipment category: String) -> Binding<Bool> {
        Binding(
            get: { !unavailableEquipmentCategories.contains(category) },
            set: { available in
                if available { unavailableEquipmentCategories.remove(category) }
                else { unavailableEquipmentCategories.insert(category) }
            }
        )
    }

    private func lockedContinuationCard(_ decision: EngineDecision) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("La suite est prête")
                        .font(.title2.bold())
                    Text("Le moteur a déjà ajusté la prochaine séance à ce bilan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(LBSBrand.orange)
                    .accessibilityHidden(true)
            }

            Label(
                PresentationCopy.explanation(decision.reasonCodes),
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
            )
            .font(.subheadline.weight(.semibold))

            Button("Continuer avec La Bonne Séance") {
                if verifyAccessForAttempt() { prepareWorkout() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(LBSBrand.cardBackground, in: LBSChamferedRectangle(cut: 14))
    }
}
