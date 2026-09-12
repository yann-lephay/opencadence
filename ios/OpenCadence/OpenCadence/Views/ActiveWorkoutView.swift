import CadenceEngine
import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var subscriptions: SubscriptionStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var reviewHistory: [CompletedWorkoutRecord]
    @State private var sessionReview: SessionReview?
    @State private var reviewSkipped = false
    @State private var summaryScrollOffset: CGFloat = 0
    @AppStorage("restCountdownSoundEnabled") private var countdownSoundEnabled = true

    @Query(sort: \UserSetupRecord.updatedAt, order: .reverse)
    private var setups: [UserSetupRecord]

    @Query(sort: \CompletedWorkoutRecord.endedAt, order: .reverse)
    private var completedWorkouts: [CompletedWorkoutRecord]

    let record: ActiveWorkoutRecord

    @State private var snapshot: ActiveWorkoutSnapshot?
    @State private var incompatibleV2Snapshot: ActiveWorkoutSnapshot?
    @State private var repetitions = 8
    @State private var recoveryMessage: String?
    @State private var errorMessage: String?
    @State private var pendingSnapshot: ActiveWorkoutSnapshot?
    @State private var pendingRequiresRepair = false
    @State private var showSkipConfirmation = false
    @State private var showEndConfirmation = false
    @State private var showSafetyReport = false
    @State private var isCorrectingLastSet = false
    @State private var correctionRepetitions = 8
    @State private var correctionLoadKg: Double?
    @State private var correctionLoadOptionID: String?
    @State private var hasLoaded = false
    @State private var adjustmentID: String?
    @State private var showingSessionPreferences = false
    @State private var showingSessionPlan = false

    var body: some View {
        Group {
            if let incompatibleV2Snapshot {
                incompatibleV2View(incompatibleV2Snapshot)
            } else if let snapshot {
                if let safetyEvent = snapshot.unresolvedSafetyEvent {
                    safetyInterruptionView(safetyEvent, snapshot: snapshot)
                } else if snapshot.isFinished {
                    completedView(snapshot)
                } else {
                    activeView(snapshot)
                }
            } else if let errorMessage {
                recoveryFailure(errorMessage)
            } else {
                ProgressView("Restauration de la séance…")
            }
        }
        .navigationTitle(
            incompatibleV2Snapshot != nil
                ? "Séance à fermer"
                : snapshot?.unresolvedSafetyEvent != nil
                ? "Faire une pause"
                : (snapshot?.isFinished == true ? "Bilan" : "Séance en cours")
        )
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            load()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-OpenCadencePersonalizationProof") && ProcessInfo.processInfo.arguments.contains("-OpenCadencePreferencesProof") { showingSessionPreferences = true }
#endif
        }
        .task(id: audibleRestDeadline) {
            guard let deadline = audibleRestDeadline else { return }
            await RestCountdownAudio.play(until: deadline)
        }
        .confirmationDialog(
            "Passer cet exercice ?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Passer l’exercice", role: .destructive) {
                update { state in
                    if state.v2Context?.personalization?.blocks != nil,
                       state.restDeadline != nil || state.pausedRemainingSeconds != nil {
                        return ActiveSessionCoordinator.skipUpcomingMovement(state)
                    }
                    return ActiveSessionCoordinator.skipCurrentMovement(state)
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les séries déjà réalisées sont conservées. Les séries restantes de cet exercice seront passées.")
        }
        .confirmationDialog(
            "Terminer maintenant ?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("Terminer la séance", role: .destructive) {
                update { ActiveSessionCoordinator.endEarly($0) }
            }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Les exercices restants seront notés comme non terminés, sans dette ni punition.")
        }
        .sheet(isPresented: $showingSessionPreferences) {
            if let setup = setups.first, let current = snapshot {
                SessionPreferencesView(setup: setup, snapshot: current) { practice, returning, mode, excludedEquipment, familiar in
                    guard let current = snapshot, pendingSnapshot == nil else { throw NativePersonalization.AdjustmentError.unavailable }
                    var knowledge = try setup.movementKnowledge()
                    let configuration: V2EngineConfiguration = current.v2Context?.personalization?.releaseConfiguration == true ? .releaseV2 : .productPreview
                    let sessionKnowledge = NativePersonalization.settingFamiliarity(
                        current.v2Context?.personalization?.person.knowledge ?? knowledge,
                        exerciseID: current.currentMovement?.exerciseKey, familiar: familiar, configuration: configuration)
                    knowledge = NativePersonalization.settingFamiliarity(knowledge,
                        exerciseID: current.currentMovement?.exerciseKey, familiar: familiar, configuration: configuration)
                    let prepared = WorkoutEngineBridge.prepareWorkout(inventory: setup.inventory,
                        todayInventory: setup.inventory.filter { $0.category == "bodyweight" || !excludedEquipment.contains($0.category) },
                        durationMinutes: setup.selectedDuration, completedWorkouts: completedWorkouts,
                        persistentRefusals: Array(Set(setup.persistentRefusals + (current.v2Context?.personalization?.refusals ?? []) + current.skippedExerciseKeys)),
                        engineVersion: current.v2Context?.personalization?.releaseConfiguration == true ? .releaseV2 : .previewV2,
                        todaySupports: setup.supportProfile?.engineSupportKeys ?? [],
                        previewMode: mode, declaredScope: setup.declaredScope,
                        person: .init(sessionId: current.sessionID, practice: practice.flatMap(V2StrengthPractice.init(rawValue:)),
                            returning: returning, knowledge: sessionKnowledge))
                    let next = try NativePersonalization.replaceBeforeFirstSet(current, with: prepared, history: WorkoutEngineBridge.migratedV2History(from: completedWorkouts.compactMap(\.payload)))
                    let oldKnowledge = setup.movementKnowledgeData, oldPractice = setup.strengthPracticeRaw
                    let oldData = record.snapshotData, oldPrevious = record.previousSnapshotData, oldDate = record.updatedAt
                    do {
                        setup.movementKnowledgeData = try JSONEncoder().encode(knowledge)
                        setup.strengthPracticeRaw = practice
                        try ActiveSessionCoordinator.persist(next, in: record, context: modelContext)
                        snapshot = next
                        repetitions = next.v2Context?.plan.first?.targetReps ?? 8
                    } catch {
                        setup.movementKnowledgeData = oldKnowledge; setup.strengthPracticeRaw = oldPractice
                        record.snapshotData = oldData; record.previousSnapshotData = oldPrevious; record.updatedAt = oldDate
                        throw error
                    }
                }
            }
        }
        .sheet(isPresented: $showingSessionPlan) {
            NavigationStack {
                List {
                    if let current = snapshot {
                        ForEach(current.decision.movements ?? [], id: \.exerciseKey) { movement in
                            LabeledContent(PresentationCopy.movementTitle(movement.exerciseKey)) { Text("\(movement.sets) séries") }
                        }
                        if let context = current.v2Context {
                            Text("Durée estimée : \(max(1, Int(ceil(Double(context.estimatedSeconds) / 60)))) min")
                            if context.personalization?.coverage.missingPrimary.isEmpty == false {
                                Text("La couverture musculaire est partielle avec les mouvements actuellement disponibles.")
                            }
                        }
                    }
                }.navigationTitle("La séance")
            }
        }
        .sheet(isPresented: Binding(get: { adjustmentID != nil }, set: { if !$0 { adjustmentID = nil } })) {
            if let id = adjustmentID, let current = snapshot, let context = current.v2Context,
               let personal = context.personalization {
                PersonalizationAdjustmentView(exerciseID: id,
                    options: personal.options[id] ?? personal.checks.first(where: { $0.exerciseId == id })?.alternatives ?? [],
                    inventory: context.inventory, currentSets: context.plan.first(where: { $0.exerciseId == id })?.sets ?? 2,
                    releaseConfiguration: personal.releaseConfiguration,
                    hasRepetitionPreference: personal.person.knowledge.first(where: { $0.exerciseId == id })?.preferredReps != nil) { id, choice, scope, declaration in
                    try applyPersonalization(id: id, choice: choice, scope: scope, declaration: declaration)
                }
            }
        }
        .sheet(isPresented: $showSafetyReport) {
            SafetyReportView(
                onPain: { score in
                    update { ActiveSessionCoordinator.reportPain($0, score: score) }
                },
                onUrgentAlert: {
                    update { ActiveSessionCoordinator.reportUrgentAlert($0) }
                }
            )
            .presentationDragIndicator(.visible)
        }
    }

    private func activeView(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let requiresScrolling = snapshot.v2Context?.personalization != nil || dynamicTypeSize.isAccessibilitySize || hasActiveNotice(snapshot)

            ZStack {
                Group {
                    if requiresScrolling {
                        ScrollView {
                            activeWorkoutContent(snapshot, availableSize: proxy.size, isLandscape: isLandscape && !dynamicTypeSize.isAccessibilitySize)
                        }
                    } else {
                        activeWorkoutContent(snapshot, availableSize: proxy.size, isLandscape: isLandscape)
                    }
                }
                .padding(.horizontal, isLandscape ? 14 : 16)
                .padding(.vertical, isLandscape ? 8 : 12)
                .allowsHitTesting(!isResting(snapshot))
                .accessibilityHidden(isResting(snapshot))

                if isResting(snapshot) {
                    restOverlay(snapshot, isLandscape: isLandscape)
                        .disabled(pendingSnapshot != nil)
                }
            }
        }
        .background(LBSBrand.cardBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func activeWorkoutContent(
        _ snapshot: ActiveWorkoutSnapshot,
        availableSize: CGSize,
        isLandscape: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if snapshot.v2Context?.personalization != nil && snapshot.recordedSets.isEmpty && snapshot.setStartedAt == nil {
                HStack {
                    if snapshot.v2Context?.personalization?.person.practice == nil {
                        Button("Tu pratiques déjà ?") { showingSessionPreferences = true }.frame(minHeight: 44)
                    } else {
                        Button("Adapter la séance") { showingSessionPreferences = true }.frame(minHeight: 44)
                    }
                    Spacer()
                    Button { showingSessionPlan = true } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }
                        .accessibilityLabel("Voir la séance")
                }.font(.subheadline)
            }
            if snapshot.decision.reasonCodes.contains("time_budget.removed_unstarted_work") {
                activeNotice(
                    String(localized: "La suite non commencée a été raccourcie pour rester dans le temps choisi. Tout ce que tu as déjà fait est conservé."),
                    systemImage: "clock.badge.checkmark",
                    color: .teal
                )
            }

            if let recoveryMessage {
                activeNotice(recoveryMessage, systemImage: "arrow.counterclockwise.circle.fill", color: .teal)
            }

            if let movement = snapshot.currentMovement {
                movementView(
                    movement,
                    snapshot: snapshot,
                    availableSize: availableSize,
                    isLandscape: isLandscape
                )
                .allowsHitTesting(!isResting(snapshot))
                .accessibilityHidden(isResting(snapshot))
                .disabled(pendingSnapshot != nil)
            }

            if let guidance = activeSafetyGuidance(snapshot) {
                activeNotice(guidance, systemImage: "hand.raised.fill", color: .orange)
            }

            if let errorMessage {
                activeNotice(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            }

            if pendingSnapshot != nil {
                Button("Réessayer la sauvegarde") {
                    retryPendingSave()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func hasActiveNotice(_ snapshot: ActiveWorkoutSnapshot) -> Bool {
        snapshot.decision.reasonCodes.contains("time_budget.removed_unstarted_work")
            || recoveryMessage != nil
            || activeSafetyGuidance(snapshot) != nil
            || errorMessage != nil
            || pendingSnapshot != nil
    }

    private func activeNotice(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private func applyPersonalization(id: String, choice: V2DirectChoice?, scope: V2ChoiceScope,
                                      declaration: V2MovementKnowledge? = nil) throws {
                    guard pendingSnapshot == nil, let current = snapshot else { throw NativePersonalization.AdjustmentError.unavailable }
                    let history = WorkoutEngineBridge.migratedV2History(from: completedWorkouts.compactMap(\.payload))
                    let next = try NativePersonalization.adjust(current, exerciseID: id, choice: choice, scope: scope,
                        declaration: declaration, history: history)
                    let previousData = setups.first?.movementKnowledgeData
                    if scope == .usual || choice == .difficultyTooHigh || choice == .deferRepetitionReview, let setup = setups.first {
                        setup.movementKnowledgeData = try JSONEncoder().encode(NativePersonalization.durableKnowledge(
                            try setup.movementKnowledge(), exerciseID: id, choice: choice, declaration: declaration,
                            result: next.v2Context?.personalization?.person.knowledge ?? []))
                    }
                    let oldData = record.snapshotData, oldPrevious = record.previousSnapshotData, oldDate = record.updatedAt
                    do {
                        try ActiveSessionCoordinator.persist(next, in: record, context: modelContext)
                        snapshot = next
                    } catch {
                        record.snapshotData = oldData; record.previousSnapshotData = oldPrevious; record.updatedAt = oldDate
                        setups.first?.movementKnowledgeData = previousData
                        throw error
                    }
    }

    private func movementView(
        _ movement: PrescribedMovement,
        snapshot: ActiveWorkoutSnapshot,
        availableSize: CGSize,
        isLandscape: Bool
    ) -> some View {
        let mediaSide = isLandscape
            ? min(availableSize.height - 84, availableSize.width * 0.42)
            : min(availableSize.width - 48, max(174, availableSize.height * 0.34))

        return Group {
            if isLandscape {
                HStack(alignment: .top, spacing: 16) {
                    MovementDemonstrationView(exerciseID: movement.exerciseKey)
                        .frame(width: mediaSide, height: mediaSide)

                    movementControls(movement, snapshot: snapshot, isLandscape: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    movementHeader(movement, snapshot: snapshot, isLandscape: false)

                    MovementDemonstrationView(exerciseID: movement.exerciseKey)
                        .frame(maxWidth: .infinity)
                        .frame(height: mediaSide)

                    movementControls(movement, snapshot: snapshot, isLandscape: false, includesHeader: false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func movementControls(
        _ movement: PrescribedMovement,
        snapshot: ActiveWorkoutSnapshot,
        isLandscape: Bool,
        includesHeader: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: isLandscape ? 4 : 10) {
            if includesHeader {
                movementHeader(movement, snapshot: snapshot, isLandscape: isLandscape)
            }

            if snapshot.recordedSets.isEmpty, snapshot.setStartedAt == nil, let context = snapshot.v2Context {
                SessionAdaptationNotice(context: context) { adjustmentID = $0 }
            }
            if snapshot.v2Context?.personalization != nil && snapshot.setStartedAt == nil {
                Button("Adapter ce mouvement") { adjustmentID = movement.exerciseKey }
            }
            if snapshot.setStartedAt == nil,
               snapshot.v2Context?.personalization?.recentWorkExercises?.contains(movement.exerciseKey) == true {
                Text("Une série de moins pour ce mouvement : les muscles sollicités ont déjà travaillé lors de deux séances récentes.")
                    .font(.footnote).foregroundStyle(LBSBrand.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            loadControl(movement, compact: isLandscape)
                .disabled(snapshot.v2Context?.personalization != nil && snapshot.setStartedAt != nil)
            if snapshot.v2Context?.personalization == nil || snapshot.setStartedAt != nil {
                repetitionsControl(movement, compact: isLandscape)
            }

            Button {
                if snapshot.setStartedAt == nil {
                    if snapshot.v2Context?.personalization != nil {
                        repetitions = snapshot.v2Context?.plan.first(where: { $0.exerciseId == movement.exerciseKey })?.targetReps ?? repetitions
                    }
                    update { current in
                        var next = current
                        if next.confirmedLoads[movement.exerciseKey] == nil,
                           let suggested = next.v2Context?.plan.first(where: { $0.exerciseId == movement.exerciseKey })?.load?.kg {
                            next = ActiveSessionCoordinator.confirmLoad(next, exerciseKey: movement.exerciseKey, perUnitWeightKg: suggested, inventory: setups.first?.inventory ?? [])
                        }
                        return ActiveSessionCoordinator.startSet(next)
                    }
                } else {
                    update { ActiveSessionCoordinator.recordSet($0, repetitions: repetitions) }
                }
            } label: {
                Label(snapshot.setStartedAt == nil ? "Commencer la série" : "Valider la série", systemImage: snapshot.setStartedAt == nil ? "play.fill" : "checkmark")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: isLandscape ? 44 : 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(LBSBrand.orange)
            .foregroundStyle(LBSBrand.ink)
            .disabled(
                WorkoutLoadResolver.requiresLoad(movement)
                    && snapshot.confirmedLoads[movement.exerciseKey] == nil
                    && !(snapshot.v2Context?.plan.first(where: { $0.exerciseId == movement.exerciseKey })?.load?.kg.map { WorkoutLoadResolver.options(for: movement, inventory: setups.first?.inventory ?? []).contains($0) } ?? false)
                    || WorkoutLoadResolver.requiresOption(movement)
                    && snapshot.confirmedOptions[movement.exerciseKey] == nil
            )

            sessionExitActions(includeSafety: true, compact: isLandscape)
        }
    }

    private func movementHeader(
        _ movement: PrescribedMovement,
        snapshot: ActiveWorkoutSnapshot,
        isLandscape: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: isLandscape ? 2 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(
                    "\(PresentationCopy.patternTitle(movement.pattern)) · Série \(min(snapshot.completedSetsInMovement + 1, movement.sets))/\(movement.sets)"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(LBSBrand.brandAccentText)

                Spacer()

                if snapshot.v2Context?.personalization == nil {
                    Text("\(snapshot.completedSetCount)/\(snapshot.totalSetCount)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(LBSBrand.brandText)
                }
            }

            if snapshot.v2Context?.personalization == nil { sessionProgress(snapshot) }

            Text(PresentationCopy.movementTitle(movement.exerciseKey))
                .font(isLandscape ? .title3.bold() : .title.bold())
                .foregroundStyle(LBSBrand.brandText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(movement.target)
                .font(isLandscape ? .caption : .subheadline)
                .foregroundStyle(LBSBrand.secondaryText)
        }
    }

    @ViewBuilder
    private func loadControl(_ movement: PrescribedMovement, compact: Bool) -> some View {
        if WorkoutLoadResolver.requiresLoad(movement) {
            let options = WorkoutLoadResolver.options(
                for: movement,
                inventory: setups.first?.inventory ?? []
            )
            if options.isEmpty {
                Label("Aucune charge compatible", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(LBSBrand.destructiveText)
            } else {
                let suggested = snapshot?.v2Context?.plan.first { $0.exerciseId == movement.exerciseKey }?.load?.kg
                let selected = snapshot?.confirmedLoads[movement.exerciseKey] ?? suggested.flatMap { options.contains($0) ? $0 : nil }
                let center = options.firstIndex(of: selected ?? suggested ?? options[0]) ?? 0
                let visible = Array(options[max(0, center - 1)...min(options.count - 1, center + 1)])
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ForEach(visible, id: \.self) { weight in loadChoice(weight, movement: movement, selected: selected, suggested: suggested) }
                    }
                    VStack(spacing: 8) {
                        ForEach(visible, id: \.self) { weight in loadChoice(weight, movement: movement, selected: selected, suggested: suggested) }
                    }
                }

            }
        }

        if WorkoutLoadResolver.requiresOption(movement) {
            let options = WorkoutLoadResolver.optionIDs(
                for: movement,
                inventory: setups.first?.inventory ?? []
            )
            adaptivePickerRow(
                title: "Élastique",
                systemImage: "line.diagonal",
                picker: Picker("Élastique réellement utilisé", selection: optionBinding(for: movement)) {
                    Text("Choisir").tag(String?.none)
                    ForEach(options, id: \.self) { option in
                        Text(bandDisplayName(option)).tag(String?.some(option))
                    }
                }
                .pickerStyle(.menu)
            )
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(LBSBrand.screenBackground, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func loadChoice(_ weight: Double, movement: PrescribedMovement, selected: Double?, suggested: Double?) -> some View {
        Button { loadBinding(for: movement).wrappedValue = weight } label: {
            VStack(spacing: 4) {
                Text("\(weight.formatted(.number)) \(WorkoutLoadResolver.loadLabel(for: movement))")
                    .font(.headline)
                if weight == suggested { Text("Suggestion").font(.caption) }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(8)
            .background(selected == weight ? LBSBrand.ink : LBSBrand.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(selected == weight ? LBSBrand.cream : LBSBrand.brandText)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(LBSBrand.border) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == weight ? .isSelected : [])
    }

    @ViewBuilder
    private func adaptivePickerRow<PickerContent: View>(
        title: LocalizedStringKey,
        systemImage: String,
        picker: PickerContent
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                picker
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                picker
            }
        }
    }

    private func repetitionsControl(_ movement: PrescribedMovement, compact: Bool) -> some View {
        let label = VStack(alignment: .leading, spacing: 2) {
            Text("Réalisé")
                .font(.subheadline.weight(.semibold))
            Text(movement.target)
                .font(.caption)
                .foregroundStyle(LBSBrand.secondaryText)
        }

        let controls = HStack(spacing: 0) {
            Button {
                repetitions = max(1, repetitions - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Retirer une répétition")

            Text("\(repetitions)")
                .font(.title2.bold())
                .monospacedDigit()
                .frame(minWidth: 42)
                .accessibilityLabel("\(repetitions) répétitions réalisées")

            Button {
                repetitions = min(50, repetitions + 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ajouter une répétition")
        }
        .buttonStyle(.plain)
        .background(LBSBrand.screenBackground, in: Capsule())

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    label
                    controls
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 10) {
                    label
                    Spacer()
                    controls
                }
            }
        }
        .frame(minHeight: compact ? 44 : 50)
    }

    private func sessionExitActions(
        includeSafety: Bool,
        compact: Bool = false,
        skipTitle: LocalizedStringKey = "Passer",
        onDark: Bool = false
    ) -> some View {
        HStack(spacing: 4) {
            compactSessionAction(skipTitle, systemImage: "forward.end", compact: compact, onDark: onDark) {
                showSkipConfirmation = true
            }

            if includeSafety {
                compactSessionAction("Gêne", systemImage: "waveform.path.ecg", compact: compact, onDark: onDark) {
                    showSafetyReport = true
                }
            }

            compactSessionAction("Terminer", systemImage: "stop.circle", role: .destructive, compact: compact, onDark: onDark) {
                showEndConfirmation = true
            }
        }
        .disabled(pendingSnapshot != nil)
    }

    private func compactSessionAction(
        _ title: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        compact: Bool = false,
        onDark: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font((compact ? Font.caption2 : .caption).weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            role == .destructive
                ? (onDark ? Color.red : LBSBrand.destructiveText)
                : (onDark ? LBSBrand.cream : LBSBrand.brandAccentText)
        )
    }

    private func restView(_ snapshot: ActiveWorkoutSnapshot, isLandscape: Bool) -> some View {
        let deadline = snapshot.restDeadline ?? .now
        let tickStart = deadline.addingTimeInterval(-Double(remainingSeconds(until: deadline, at: .now)))
        return TimelineView(.periodic(from: tickStart, by: 1)) { context in
            restContent(snapshot, now: context.date, isLandscape: isLandscape)
        }
    }

    private func restOverlay(_ snapshot: ActiveWorkoutSnapshot, isLandscape: Bool) -> some View {
        VStack(spacing: 12) {
            restView(snapshot, isLandscape: isLandscape)
            sessionExitActions(includeSafety: false, skipTitle: "Passer l’exercice", onDark: true)
        }
        .padding(isLandscape ? 16 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LBSBrand.ink.opacity(0.985).ignoresSafeArea())
        .foregroundStyle(LBSBrand.cream)
        .tint(LBSBrand.orange)
    }

    private func restContent(_ snapshot: ActiveWorkoutSnapshot, now: Date, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Repos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBSBrand.orange)
                Spacer()
                Button {
                    countdownSoundEnabled.toggle()
                } label: {
                    Image(systemName: countdownSoundEnabled ? "speaker.wave.2" : "speaker.slash")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LBSBrand.cream)
                .accessibilityLabel(countdownSoundEnabled
                    ? String(localized: "Couper le son du compte à rebours")
                    : String(localized: "Activer le son du compte à rebours"))
                if snapshot.v2Context?.personalization == nil {
                    Text("\(snapshot.completedSetCount)/\(snapshot.totalSetCount)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(LBSBrand.cream)
                }
            }
            if snapshot.v2Context?.personalization == nil {
                sessionProgress(snapshot)
                    .tint(LBSBrand.orange)
            }

            if isLandscape {
                HStack(alignment: .top, spacing: 24) {
                    restMovementPreview(snapshot, compact: true)
                        .frame(maxWidth: .infinity)
                    restTimerControls(snapshot, now: now)
                        .frame(maxWidth: .infinity)
                }
            } else {
                restMovementPreview(snapshot, compact: false)
                restTimerControls(snapshot, now: now)
            }
            if let row = pendingRepetitionReview(snapshot) {
                RepetitionReviewNotice(exerciseID: row.exerciseId, repetitions: row.targetReps) { choice, scope in
                    do { try applyPersonalization(id: row.exerciseId, choice: choice, scope: scope) }
                    catch { adjustmentID = row.exerciseId }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pendingRepetitionReview(_ snapshot: ActiveWorkoutSnapshot) -> V2PlanItem? {
        guard let context = snapshot.v2Context,
              let check = context.personalization?.checks.first(where: { $0.reason == "repeated_repetitions_gap" }),
              let row = context.plan.first(where: { $0.exerciseId == check.exerciseId }),
              snapshot.recordedSets.filter({ $0.exerciseKey == row.exerciseId }).count < row.sets else { return nil }
        return row
    }

    @ViewBuilder
    private func restMovementPreview(_ snapshot: ActiveWorkoutSnapshot, compact: Bool) -> some View {
        if let next = restPreviewMovement(snapshot), pendingRepetitionReview(snapshot) != nil {
            HStack(spacing: 12) {
                MovementDemonstrationView(exerciseID: next.exerciseKey, showsPlaybackControls: false)
                    .frame(width: 76, height: 76).clipped()
                Text(PresentationCopy.movementTitle(next.exerciseKey)).font(.headline)
            }
        } else if let next = restPreviewMovement(snapshot) {
            VStack(alignment: .leading, spacing: 8) {
                if let personal = snapshot.v2Context?.personalization {
                    Button("Adapter le prochain mouvement") { adjustmentID = next.exerciseKey }
                    ForEach(personal.checks.filter(\.requiredBeforeMovement), id: \.exerciseId) { check in
                        Button { adjustmentID = check.exerciseId } label: {
                            Text("Préciser : \(PresentationCopy.movementTitle(check.exerciseId))")
                        }
                    }
                }
                MovementDemonstrationView(exerciseID: next.exerciseKey, showsPlaybackControls: false)
                    .frame(maxWidth: compact ? 170 : 280)
                    .frame(maxWidth: .infinity)
                Text(next.exerciseKey == snapshot.currentMovement?.exerciseKey ? "Encore ce mouvement" : "Prochain mouvement")
                    .font(.caption.weight(.semibold))
                Text(PresentationCopy.movementTitle(next.exerciseKey))
                    .font(.archivoBlack(compact ? 18 : 24, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func restTimerControls(_ snapshot: ActiveWorkoutSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let paused = snapshot.pausedRemainingSeconds {
                timerText(paused)
                Text("En pause")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if let deadline = snapshot.restDeadline {
                timerText(remainingSeconds(until: deadline, at: now))
            }

            HStack {
                if snapshot.pausedRemainingSeconds != nil {
                    Button("Reprendre") {
                        update { ActiveSessionCoordinator.resumeRest($0) }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause") {
                        update { ActiveSessionCoordinator.pauseRest($0) }
                    }
                    .buttonStyle(.bordered)
                }

            }

            Button {
                update { ActiveSessionCoordinator.completeRest($0) }
            } label: {
                Text(snapshot.restDeadline.map { $0 <= now } == true ? "Continuer" : "Passer le repos")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(LBSBrand.orange)
            .foregroundStyle(LBSBrand.ink)
        }
    }

    private func restPreviewMovement(_ snapshot: ActiveWorkoutSnapshot) -> PrescribedMovement? {
        if snapshot.v2Context?.personalization?.blocks != nil {
            return ActiveSessionCoordinator.nextMovementIndex(snapshot).flatMap { snapshot.decision.movements?[$0] }
        }
        guard let current = snapshot.currentMovement else { return nil }
        if snapshot.completedSetsInMovement < current.sets { return current }
        let next = snapshot.currentMovementIndex + 1
        guard let movements = snapshot.decision.movements, movements.indices.contains(next) else { return nil }
        return movements[next]
    }

    private func sessionProgress(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        ProgressView(
            value: Double(snapshot.completedSetCount),
            total: Double(max(snapshot.totalSetCount, 1))
        )
        .tint(LBSBrand.controlTint)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Progression de la séance")
        .accessibilityValue(
            snapshot.completedSetCount == 1
                ? "1 série sur \(snapshot.totalSetCount)"
                : "\(snapshot.completedSetCount) séries sur \(snapshot.totalSetCount)"
        )
    }

    private func timerText(_ seconds: Int) -> some View {
        Text(Duration.seconds(max(seconds, 0)).formatted(.time(pattern: .minuteSecond)))
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Temps de repos restant")
            .accessibilityValue("\(max(seconds, 0)) secondes")
    }

    private var summaryPrefersReducedMotion: Bool {
#if DEBUG
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-OpenCadenceMediaReduceMotion")
#else
        reduceMotion
#endif
    }

    private func completedView(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        VStack(spacing: 0) {
            LBSWordmark()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            GeometryReader { geometry in
                let landscape = geometry.size.width > geometry.size.height
                let heroHeight: CGFloat = landscape ? 150 : min(390, max(270, geometry.size.height * 0.46))
                let staticHero = summaryPrefersReducedMotion || dynamicTypeSize.isAccessibilitySize
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if staticHero {
                            summaryHero(snapshot, height: heroHeight, progress: 0, landscape: landscape)
                        } else {
                            Color.clear.frame(height: heroHeight)
                                .accessibilityHidden(true)
                        }
                        summaryBody(snapshot)
                            .frame(maxWidth: 640)
                            .frame(maxWidth: .infinity)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, offset in
                    summaryScrollOffset = offset
                }
                .overlay(alignment: .top) {
                    if !staticHero {
                        let visible = max(0, heroHeight - summaryScrollOffset)
                        summaryHero(snapshot, height: heroHeight, progress: min(1, summaryScrollOffset / heroHeight), landscape: landscape)
                            .frame(height: visible, alignment: .top)
                            .clipped()
                            .allowsHitTesting(false)
                            .accessibilityHidden(visible == 0)
                    }
                }
            }
        }
        .background(LBSBrand.screenBackground.ignoresSafeArea())
        .foregroundStyle(LBSBrand.brandText)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func summaryHero(_ snapshot: ActiveWorkoutSnapshot, height: CGFloat, progress: CGFloat, landscape: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            LBSBrand.screenBackground
            Image("summary-hero")
                .resizable()
                .aspectRatio(contentMode: landscape ? .fit : .fill)
                .frame(height: height + 30)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .scaleEffect(max(0.01, 1 - progress), anchor: .topTrailing)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 13) {
                Text("Ta séance").font(.subheadline.weight(.semibold))
                Text(snapshot.recordedSets.isEmpty ? "À bientôt." : "Bien joué.")
                    .font(.archivoBlack(landscape ? 42 : 48, relativeTo: .largeTitle))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(snapshot.recordedSets.isEmpty ? "Aucune série enregistrée." : "Voilà ce que tu as fait.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: landscape ? 300 : 195, alignment: .leading)
                    .padding(.top, landscape ? 0 : 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, landscape ? 12 : 20)
            .scaleEffect(1 - 0.55 * progress, anchor: .topLeading)
            .offset(y: -20 * progress)
            .opacity(max(0, 1 - max(0, progress - 0.5) * 2))
        }
        .frame(height: height, alignment: .top)
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private func summaryBody(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if !snapshot.recordedSets.isEmpty {
                HStack(spacing: 0) {
                    completionMetric("\(Set(snapshot.recordedSets.map(\.exerciseKey)).count)", label: "mouvements")
                    Rectangle().fill(LBSBrand.orange).frame(width: 1, height: 55)
                    completionMetric("\(snapshot.recordedSets.count)", label: "séries")
                }
                .padding(.vertical, 24)
                factualSummary(snapshot)
            }
                if shouldAskReview(snapshot) {
                    sessionReviewCard
                }
                DisclosureGroup("Si tu veux affiner la suite") {
                    VStack(alignment: .leading, spacing: 14) {
                    Text("Ces réponses sont facultatives. Tu peux passer cette étape.")
                        .foregroundStyle(.secondary)

                    feedbackPicker(
                        title: "Difficulté globale",
                        selection: feedbackBinding(.effort),
                        options: Array(1...10),
                        label: { "\($0) sur 10" }
                    )
                    if let maximumReportedPain = snapshot.maximumReportedPain {
                        LabeledContent("Gêne maximale signalée pendant la séance") {
                            Text("\(maximumReportedPain) sur 10")
                                .fontWeight(.semibold)
                        }
                        Text("Cette valeur vient d’un signalement enregistré pendant la séance. Elle ne sera pas remplacée par une estimation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        feedbackPicker(
                            title: "Gêne ou douleur la plus forte",
                            selection: feedbackBinding(.discomfort),
                            options: Array(0...10),
                            label: { "\($0) sur 10" }
                        )
                    }
                    if snapshot.recordedSets.contains(where: { $0.perUnitWeightKg != nil }) {
                        feedbackPicker(
                            title: "Répétitions encore possibles sur la dernière série chargée",
                            selection: feedbackBinding(.repetitionsInReserve),
                            options: Array(0...5),
                            label: { $0 == 5 ? "5 ou plus" : "\($0)" }
                        )
                    }

                    if let discomfort = snapshot.feedback?.discomfort, discomfort >= 5 {
                        Label(
                            "Cette valeur empêchera le moteur de proposer une progression à partir de cette séance.",
                            systemImage: "hand.raised.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    }
                }
                    }
                .padding(.vertical, 16)
                .disabled(pendingSnapshot != nil)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                if pendingSnapshot != nil {
                    Button("Réessayer la sauvegarde") {
                        retryPendingSave()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let lastSet = snapshot.recordedSets.last {
                    if isCorrectingLastSet {
                        lastSetCorrection(lastSet, snapshot: snapshot)
                    } else {
                        Button("Corriger la dernière série") {
                            beginLastSetCorrection(lastSet)
                        }
                        .buttonStyle(.bordered)
                        .disabled(pendingSnapshot != nil)
                    }
                }

                Button {
                    saveSummary(snapshot)
                } label: {
                    Text("Retour à l’accueil")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(LBSBrand.ink)
                .foregroundStyle(LBSBrand.cream)
                .disabled(pendingSnapshot != nil)

        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private func completionMetric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.archivoBlack(50, relativeTo: .largeTitle))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .monospacedDigit()
            Text(label).font(.body)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func recoveryFailure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Séance illisible", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        } description: {
            Text(message)
        } actions: {
            Button("Supprimer cette sauvegarde", role: .destructive) {
                closeSession()
            }
        }
    }

    private func incompatibleV2View(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        ContentUnavailableView {
            Label("Cette séance vient d’une ancienne version", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        } description: {
            Text("Elle ne peut pas continuer avec les règles actuelles. Les séries déjà enregistrées peuvent être conservées dans le bilan, sans progression automatique.")
        } actions: {
            if !snapshot.recordedSets.isEmpty {
                Button("Enregistrer ce qui a été fait") {
                    var factual = ActiveSessionCoordinator.endEarly(snapshot)
                    factual.v2Context = nil
                    saveSummary(factual)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Fermer sans enregistrer", role: .destructive) {
                closeSession()
            }
        }
    }

    private func safetyInterruptionView(
        _ event: SafetyEventRecord,
        snapshot: ActiveWorkoutSnapshot
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: event.transition == "stop_session_and_orient"
                    ? "cross.case.fill"
                    : "hand.raised.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                if event.transition == "stop_current_set" {
                    Text("Arrête la série maintenant")
                        .font(.largeTitle.bold())
                    Text("Une gêne de \(event.painScore ?? 0) sur 10 a été enregistrée. La Bonne Séance n’en détermine pas la cause.")
                        .foregroundStyle(.secondary)

                    Button("Réduire l’amplitude et réévaluer") {
                        resolveSafety(.reduceRange)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pendingSnapshot != nil)

                    Button("Passer à l’exercice suivant") {
                        resolveSafety(.stopExercise)
                    }
                    .buttonStyle(.bordered)
                    .disabled(pendingSnapshot != nil)

                    Button("Terminer la séance", role: .destructive) {
                        resolveSafety(.endSession)
                    }
                    .disabled(pendingSnapshot != nil)
                } else if event.transition == "stop_current_exercise" {
                    Text("Arrête ce mouvement")
                        .font(.largeTitle.bold())
                    Text("Une gêne de \(event.painScore ?? 0) sur 10 a été enregistrée. La série n’est pas comptée et ce mouvement ne peut pas reprendre dans cette séance.")
                        .foregroundStyle(.secondary)

                    Button("Passer à l’exercice suivant") {
                        resolveSafety(.stopExercise)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pendingSnapshot != nil)

                    Button("Terminer la séance", role: .destructive) {
                        resolveSafety(.endSession)
                    }
                    .disabled(pendingSnapshot != nil)
                } else {
                    Text("Arrête la séance")
                        .font(.largeTitle.bold())
                    Text("Une pression ou douleur dans la poitrine, un essoufflement brutal ou inhabituel, ou un malaise peut nécessiter une aide urgente. La Bonne Séance ne pose pas de diagnostic.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("En France")
                            .font(.headline)
                        Text("Appelle le 15 ou le 112. Si tu es ailleurs, contacte les services d’urgence locaux.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Link("Appeler le 15", destination: URL(string: "tel:15")!)
                                .buttonStyle(.borderedProminent)
                            Link("Appeler le 112", destination: URL(string: "tel:112")!)
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))

                    Button("Voir le bilan") {
                        resolveSafety(.acknowledgeOrientation)
                    }
                    .buttonStyle(.bordered)
                    .disabled(pendingSnapshot != nil)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if pendingSnapshot != nil {
                    Button("Réessayer la sauvegarde du signalement") {
                        retryPendingSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Text("Les séries déjà enregistrées restent conservées.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func load() {
        do {
            let loaded = try ActiveSessionCoordinator.load(record)
            guard loaded.v2ContextIsCompatible else {
                incompatibleV2Snapshot = loaded.snapshot
                return
            }
            snapshot = loaded.snapshot
            if loaded.restoredPreviousSnapshot {
                recoveryMessage = String(localized: "La dernière écriture était incomplète. La sauvegarde valide précédente a été restaurée.")
                do {
                    try ActiveSessionCoordinator.repair(loaded.snapshot, in: record, context: modelContext)
                } catch {
                    pendingSnapshot = loaded.snapshot
                    pendingRequiresRepair = true
                    errorMessage = String(localized: "La séance est restaurée à l’écran, mais sa réparation n’est pas encore sauvegardée.")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ mutation: (ActiveWorkoutSnapshot) -> ActiveWorkoutSnapshot) {
        guard pendingSnapshot == nil, let snapshot else { return }
        let next = mutation(snapshot)
        self.snapshot = next
        do {
            try ActiveSessionCoordinator.persist(next, in: record, context: modelContext)
            errorMessage = nil
        } catch {
            pendingSnapshot = next
            pendingRequiresRepair = false
            errorMessage = String(localized: "La dernière action reste visible, mais n’est pas encore sauvegardée. Les autres actions sont bloquées pour éviter de compter deux fois.")
        }
    }

    private func retryPendingSave() {
        guard let pendingSnapshot else { return }
        do {
            if pendingRequiresRepair {
                try ActiveSessionCoordinator.repair(pendingSnapshot, in: record, context: modelContext)
            } else {
                try ActiveSessionCoordinator.persist(pendingSnapshot, in: record, context: modelContext)
            }
            self.pendingSnapshot = nil
            pendingRequiresRepair = false
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "La sauvegarde échoue encore. L’action reste visible et ne sera pas recomptée lors du prochain essai.")
        }
    }

    private func loadBinding(for movement: PrescribedMovement) -> Binding<Double?> {
        Binding(
            get: { snapshot?.confirmedLoads[movement.exerciseKey] },
            set: { value in
                update {
                    ActiveSessionCoordinator.confirmLoad(
                        $0,
                        exerciseKey: movement.exerciseKey,
                        perUnitWeightKg: value,
                        inventory: setups.first?.inventory ?? []
                    )
                }
            }
        )
    }

    private func bandDisplayName(_ optionID: String) -> String {
        EquipmentConfigurationDraft.bandDisplayName(for: optionID, draftData: setups.first?.equipmentDraftData)
    }

    private func optionBinding(for movement: PrescribedMovement) -> Binding<String?> {
        Binding(
            get: { snapshot?.confirmedOptions[movement.exerciseKey] },
            set: { value in
                update {
                    ActiveSessionCoordinator.confirmLoadOption(
                        $0,
                        exerciseKey: movement.exerciseKey,
                        optionID: value,
                        inventory: setups.first?.inventory ?? []
                    )
                }
            }
        )
    }

    private func feedbackBinding(_ field: FeedbackField) -> Binding<Int?> {
        Binding(
            get: {
                switch field {
                case .effort: snapshot?.feedback?.effort
                case .discomfort: snapshot?.feedback?.discomfort
                case .repetitionsInReserve: snapshot?.feedback?.repetitionsInReserve
                }
            },
            set: { value in
                update {
                    ActiveSessionCoordinator.updateFeedback(
                        $0,
                        value: value,
                        field: field
                    )
                }
            }
        )
    }

    private func feedbackPicker(
        title: LocalizedStringKey,
        selection: Binding<Int?>,
        options: [Int],
        label: @escaping (Int) -> LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
            Picker(title, selection: selection) {
                Text("Non renseigné").tag(Int?.none)
                ForEach(options, id: \.self) { value in
                    Text(label(value)).tag(Int?.some(value))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func factualSummary(_ snapshot: ActiveWorkoutSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(snapshot.decision.movements ?? [], id: \.exerciseKey) { movement in
                let results = snapshot.recordedSets.filter { $0.exerciseKey == movement.exerciseKey }
                if !results.isEmpty {
                    SummaryMovementRow(
                        movement: movement,
                        results: results,
                        aggregateDose: recordedDose(results.reduce(0) { $0 + $1.repetitions }, movement: movement, snapshot: snapshot),
                        dose: { recordedDose($0, movement: movement, snapshot: snapshot) }
                    )
                }
            }
        }
    }

    private func recordedDose(_ value: Int, movement: PrescribedMovement, snapshot: ActiveWorkoutSnapshot) -> String {
        let item = snapshot.v2Context?.plan.first { $0.exerciseId == movement.exerciseKey }
        let perSide = item != nil && (V2EngineConfiguration.productPreview.catalog[movement.exerciseKey]?.timingSeconds.secondSide ?? 0) > 0
        let format: String
        switch (item?.resolvedTargetUnit ?? .repetitions, perSide) {
        case (.repetitions, false): format = String(localized: "%lld répétitions")
        case (.repetitions, true): format = String(localized: "%lld répétitions par côté")
        case (.seconds, false): format = String(localized: "%lld s")
        case (.seconds, true): format = String(localized: "%lld s par côté")
        case (.intervals, _): format = String(localized: "%lld intervalles")
        }
        return String.localizedStringWithFormat(format, value)
    }

    private func lastSetCorrection(
        _ lastSet: CompletedSetRecord,
        snapshot: ActiveWorkoutSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Corriger la dernière série")
                .font(.headline)
            Text(PresentationCopy.movementTitle(lastSet.exerciseKey))
                .foregroundStyle(.secondary)

            Stepper(value: $correctionRepetitions, in: 1...50) {
                Text("\(correctionRepetitions) répétitions")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if let movement = snapshot.decision.movements?.first(where: {
                $0.exerciseKey == lastSet.exerciseKey
            }), WorkoutLoadResolver.requiresLoad(movement) {
                Picker("Charge réellement utilisée", selection: $correctionLoadKg) {
                    ForEach(
                        WorkoutLoadResolver.options(
                            for: movement,
                            inventory: setups.first?.inventory ?? []
                        ),
                        id: \.self
                    ) { weight in
                        Text("\(weight.formatted(.number)) \(WorkoutLoadResolver.loadLabel(for: movement))")
                            .tag(Double?.some(weight))
                    }
                }
                .pickerStyle(.menu)
            }


            if let movement = snapshot.decision.movements?.first(where: {
                $0.exerciseKey == lastSet.exerciseKey
            }), WorkoutLoadResolver.requiresOption(movement) {
                Picker("Élastique réellement utilisé", selection: $correctionLoadOptionID) {
                    ForEach(
                        WorkoutLoadResolver.optionIDs(
                            for: movement,
                            inventory: setups.first?.inventory ?? []
                        ),
                        id: \.self
                    ) { option in
                        Text(bandDisplayName(option)).tag(String?.some(option))
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Annuler") {
                    isCorrectingLastSet = false
                }
                .buttonStyle(.bordered)

                Button("Appliquer la correction") {
                    update {
                        ActiveSessionCoordinator.correctLastSet(
                            $0,
                            repetitions: correctionRepetitions,
                            perUnitWeightKg: correctionLoadKg,
                            loadOptionID: correctionLoadOptionID,
                            inventory: setups.first?.inventory ?? []
                        )
                    }
                    isCorrectingLastSet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .disabled(pendingSnapshot != nil)
    }

    private func beginLastSetCorrection(_ lastSet: CompletedSetRecord) {
        correctionRepetitions = lastSet.repetitions
        correctionLoadKg = lastSet.perUnitWeightKg
        correctionLoadOptionID = lastSet.loadOptionID
        isCorrectingLastSet = true
    }

    private func isResting(_ snapshot: ActiveWorkoutSnapshot) -> Bool {
        snapshot.restDeadline != nil || snapshot.pausedRemainingSeconds != nil
    }

    private func activeSafetyGuidance(_ snapshot: ActiveWorkoutSnapshot) -> String? {
        guard let last = snapshot.recordedSafetyEvents.last,
              last.exerciseKey == snapshot.currentMovement?.exerciseKey else { return nil }
        if last.chosenAction == SafetyResolutionAction.reduceRange.rawValue {
            return String(localized: "Amplitude réduite choisie après une gêne signalée. Tu peux arrêter ce mouvement ou la séance à tout moment.")
        }
        if let score = last.painScore, score <= 2 {
            return String.localizedStringWithFormat(
                String(localized: "Gêne de %lld sur 10 enregistrée. Tu peux arrêter ce mouvement ou la séance à tout moment."),
                score
            )
        }
        return nil
    }

    private func resolveSafety(_ action: SafetyResolutionAction) {
        update { ActiveSessionCoordinator.resolveSafetyEvent($0, action: action) }
    }

    private func remainingSeconds(until deadline: Date, at now: Date) -> Int {
        max(Int(ceil(deadline.timeIntervalSince(now))), 0)
    }

    private var audibleRestDeadline: Date? {
        guard countdownSoundEnabled, scenePhase == .active,
              pendingSnapshot == nil, incompatibleV2Snapshot == nil,
              !showSafetyReport, !showSkipConfirmation, !showEndConfirmation,
              let snapshot, !snapshot.isFinished,
              snapshot.unresolvedSafetyEvent == nil,
              snapshot.pausedRemainingSeconds == nil else { return nil }
        return snapshot.restDeadline
    }

    private func closeSession() {
        modelContext.delete(record)
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "La séance n’a pas pu être fermée. Tu peux réessayer sans perdre ce bilan.")
        }
    }

    private func reviewEnrollment(_ snapshot: ActiveWorkoutSnapshot) -> String? {
        SessionSharing.shared.completionEnrollment(
            paid: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription,
            startedAt: snapshot.startedAt)
    }

    private func shouldAskReview(_ snapshot: ActiveWorkoutSnapshot) -> Bool {
        let enrollment = reviewEnrollment(snapshot)
        return !reviewSkipped && SessionReview.shouldAsk(
            paid: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription,
            enrollmentID: enrollment,
            priorEligibleCount: reviewHistory.filter { $0.sharingEnrollmentID == enrollment && enrollment != nil }.count,
            hasWork: !snapshot.recordedSets.isEmpty)
    }

    private var sessionReviewCard: some View {
        SessionReviewCard(sessionReview: $sessionReview, reviewSkipped: $reviewSkipped)
            .disabled(pendingSnapshot != nil)
    }

    private func saveSummary(_ snapshot: ActiveWorkoutSnapshot) {
        guard pendingSnapshot == nil else { return }
        do {
            try WorkoutCompletionCoordinator.save(
                snapshot: snapshot,
                activeRecord: record,
                context: modelContext,
                sharingEnrollmentID: SessionSharing.shared.completionEnrollment(
                    paid: subscriptions.entitlementsLoaded && subscriptions.hasActiveSubscription,
                    startedAt: snapshot.startedAt),
                sessionReview: shouldAskReview(snapshot) ? sessionReview : nil
            )
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Le bilan n’a pas été enregistré. La séance active et tes réponses sont conservées pour réessayer.")
        }
    }
}

private struct SafetyReportView: View {
    @Environment(\.dismiss) private var dismiss

    let onPain: (Int) -> Void
    let onUrgentAlert: () -> Void

    @State private var painScore = 3

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ce signalement est enregistré tel quel")
                            .font(.title2.bold())
                        Text("Il sert à arrêter ou adapter la séance. Il ne permet pas à l’app d’expliquer la cause de la gêne.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Gêne ou douleur") {
                    Stepper(value: $painScore, in: 1...10) {
                        LabeledContent("Intensité") {
                            Text("\(painScore) sur 10")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                    Text("À partir de 3 sur 10, la série s’arrête avant de proposer la suite.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Enregistrer cette gêne") {
                        onPain(painScore)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }

                Section("Signal inhabituel") {
                    Text("Pression ou douleur dans la poitrine, essoufflement brutal ou inhabituel, ou malaise.")
                        .foregroundStyle(.secondary)
                    Button("Arrêter et afficher l’aide urgente", role: .destructive) {
                        onUrgentAlert()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Comment te sens-tu ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct SessionReviewCard: View {
    @Binding var sessionReview: SessionReview?
    @Binding var reviewSkipped: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cette séance te convenait ?").font(.headline)
            Text("Facultatif · Pour aider l’équipe à améliorer les séances.")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(SessionReview.Impression.allCases, id: \.self) { value in
                Button {
                    sessionReview = SessionReview(impression: value, reason: sessionReview?.reason)
                } label: {
                    HStack {
                        Text(reviewLabel(value))
                        Spacer()
                        if sessionReview?.impression == value { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44)
                }.buttonStyle(.bordered).tint(LBSBrand.ink)
            }
            if sessionReview != nil {
                DisclosureGroup("Une précision ?") {
                    ForEach(SessionReview.Reason.allCases, id: \.self) { reason in
                        Button {
                            sessionReview?.reason = sessionReview?.reason == reason ? nil : reason
                        } label: {
                            HStack {
                                Text(reasonLabel(reason))
                                Spacer()
                                if sessionReview?.reason == reason { Image(systemName: "checkmark") }
                            }.frame(minHeight: 44)
                        }.buttonStyle(.bordered).tint(LBSBrand.ink)
                    }
                }
                Text("Ton retour sera enregistré avec le bilan. Il ne change pas automatiquement ta prochaine séance.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Passer ce retour") { sessionReview = nil; reviewSkipped = true }
                .frame(minHeight: 44)
        }.padding(.vertical, 12)
    }

    private func reviewLabel(_ value: SessionReview.Impression) -> String {
        switch value {
        case .fits: String(localized: "Oui, elle me convenait")
        case .mixed: String(localized: "Mitigé")
        case .notFit: String(localized: "Pas vraiment")
        }
    }
    private func reasonLabel(_ value: SessionReview.Reason) -> String {
        switch value {
        case .tooEasy: String(localized: "Trop facile")
        case .tooHard: String(localized: "Trop difficile")
        case .repetitive: String(localized: "Trop répétitive")
        case .unclear: String(localized: "Un exercice mal compris")
        }
    }

}
